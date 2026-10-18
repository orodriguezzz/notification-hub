module Notifications
  module AntiSpam
    # Filtro anti-spam (D7). Corre después del resolver y antes de renderizar. Capas, en orden:
    #   1. Críticas exentas (se cuentan igual, para métricas).
    #   2. Cooldown: misma notificación al mismo destinatario dentro del plazo -> drop.
    #   3. Horario de silencio en la zona del destinatario -> defer hasta las 08:00 locales.
    #   4. Presupuesto diario por destinatario y categoría (contador atómico).
    #   5. Excedente: engagement -> digest; operational -> defer al día siguiente.
    #      Si el request vence antes de la nueva hora -> drop por expired.
    #
    # El horario de silencio se evalúa ANTES de consumir presupuesto: si fuera al revés, un envío
    # postergado por la noche consumiría cupo hoy y otra vez al reintentarse mañana.
    #
    # En modo sombra la decisión se registra (evento throttled_shadow) pero el envío pasa.
    class Filter
      Decision = Data.define(:action, :reason, :until_time, :shadowed) do
        def self.allow(shadowed: nil) = new(action: :allow, reason: nil, until_time: nil, shadowed: shadowed)
        def self.defer(reason, until_time) = new(action: :defer, reason: reason, until_time: until_time, shadowed: nil)
        def self.digest(until_time) = new(action: :digest, reason: :digest, until_time: until_time, shadowed: nil)
        def self.drop(reason) = new(action: :drop, reason: reason, until_time: nil, shadowed: nil)

        def allow? = action == :allow

        def as_json(*)
          { action: action, reason: reason, until: until_time&.iso8601, shadowed: shadowed&.as_json }.compact
        end
      end

      def initialize(policy = Notifications.policy)
        @policy = policy
      end

      def call(request:, definition:, recipient:, now: Time.current)
        decision = evaluate(request, definition, recipient, now)
        return decision if decision.allow?

        ActiveSupport::Notifications.instrument(
          "throttle.notifications",
          notification_key: request.notification_key, category: request.category, owner: definition.owner,
          status: decision.action, reason: decision.reason, shadow: @policy.shadow_mode?
        )

        return decision unless @policy.shadow_mode?

        NotificationEvent.record!(:throttled_shadow, request: request, payload: decision.as_json)
        Decision.allow(shadowed: decision)
      end

      private

      def evaluate(request, definition, recipient, now)
        category = request.category.to_sym
        rule = @policy.rule_for(category)
        local_now = now.in_time_zone(time_zone_for(recipient))

        if category == :critical || rule.bypass_rate_limit?
          count!(request, local_now, limit: nil)
          return Decision.allow
        end

        return Decision.drop(:cooldown) if cooling_down?(request, definition, now)

        quiet = @policy.quiet_hours
        if quiet&.applies_to?(category) && quiet.active_at?(local_now)
          return expire_or(request, Decision.defer(:quiet_hours, quiet.next_end_after(local_now)))
        end

        limit = @policy.rate_limit_for(category)
        return Decision.allow unless limit
        return Decision.allow if count!(request, local_now, limit: limit.max)

        overflow(request, limit, local_now)
      end

      def overflow(request, limit, local_now)
        morning = morning_end(local_now)

        if limit.overflow == :digest
          expire_or(request, Decision.digest(morning.call(next_morning_date(local_now, morning))))
        else
          expire_or(request, Decision.defer(:rate_limit, morning.call(local_now.to_date + 1)))
        end
      end

      # Hora de fin de la noche (08:00 locales por defecto) para una fecha dada
      def morning_end(local_now)
        quiet = @policy.quiet_hours || Policy::QuietHours.new(from: "21:00", to: "08:00", except: [])
        ->(date) { quiet.at(local_now, date) }
      end

      def next_morning_date(local_now, morning)
        morning.call(local_now.to_date) > local_now ? local_now.to_date : local_now.to_date + 1
      end

      def expire_or(request, decision)
        return Decision.drop(:expired) if request.expires_at && decision.until_time > request.expires_at

        decision
      end

      def cooling_down?(request, definition, now)
        return false unless definition.cooldown

        NotificationDelivery
          .where(recipient_type: request.recipient_type, recipient_id: request.recipient_id,
                 notification_key: request.notification_key, status: NotificationDelivery::SENT_STATUSES)
          .where(created_at: (now - definition.cooldown)..)
          .where.not(request_id: request.id)
          .exists?
      end

      def count!(request, local_now, limit:)
        Counter.increment!(recipient_type: request.recipient_type, recipient_id: request.recipient_id,
                           bucket_date: local_now.to_date, category: request.category, limit: limit)
      end

      def time_zone_for(recipient)
        recipient.try(:effective_time_zone) || Time.zone
      end
    end
  end
end

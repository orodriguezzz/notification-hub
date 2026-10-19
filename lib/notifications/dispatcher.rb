module Notifications
  # Despacho asíncrono de un request (lo ejecuta Notifications::DispatchJob):
  #
  #   1. Toma el request con FOR UPDATE SKIP LOCKED (solo si está accepted o deferred) y lo marca processing.
  #   2. Resuelve parámetros (GlobalID). Entidad borrada -> skipped / entity_missing.
  #   3. Vencido -> expired.
  #   4. ChannelResolver -> canales posibles (sin canales: crítica -> undeliverable, resto -> skipped).
  #   5. AntiSpam::Filter -> allow | defer | digest | drop.
  #   6. Por cada canal: Renderer -> Adapter -> notification_delivery + eventos.
  #   7. Estado final: completed, skipped, deferred, expired, undeliverable o failed.
  class Dispatcher
    CLAIMABLE = NotificationRequest::PENDING_STATUSES

    def self.call(request_id) = new(request_id).call

    def initialize(request_id, policy: Notifications.policy)
      @request_id = request_id
      @policy = policy
    end

    def call
      request = claim
      return unless request

      payload = { notification_key: request.notification_key, category: request.category, request_id: request.id }
      ActiveSupport::Notifications.instrument("dispatch.notifications", payload) do
        process(request)
        payload[:status] = request.status
        payload[:owner] = safe_definition(request)&.owner
      end
      request
    end

    # Reintentos agotados (retry_on): la entrega pendiente pasa a failed
    def give_up(error)
      request = NotificationRequest.find_by(id: @request_id)
      return unless request

      NotificationRequest.transaction do
        request.deliveries.pending.find_each do |delivery|
          delivery.update!(status: "failed", last_error: error.message)
          NotificationEvent.record!(:failed, request: request, delivery: delivery,
                                    payload: { error: error.message, retries_exhausted: true })
        end
        request.update!(status: "failed", status_reason: Reasons::RETRIES_EXHAUSTED)
      end
    end

    # Fallback: intenta el siguiente canal de la política tras una falla definitiva o un rebote.
    # Devuelve :sent si salió por otro canal, :exhausted si no quedan canales.
    def fallback_from(request, failed_channel)
      rule = @policy.rule_for(request.category)
      remaining = rule.channels.drop_while { _1 != failed_channel.to_sym }.drop(1)
      definition = request.definition
      recipient = request.recipient
      params = ParamSerializer.load(request.params)
      resolution = ChannelResolver.new(@policy).call(category: request.category, company_id: request.company_id,
                                                     recipient: recipient, only: remaining)

      NotificationEvent.record!(:fallback_triggered, request: request,
                                payload: { from: failed_channel, to: resolution.channels.first }.compact)

      return :exhausted if resolution.empty?

      content = definition.build_content(params)
      resolution.channels.each do |channel|
        if deliver_via(request, definition, content, params, recipient, channel, { fallback_from: failed_channel }) == :sent
          request.update!(status: "completed", status_reason: Reasons::FALLBACK)
          return :sent
        end
      end

      :exhausted
    rescue ActiveJob::DeserializationError
      :exhausted
    end

    # Log de error + instrumentación para alertar sobre una notificación que no pudo salir
    def alert_undeliverable(request, reason)
      Rails.logger.error("[notifications] Notificación crítica sin entregar: request=#{request.id} " \
                         "key=#{request.notification_key} motivo=#{reason}")
      ActiveSupport::Notifications.instrument(
        "undeliverable.notifications",
        notification_key: request.notification_key, category: request.category,
        request_id: request.id, status: "undeliverable", reason: reason
      )
    end

    private

    def claim
      NotificationRequest.transaction do
        request = NotificationRequest.lock("FOR UPDATE SKIP LOCKED").find_by(id: @request_id)
        next unless request && CLAIMABLE.include?(request.status) && !request.digest_pending?

        request.update!(status: "processing")
        request
      end
    end

    def process(request)
      definition = request.definition

      params = begin
        ParamSerializer.load(request.params)
      rescue ActiveJob::DeserializationError
        return finish(request, "skipped", Reasons::ENTITY_MISSING, event: :skipped)
      end

      # El destinatario suele venir en los parámetros: evita volver a cargarlo
      recipient = params[definition.recipient] || request.recipient
      return finish(request, "skipped", Reasons::ENTITY_MISSING, event: :skipped) unless recipient
      return finish(request, "expired", Reasons::EXPIRED, event: :expired) if request.expires_at&.past?

      # Reintento tras un error transitorio: se reenvía la entrega pendiente, sin volver a filtrar
      pending = request.deliveries.pending.order(:created_at).first
      return retry_delivery(request, definition, params, recipient, pending) if pending

      resolution = ChannelResolver.new(@policy).call(category: request.category, company_id: request.company_id,
                                                     recipient: recipient)
      return no_channels(request, resolution) if resolution.empty?

      decision = AntiSpam::Filter.new(@policy).call(request: request, definition: definition, recipient: recipient)
      case decision.action
      when :drop then drop(request, decision)
      when :defer then defer(request, decision)
      when :digest then digest(request, decision)
      else deliver_all(request, definition, params, recipient, resolution, decision)
      end
    end

    def deliver_all(request, definition, params, recipient, resolution, decision)
      content = definition.build_content(params)
      reason = { strategy: resolution.rule.strategy, resolver: resolution.reasons, filter: decision.as_json }

      resolution.channels.each_with_index do |channel, index|
        result = deliver_via(request, definition, content, params, recipient, channel, reason)
        return request if result == :sent

        next_channel = resolution.channels[index + 1]
        break unless resolution.rule.fallback? && next_channel

        NotificationEvent.record!(:fallback_triggered, request: request, payload: { from: channel, to: next_channel })
      end

      fail_request(request)
    end

    # Renderiza y entrega por un canal. Devuelve :sent o :failed; los errores transitorios se propagan.
    def deliver_via(request, definition, content, params, recipient, channel, reason)
      entry = Channels::Registry.fetch(channel)
      adapter = entry.adapter
      message = render(entry, definition, content, params, recipient)

      delivery = NotificationDelivery.create!(
        request_id: request.id,
        company_id: request.company_id,
        notification_key: request.notification_key,
        category: request.category,
        recipient_type: request.recipient_type,
        recipient_id: request.recipient_id,
        channel: channel.to_s,
        address: adapter.contact_for(recipient),
        provider: adapter.provider_name,
        subject: message.try(:subject),
        body_text: message.text,
        content_hash: Digest::SHA256.hexdigest(message.text.to_s),
        decision_reason: reason,
        status: "pending",
        attempts: 1
      )

      send_delivery(request, delivery, adapter, message)
    end

    def retry_delivery(request, definition, params, recipient, delivery)
      entry = Channels::Registry.fetch(delivery.channel)
      message = render(entry, definition, definition.build_content(params), params, recipient)
      delivery.update!(attempts: delivery.attempts + 1)
      return if send_delivery(request, delivery, entry.adapter, message) == :sent

      # Falla definitiva en un reintento: igual que en el primer intento, se prueba el canal siguiente
      return if @policy.rule_for(request.category).fallback? && fallback_from(request, delivery.channel) == :sent

      fail_request(request)
    end

    # Ningún canal pudo entregar: el request queda failed y, si es crítica, se alerta
    def fail_request(request)
      finish(request, "failed", Reasons::PROVIDER_REJECTED)
      alert_undeliverable(request, Reasons::PROVIDER_REJECTED) if request.category == "critical"
    end

    def render(entry, definition, content, params, recipient)
      overrides = definition.overrides_for(entry.name, params, allowed: entry.renderer_class.allowed_overrides)
      entry.renderer.render(content: content, overrides: overrides, recipient: recipient, locale: I18n.default_locale)
    end

    # La llamada al proveedor va fuera de transacción; el resultado se registra en una sola transacción
    def send_delivery(request, delivery, adapter, message)
      provider_message_id = adapter.deliver(message: message, delivery: delivery)

      NotificationRequest.transaction do
        delivery.update!(status: "sent", provider_message_id: provider_message_id, sent_at: Time.current, last_error: nil)
        NotificationEvent.record!(:sent, request: request, delivery: delivery,
                                  payload: { channel: delivery.channel, provider: delivery.provider })
        request.update!(status: "completed", status_reason: nil)
      end
      :sent
    rescue PermanentDeliveryError => e
      NotificationRequest.transaction do
        delivery.update!(status: "failed", last_error: e.message)
        NotificationEvent.record!(:failed, request: request, delivery: delivery, payload: { error: e.message })
      end
      provider_error(request, delivery, e)
      :failed
    rescue TransientDeliveryError => e
      # Vuelve a quedar disponible para el reintento de retry_on
      NotificationRequest.transaction do
        delivery.update!(last_error: e.message)
        request.update!(status: "accepted", status_reason: Reasons::RETRYING)
      end
      provider_error(request, delivery, e)
      raise
    end

    def no_channels(request, resolution)
      if request.category == "critical"
        finish(request, "undeliverable", resolution.skip_reason, event: :undeliverable,
               payload: { resolver: resolution.reasons })
        alert_undeliverable(request, resolution.skip_reason)
      else
        finish(request, "skipped", resolution.skip_reason, event: :skipped, payload: { resolver: resolution.reasons })
      end
    end

    def drop(request, decision)
      if decision.reason == :expired
        finish(request, "expired", Reasons::EXPIRED, event: :expired, payload: decision.as_json)
      else
        finish(request, "skipped", decision.reason.to_s, event: :throttled, payload: decision.as_json)
      end
    end

    # Estado y job en la misma transacción (misma base): un request postergado nunca queda sin job
    def defer(request, decision)
      NotificationRequest.transaction do
        request.update!(status: "deferred", status_reason: decision.reason.to_s, scheduled_at: decision.until_time)
        NotificationEvent.record!(:deferred, request: request, payload: decision.as_json)
        DispatchJob.set(queue: Notifications.queue_for(request.category), wait_until: decision.until_time)
                   .perform_later(request.id)
      end
    end

    # Queda postergado; DigestJob lo incluirá en el resumen de las 08:00 locales
    def digest(request, decision)
      NotificationRequest.transaction do
        request.update!(status: "deferred", status_reason: Reasons::DIGEST, scheduled_at: decision.until_time)
        NotificationEvent.record!(:deferred, request: request, payload: decision.as_json)
      end
    end

    def finish(request, status, reason = nil, event: nil, payload: {})
      NotificationRequest.transaction do
        request.update!(status: status, status_reason: reason)
        NotificationEvent.record!(event, request: request, payload: { reason: reason }.merge(payload).compact) if event
      end
      request
    end

    def provider_error(request, delivery, error)
      ActiveSupport::Notifications.instrument(
        "provider_error.notifications",
        notification_key: request.notification_key, category: request.category, channel: delivery.channel,
        provider: delivery.provider, error: error.class.name, message: error.message,
        status: error.is_a?(TransientDeliveryError) ? "transient" : "permanent"
      )
    end

    def safe_definition(request)
      request.definition
    rescue UnknownNotificationError
      nil
    end
  end
end

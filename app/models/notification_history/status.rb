module NotificationHistory
  # Traduce estados internos a lenguaje simple para el administrador del cliente.
  # Nunca se muestran los estados internos: solo la etiqueta (I18n) y un tono visual.
  module Status
    Label = Data.define(:key, :tone) do
      def text = I18n.t("notification_history.statuses.#{key}")
    end

    # Eventos internos que el cliente no ve
    HIDDEN_EVENTS = %w[throttled_shadow recovered].freeze

    TONES = {
      delivered: :ok, digested: :ok, sent: :info, in_progress: :info,
      scheduled: :warn, rate_limited: :warn, digest_pending: :warn,
      bounced: :danger, dropped: :danger, failed: :danger, no_channel: :danger,
      opted_out: :neutral, cooldown: :neutral, entity_missing: :neutral, expired: :neutral
    }.freeze

    # Filtro de estado (valor del select -> condición SQL)
    FILTERS = {
      "delivered" => ->(r) { r.completed.where(delivery_exists(%w[delivered])) },
      "sent" => ->(r) { r.completed.where.not(status_reason: Notifications::Reasons::DIGESTED).where(delivery_exists(%w[sent pending])) },
      "not_delivered" => ->(r) { r.where(status: %w[undeliverable failed]).or(r.where(delivery_exists(%w[bounced dropped]))) },
      "deferred" => ->(r) { r.deferred },
      "digested" => ->(r) { r.completed.where(status_reason: Notifications::Reasons::DIGESTED) },
      "not_sent" => ->(r) { r.where(status: %w[skipped expired]) },
      "in_progress" => ->(r) { r.where(status: %w[accepted processing]) }
    }.freeze

    module_function

    def for(request, delivery)
      key = key_for(request, delivery)
      Label.new(key: key, tone: TONES.fetch(key))
    end

    def key_for(request, delivery)
      reason = request.status_reason

      case request.status
      when "completed"
        return :digested if reason == Notifications::Reasons::DIGESTED

        { "delivered" => :delivered, "bounced" => :bounced, "dropped" => :dropped, "failed" => :failed }
          .fetch(delivery&.status, :sent)
      when "deferred"
        { Notifications::Reasons::QUIET_HOURS => :scheduled, Notifications::Reasons::RATE_LIMIT => :rate_limited,
          Notifications::Reasons::DIGEST => :digest_pending }
          .fetch(reason, :scheduled)
      when "skipped"
        { Notifications::Reasons::OPTED_OUT => :opted_out, Notifications::Reasons::COOLDOWN => :cooldown,
          Notifications::Reasons::ENTITY_MISSING => :entity_missing }
          .fetch(reason, :no_channel)
      when "undeliverable" then reason == Notifications::Reasons::BOUNCED ? :bounced : :no_channel
      when "expired" then :expired
      when "failed" then :failed
      else :in_progress
      end
    end

    def filter(relation, value)
      FILTERS.fetch(value).call(relation)
    end

    def delivery_exists(statuses)
      sanitized = NotificationRequest.sanitize_sql_array([ "?", statuses ])
      "EXISTS (SELECT 1 FROM notification_deliveries d WHERE d.request_id = notification_requests.id " \
        "AND d.company_id = notification_requests.company_id AND d.status IN (#{sanitized}))"
    end

    def notification_name(key)
      I18n.t("notifications.#{key}.name", default: key.to_s.humanize)
    end

    # Canal en lenguaje simple; nil cuando la notificación no llegó a salir
    def channel_name(channel)
      return I18n.t("notification_history.channels.none") if channel.blank?

      I18n.t("notification_history.channels.#{channel}", default: channel.to_s.humanize)
    end

    def event_label(event)
      I18n.t("notification_history.events.#{event.event_type}", default: event.event_type.humanize)
    end
  end
end

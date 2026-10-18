module Notifications
  # Procesa un lote del Event Webhook de SendGrid: registra eventos y actualiza el estado de cada entrega.
  # Es idempotente: un evento repetido (mismo sg_event_id para la entrega) no cambia nada.
  class WebhookEventsJob < ApplicationJob
    queue_as :default

    # Evento de SendGrid -> tipo de notification_event
    EVENT_TYPES = {
      "delivered" => "delivered", "bounce" => "bounced", "dropped" => "dropped",
      "open" => "opened", "click" => "clicked",
      "spamreport" => "spam_report", "unsubscribe" => "unsubscribed", "group_unsubscribe" => "unsubscribed"
    }.freeze

    # Evento de SendGrid -> nuevo estado de la entrega, y desde qué estados se permite la transición
    TRANSITIONS = {
      "delivered" => [ "delivered", %w[pending sent] ],
      "bounce" => [ "bounced", %w[pending sent delivered] ],
      "dropped" => [ "dropped", %w[pending sent] ]
    }.freeze

    OPT_OUT_EVENTS = %w[spamreport unsubscribe group_unsubscribe].freeze

    def perform(events)
      events.each { |event| process(event) }
    end

    private

    def process(event)
      type = EVENT_TYPES[event["event"]]
      delivery = type && NotificationDelivery.find_by(id: event["delivery_id"])
      return unless delivery

      recorded = NotificationDelivery.transaction do
        delivery.lock!
        record(delivery, type, event)
      end
      return unless recorded

      opt_out(delivery) if OPT_OUT_EVENTS.include?(event["event"])
      fallback(delivery) if event["event"] == "bounce" && delivery.category == "critical"
    end

    # Devuelve false si el evento ya estaba registrado
    def record(delivery, type, event)
      provider_event_id = event["sg_event_id"]
      if provider_event_id && NotificationEvent.exists?(delivery_id: delivery.id, provider_event_id: provider_event_id)
        return false
      end

      NotificationEvent.record!(
        type, request: delivery.request_id, delivery: delivery, provider_event_id: provider_event_id,
        occurred_at: event["timestamp"] ? Time.zone.at(event["timestamp"].to_i) : Time.current,
        payload: event.slice("event", "reason", "type", "status", "url")
      )

      new_status, from = TRANSITIONS[event["event"]]
      delivery.update!(status: new_status) if new_status && from.include?(delivery.status)
      true
    end

    def opt_out(delivery)
      delivery.recipient&.opt_out!("engagement")
    end

    # Rebote de una crítica: intenta el siguiente canal de la política; si no hay, queda undeliverable con alerta
    def fallback(delivery)
      request = delivery.request
      dispatcher = Notifications::Dispatcher.new(request.id)
      return unless Notifications.policy.rule_for(request.category).fallback?
      return if dispatcher.fallback_from(request, delivery.channel) == :sent

      request.update!(status: "undeliverable", status_reason: "bounced")
      NotificationEvent.record!(:undeliverable, request: request, delivery: delivery, payload: { reason: "bounced" })
      dispatcher.alert_undeliverable(request, "bounced")
    end
  end
end

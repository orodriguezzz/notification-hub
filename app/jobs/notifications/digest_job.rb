module Notifications
  # Tarea horaria: envía UN correo resumen por destinatario con las engagement que excedieron su
  # presupuesto diario. Cada request queda postergado con scheduled_at = 08:00 locales del destinatario,
  # así que en cada corrida se toman los que ya cumplieron su hora.
  class DigestJob < ApplicationJob
    queue_as :bulk

    def perform(now: Time.current)
      due = NotificationRequest.deferred.where(status_reason: "digest", scheduled_at: ..now)
      due.distinct.pluck(:recipient_type, :recipient_id).each do |recipient_type, recipient_id|
        deliver_digest(recipient_type, recipient_id, now)
      end
    end

    private

    def deliver_digest(recipient_type, recipient_id, now)
      requests = claim(recipient_type, recipient_id, now)
      return if requests.empty?

      recipient = recipient_type.constantize.find_by(id: recipient_id)
      return finish_all(requests, "skipped", "entity_missing", :skipped) unless recipient

      expired, live = requests.partition { |request| request.expires_at&.<=(now) }
      finish_all(expired, "expired", "expired", :expired)
      return if live.empty?

      resolution = ChannelResolver.new.call(category: :engagement, company_id: live.first.company_id, recipient: recipient)
      entry = resolution.channels.map { Channels::Registry.fetch(_1) }.find { _1.renderer.respond_to?(:render_digest) }
      return finish_all(live, "skipped", resolution.skip_reason, :skipped) unless entry

      send_digest(entry, recipient, live)
    rescue TransientDeliveryError
      # Se reintenta en la próxima corrida
      NotificationRequest.where(id: Array(live).map(&:id))
                         .update_all(status: "deferred", scheduled_at: now + 1.hour, updated_at: Time.current)
    end

    # Toma los requests del destinatario y los marca processing, para que otra corrida no los duplique
    def claim(recipient_type, recipient_id, now)
      NotificationRequest.transaction do
        requests = NotificationRequest.deferred.lock("FOR UPDATE SKIP LOCKED")
                                      .where(status_reason: "digest", scheduled_at: ..now,
                                             recipient_type: recipient_type, recipient_id: recipient_id)
                                      .order(:created_at).to_a
        NotificationRequest.where(id: requests.map(&:id)).update_all(status: "processing", updated_at: now)
        requests
      end
    end

    def send_digest(entry, recipient, requests)
      contents = requests.filter_map do |request|
        request.definition.build_content(ParamSerializer.load(request.params))
      rescue ActiveJob::DeserializationError
        finish_all([ request ], "skipped", "entity_missing", :skipped)
        nil
      end
      requests = requests.reject(&:skipped?)
      return if contents.empty?

      adapter = entry.adapter
      message = entry.renderer.render_digest(contents: contents, recipient: recipient, locale: I18n.default_locale)
      first = requests.first

      delivery = NotificationDelivery.create!(
        request_id: first.id, company_id: first.company_id, notification_key: "daily_digest", category: "engagement",
        recipient_type: first.recipient_type, recipient_id: first.recipient_id, channel: entry.name.to_s,
        address: adapter.contact_for(recipient), provider: adapter.provider_name,
        subject: message.subject, body_text: message.text, content_hash: Digest::SHA256.hexdigest(message.text),
        decision_reason: { digest_request_ids: requests.map(&:id) }, status: "pending", attempts: 1
      )

      provider_message_id = deliver(adapter, message, delivery)

      # El resultado se registra en una sola transacción: entrega, evento y requests incluidos
      NotificationRequest.transaction do
        delivery.update!(status: "sent", provider_message_id: provider_message_id, sent_at: Time.current)
        NotificationEvent.record!(:sent, request: first, delivery: delivery, payload: { digest: true })
        finish_all(requests, "completed", "digested", :digested, delivery_id: delivery.id)
      end
    rescue PermanentDeliveryError => e
      NotificationRequest.transaction do
        delivery&.update!(status: "failed", last_error: e.message)
        finish_all(requests, "failed", "provider_rejected", :failed)
      end
    end

    # Un error transitorio cierra esta entrega como fallida (no queda pendiente para siempre) y se
    # propaga: deliver_digest devuelve los requests a deferred y la próxima corrida crea una entrega nueva.
    def deliver(adapter, message, delivery)
      adapter.deliver(message: message, delivery: delivery)
    rescue TransientDeliveryError => e
      delivery.update!(status: "failed", last_error: "#{e.message} (se reintenta en la próxima corrida)")
      raise
    end

    def finish_all(requests, status, reason, event, **payload)
      requests.each do |request|
        request.update!(status: status, status_reason: reason)
        NotificationEvent.record!(event, request: request, delivery: payload[:delivery_id],
                                  payload: { reason: reason }.merge(payload).compact)
      end
    end
  end
end

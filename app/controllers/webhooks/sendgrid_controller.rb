module Webhooks
  # Event Webhook firmado de SendGrid. Verifica la firma y procesa el lote en un job para responder rápido.
  class SendgridController < ActionController::API
    SIGNATURE_HEADER = "X-Twilio-Email-Event-Webhook-Signature".freeze
    TIMESTAMP_HEADER = "X-Twilio-Email-Event-Webhook-Timestamp".freeze

    # Ventana anti-replay: el timestamp firmado debe ser reciente, con margen para el desfase de relojes.
    # Un lote firmado capturado no se puede reenviar más tarde.
    MAX_AGE = 15.minutes
    MAX_CLOCK_SKEW = 5.minutes

    def create
      return head :unauthorized unless valid_signature?

      events = JSON.parse(request.raw_post)
      return head :bad_request unless events.is_a?(Array)

      Notifications::WebhookEventsJob.perform_later(events)
      head :accepted
    rescue JSON::ParserError
      head :bad_request
    end

    private

    def valid_signature?
      public_key = Rails.configuration.x.notifications.webhook_public_key
      signature = request.headers[SIGNATURE_HEADER]
      timestamp = request.headers[TIMESTAMP_HEADER]
      return false if public_key.blank? || signature.blank? || timestamp.blank?
      return false unless fresh?(timestamp)

      webhook = SendGrid::EventWebhook.new
      webhook.verify_signature(webhook.convert_public_key_to_ecdsa(public_key), request.raw_post, signature, timestamp)
    rescue OpenSSL::PKey::PKeyError, ArgumentError
      false
    end

    def fresh?(timestamp)
      Time.zone.at(Integer(timestamp, 10)).between?(MAX_AGE.ago, MAX_CLOCK_SKEW.from_now)
    rescue ArgumentError, TypeError
      false
    end
  end
end

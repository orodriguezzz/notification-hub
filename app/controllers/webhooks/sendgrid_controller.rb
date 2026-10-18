module Webhooks
  # Event Webhook firmado de SendGrid. Verifica la firma y procesa el lote en un job para responder rápido.
  class SendgridController < ActionController::API
    SIGNATURE_HEADER = "X-Twilio-Email-Event-Webhook-Signature".freeze
    TIMESTAMP_HEADER = "X-Twilio-Email-Event-Webhook-Timestamp".freeze

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

      webhook = SendGrid::EventWebhook.new
      webhook.verify_signature(webhook.convert_public_key_to_ecdsa(public_key), request.raw_post, signature, timestamp)
    rescue OpenSSL::PKey::PKeyError, ArgumentError
      false
    end
  end
end

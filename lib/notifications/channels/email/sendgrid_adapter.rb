require "sendgrid-ruby"

module Notifications
  module Channels
    module Email
      # Envío real vía SendGrid API v3 (mail/send)
      class SendgridAdapter < BaseAdapter
        NETWORK_ERRORS = [ Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH,
                           SocketError, OpenSSL::SSL::SSLError, EOFError, Net::OpenTimeout, Net::ReadTimeout ].freeze

        # Timeouts cortos: un SendGrid lento no debe bloquear los threads del worker (por defecto Net::HTTP espera 60 s).
        # Un timeout es un error transitorio y el envío se reintenta.
        HTTP_OPTIONS = { open_timeout: 5, read_timeout: 10 }.freeze

        def initialize(api_key: self.class.api_key, from: Rails.configuration.x.notifications.from_email,
                       sandbox: Rails.configuration.x.notifications.sendgrid_sandbox)
          @api_key = api_key
          @from = from
          @sandbox = sandbox
        end

        # La API key vive en credentials (sendgrid.api_key); ENV solo como respaldo local
        def self.api_key
          Rails.application.credentials.dig(:sendgrid, :api_key) || ENV["SENDGRID_API_KEY"]
        end

        def provider_name = "sendgrid"

        def deliver(message:, delivery:)
          raise PermanentDeliveryError, "Falta la API key de SendGrid" if @api_key.blank?

          response = client.mail._("send").post(request_body: payload(message, delivery))
          handle_response(response)
        rescue *NETWORK_ERRORS => e
          raise TransientDeliveryError, "Error de red con SendGrid: #{e.class}: #{e.message}"
        end

        def payload(message, delivery)
          body = {
            personalizations: [ { to: [ { email: delivery.address } ] } ],
            from: { email: @from },
            subject: message.subject,
            content: [
              { type: "text/plain", value: message.text },
              { type: "text/html", value: message.html }
            ],
            custom_args: { delivery_id: delivery.id.to_s, request_id: delivery.request_id.to_s },
            categories: [ delivery.notification_key ]
          }

          headers = unsubscribe_headers(delivery)
          body[:headers] = headers if headers.any?
          body[:mail_settings] = { sandbox_mode: { enable: true } } if @sandbox
          body
        end

        private

        def client
          api.client
        end

        def api
          SendGrid::API.new(api_key: @api_key, http_options: HTTP_OPTIONS)
        end

        def handle_response(response)
          status = response.status_code.to_i

          case status
          when 200..299
            message_id = response.headers&.dig("x-message-id")
            Array(message_id).first || "sendgrid-#{SecureRandom.hex(8)}"
          when 429, 500..599
            raise TransientDeliveryError, "SendGrid respondió #{status}: #{response.body}"
          else
            raise PermanentDeliveryError, "SendGrid respondió #{status}: #{response.body}"
          end
        end
      end
    end
  end
end

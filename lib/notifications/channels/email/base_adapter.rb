module Notifications
  module Channels
    module Email
      # Comportamiento común de los adaptadores de email
      class BaseAdapter < Channels::BaseAdapter
        def contact_for(recipient)
          recipient.try(:email).presence
        end

        private

        # Headers de desuscripción en un clic (RFC 8058) para la categoría engagement
        def unsubscribe_headers(delivery)
          return {} unless delivery.category == "engagement"

          recipient = delivery.recipient
          return {} unless recipient

          url = Notifications::UnsubscribeToken.url_for(recipient)
          { "List-Unsubscribe" => "<#{url}>", "List-Unsubscribe-Post" => "List-Unsubscribe=One-Click" }
        end
      end
    end
  end
end

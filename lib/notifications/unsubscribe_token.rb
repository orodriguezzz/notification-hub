module Notifications
  # Token firmado (MessageVerifier) para desuscribirse sin login
  module UnsubscribeToken
    PURPOSE = :notifications_unsubscribe

    module_function

    def generate(recipient, category: "engagement")
      verifier.generate({ "type" => recipient.class.polymorphic_name, "id" => recipient.id, "category" => category.to_s },
                        purpose: PURPOSE)
    end

    # Devuelve [destinatario, categoría] o nil si el token es inválido
    def resolve(token)
      data = verifier.verified(token, purpose: PURPOSE)
      return unless data.is_a?(Hash) && data["type"] == "Employee"

      recipient = Employee.find_by(id: data["id"])
      recipient && [ recipient, data["category"] ]
    end

    def url_for(recipient)
      "#{Rails.configuration.x.app_host}/unsubscribe/#{generate(recipient)}"
    end

    def verifier
      Rails.application.message_verifier(PURPOSE)
    end
  end
end

module Notifications
  module Channels
    # Entrega el mensaje renderizado al proveedor.
    #   - deliver: devuelve el provider_message_id o lanza TransientDeliveryError / PermanentDeliveryError
    #   - contact_for: dato de contacto del destinatario para este canal (nil si no tiene)
    class BaseAdapter
      def deliver(message:, delivery:) = raise NotImplementedError
      def contact_for(recipient) = raise NotImplementedError

      def provider_name
        self.class.name.demodulize.underscore.delete_suffix("_adapter")
      end
    end
  end
end

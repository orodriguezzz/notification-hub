module Notifications
  module Channels
    # Traduce el contenido semántico al formato del canal.
    # El mensaje devuelto debe responder a `text` (se guarda cifrado en la entrega) y,
    # si el canal lo tiene, a `subject`.
    class BaseRenderer
      # Opciones de presentación que una definición puede refinar para este canal
      def self.allowed_overrides = []

      def render(content:, overrides:, recipient:, locale:) = raise NotImplementedError
    end
  end
end

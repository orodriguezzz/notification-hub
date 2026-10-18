module Notifications
  class Error < StandardError; end

  # Definición inválida: falta un campo obligatorio, categoría desconocida, key duplicada, etc.
  # Se lanza al cargar la clase.
  class DefinitionError < Error; end

  # Parámetros inválidos al llamar a deliver: es un error de programación, falla rápido.
  class InvalidParamsError < ArgumentError; end

  class UnknownNotificationError < Error; end
  class UnknownChannelError < Error; end

  # Error de entrega reintentable (red, 429, 5xx del proveedor)
  class TransientDeliveryError < Error; end

  # Error de entrega definitivo (4xx del proveedor salvo 429): no se reintenta
  class PermanentDeliveryError < Error; end
end

# Núcleo de la central de notificaciones.
#
#   - Definición (API 1.1): ApplicationNotification + Notifications::DefinitionDsl
#   - Envío (API 1.2):      Notifications::Enqueuer (outbox transaccional, solo escribe en PostgreSQL)
#   - Despacho:             Notifications::Dispatcher (asíncrono, vía Notifications::DispatchJob)
#   - Política de canales:  Notifications::Policy + config/notifications/channel_policy.rb
module Notifications
  # Categorías de notificación y la cola de Solid Queue de cada una. Es la ÚNICA lista: el DSL de
  # definición, la política y el despacho la leen de aquí. Agregar una categoría = una entrada aquí
  # y su bloque de reglas en config/notifications/channel_policy.rb (la política valida que exista).
  CATEGORIES = { critical: "critical", operational: "default", engagement: "bulk" }.freeze
  DIGEST_QUEUE = "bulk".freeze

  def self.categories
    CATEGORIES.keys
  end

  def self.queue_for(category)
    CATEGORIES.fetch(category.to_sym)
  end

  def self.policy
    Notifications::Policy.current
  end

  # --- Errores ------------------------------------------------------------------------------

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

# Núcleo de la central de notificaciones.
#
#   - Definición (API 1.1): ApplicationNotification + Notifications::DefinitionDsl
#   - Envío (API 1.2):      Notifications::Enqueuer (outbox transaccional, solo escribe en PostgreSQL)
#   - Despacho:             Notifications::Dispatcher (asíncrono, vía Notifications::DispatchJob)
#   - Política de canales:  Notifications::Policy + config/notifications/channel_policy.rb
module Notifications
  # Cola de Solid Queue según la categoría
  QUEUES = { critical: "critical", operational: "default", engagement: "bulk" }.freeze
  DIGEST_QUEUE = "bulk".freeze

  def self.queue_for(category)
    QUEUES.fetch(category.to_sym)
  end

  def self.policy
    Notifications::Policy.current
  end

  # Las clases de error viven juntas en un solo archivo (no siguen la convención de Zeitwerk),
  # así que se cargan explícitamente con `load` para que sobrevivan a la recarga de código.
  load File.expand_path("notifications/errors.rb", __dir__)
end

# Clase base de todas las notificaciones (API 1.1). Ver Notifications::DefinitionDsl.
#
# Una notificación se define UNA vez, con contenido semántico (título, cuerpo, acción),
# sin mencionar canales ni direcciones. La política central decide por dónde sale.
class ApplicationNotification
  include Notifications::DefinitionDsl

  # Helpers de rutas para armar las URLs de acción
  def self.routes
    Rails.application.routes.url_helpers
  end
end

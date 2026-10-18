require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module NotificationHub
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # lib/notifications es el núcleo de la central y se carga con Zeitwerk.
    # El cop de RuboCop y el generador se cargan por su cuenta; errors.rb lo carga lib/notifications.rb.
    config.autoload_lib(ignore: %w[assets tasks rubocop generators notifications/errors.rb])

    # Interfaz en español neutro
    config.i18n.default_locale = :es
    config.i18n.available_locales = %i[es en]
    config.i18n.fallbacks = [ :es ]

    # Las tablas particionadas, el trigger de inmutabilidad y uuidv7() no caben en schema.rb
    config.active_record.schema_format = :sql

    # Solid Queue en la base principal, en todos los entornos: encolar es atómico con el negocio
    config.active_job.queue_adapter = :solid_queue
    # La auditoría vive en notification_events, no en la cola
    config.solid_queue.preserve_finished_jobs = false

    # Central de notificaciones
    config.x.notifications.email_adapter = ENV.fetch("NOTIFICATIONS_EMAIL_ADAPTER", "sendgrid").to_sym
    config.x.notifications.from_email = ENV.fetch("SENDGRID_FROM_EMAIL", "notificaciones@notification-hub.test")
    config.x.notifications.sendgrid_sandbox = ENV.fetch("SENDGRID_SANDBOX", "true") == "true"
    config.x.notifications.webhook_public_key = ENV["SENDGRID_WEBHOOK_PUBLIC_KEY"]
    config.x.app_host = ENV.fetch("APP_HOST", "http://localhost:3000")

    # Modo demo: selector de usuario simulado y Swagger (/api-docs). Siempre activo en local;
    # en un servidor se activa solo con DEMO_MODE=true (no hay autenticación real).
    config.x.demo_mode = Rails.env.local? || ENV["DEMO_MODE"] == "true"
  end
end

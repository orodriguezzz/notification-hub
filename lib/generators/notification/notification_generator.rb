require "rails/generators/named_base"

# bin/rails g notification SurveyClosed --category=engagement --owner=people_team
# Crea la definición, sus claves I18n y un test.
class NotificationGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  class_option :category, type: :string, required: true, desc: "Categoría (ver Notifications::CATEGORIES)"
  class_option :owner, type: :string, required: true, desc: "Equipo dueño (p. ej. people_team)"
  class_option :recipient, type: :string, default: "employee", desc: "Tipo de destinatario"

  LOCALE_FILE = "config/locales/notifications.es.yml".freeze

  def validate_options
    categories = Notifications.categories.map(&:to_s)
    return if categories.include?(options[:category])

    raise Thor::Error, "Categoría inválida: #{options[:category]} (usa #{categories.join(', ')})"
  end

  def create_definition
    template "notification.rb.tt", File.join("app/notifications", "#{notification_key}_notification.rb")
  end

  def add_translations
    translations = <<~YAML.indent(4)
      #{notification_key}:
        name: "#{human_name}"
        title: "#{human_name}"
        body: "Completa el cuerpo de la notificación."
        action: "Ver más"
    YAML

    insert_into_file LOCALE_FILE, translations, after: "  notifications:\n"
  end

  def create_test
    template "notification_test.rb.tt", File.join("test/notifications", "#{notification_key}_notification_test.rb")
  end

  private

  def notification_key
    file_name.delete_suffix("_notification")
  end

  def notification_class
    "#{notification_key.camelize}Notification"
  end

  def recipient
    options[:recipient].underscore
  end
end

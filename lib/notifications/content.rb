module Notifications
  # Contenido semántico de una notificación: no menciona ningún canal. Inmutable.
  Content = Data.define(:title, :body, :action_label, :action_url) do
    def action?
      action_url.present?
    end
  end

  # Contexto en el que se evalúa el bloque `content do |p| ... end` de una definición
  class Content::Builder
    def initialize(definition)
      @definition = definition
      @values = {}
    end

    # t(".x") resuelve a notifications.<key>.x; falla si la traducción no existe
    def t(key, **options)
      key = "notifications.#{@definition.notification_key}#{key}" if key.to_s.start_with?(".")
      I18n.t(key, **options, raise: true)
    end

    def routes
      Rails.application.routes.url_helpers
    end

    def title(value)
      @values[:title] = value
    end

    def body(value)
      @values[:body] = value
    end

    def action(label, url:)
      @values[:action_label] = label
      @values[:action_url] = url
    end

    def build
      missing = %i[title body].select { |field| @values[field].blank? }
      if missing.any?
        raise DefinitionError, "#{@definition.name}: el contenido debe declarar #{missing.join(' y ')}"
      end

      Content.new(title: @values[:title], body: @values[:body],
                  action_label: @values[:action_label], action_url: @values[:action_url])
    end
  end
end

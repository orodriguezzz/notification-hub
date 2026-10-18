module Notifications
  # Registro de todas las definiciones de notificación (app/notifications).
  # Guarda nombres de clase para no retener clases viejas tras una recarga de código.
  module Registry
    @definitions = {}
    @mutex = Mutex.new
    @eager_loaded = false

    class << self
      def register(definition)
        key = definition.notification_key.to_s

        @mutex.synchronize do
          existing = @definitions[key]
          if existing && existing != definition.name
            raise DefinitionError, "La key :#{key} de #{definition.name} ya está registrada por #{existing}"
          end

          @definitions[key] = definition.name
        end
      end

      def unregister(key)
        @mutex.synchronize { @definitions.delete(key.to_s) }
      end

      def all
        eager_load!
        @definitions.values.map(&:constantize)
      end

      def keys
        eager_load!
        @definitions.keys
      end

      def fetch(key)
        eager_load! unless @definitions.key?(key.to_s)
        name = @definitions[key.to_s]
        raise UnknownNotificationError, "No existe una notificación con key :#{key}" unless name

        name.constantize
      end

      def registered?(key)
        eager_load!
        @definitions.key?(key.to_s)
      end

      # Carga todas las clases de app/notifications (en producción ya están cargadas por eager_load)
      def eager_load!
        return if @eager_loaded

        dir = Rails.root.join("app/notifications")
        Rails.autoloaders.main.eager_load_dir(dir) if dir.exist?
        @eager_loaded = true
      end
    end
  end
end

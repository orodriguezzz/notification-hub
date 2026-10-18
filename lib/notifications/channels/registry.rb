module Notifications
  module Channels
    # Canales disponibles para la central. Agregar un canal no toca ninguna definición:
    #
    #   Notifications::Channels::Registry.register(:sms, renderer: Sms::Renderer, adapter: Sms::TwilioAdapter)
    module Registry
      Entry = Data.define(:name, :renderer_class, :adapter_source) do
        def renderer = renderer_class.new

        # El adaptador puede registrarse como clase o como bloque que devuelve una instancia
        def adapter
          adapter_source.respond_to?(:call) ? adapter_source.call : adapter_source.new
        end
      end

      @entries = {}

      class << self
        def register(name, renderer:, adapter:)
          @entries[name.to_sym] = Entry.new(name: name.to_sym, renderer_class: renderer, adapter_source: adapter)
        end

        def unregister(name)
          @entries.delete(name.to_sym)
        end

        def fetch(name)
          @entries.fetch(name.to_sym) { raise UnknownChannelError, "Canal no registrado: #{name}" }
        end

        def registered?(name)
          @entries.key?(name.to_sym)
        end

        def names
          @entries.keys
        end

        def entries
          @entries.values
        end
      end
    end
  end
end

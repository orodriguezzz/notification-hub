module Notifications
  # Parámetros de una notificación, accesibles como métodos: `p.employee`, `p.company`
  class ParamSet
    def initialize(values)
      @values = values.to_h.symbolize_keys.freeze
    end

    def [](name)
      @values[name.to_sym]
    end

    def to_h
      @values
    end

    def method_missing(name, *args)
      return @values[name] if args.empty? && @values.key?(name)

      super
    end

    def respond_to_missing?(name, include_private = false)
      @values.key?(name) || super
    end
  end
end

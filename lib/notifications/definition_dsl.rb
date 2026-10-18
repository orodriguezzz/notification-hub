module Notifications
  # DSL para definir notificaciones (API 1.1). Una clase por notificación en app/notifications.
  #
  #   class BirthdayNotification < ApplicationNotification
  #     key :birthday
  #     category :engagement
  #     owner :people_team
  #     recipient :employee
  #     param :employee, required: true
  #     content { |p| title t(".title", name: p.employee.first_name) ... }
  #   end
  #
  # La definición se valida al cerrar la clase (`end`): si falta algo obligatorio,
  # la carga falla con Notifications::DefinitionError.
  module DefinitionDsl
    REQUIRED = %i[key category owner recipient content].freeze
    KEY_FORMAT = /\A[a-z][a-z0-9_]*\z/

    def self.included(base)
      base.extend(ClassMethods)
    end

    # Ejecuta finalize_definition! cuando termina el cuerpo de la clase.
    # Las clases anónimas (Class.new) no tienen `end` detectable: se finalizan a mano.
    def self.finalize_on_class_end(definition)
      return if definition.name.nil?

      trace = TracePoint.new(:end) do |tp|
        next unless tp.self.equal?(definition)

        trace.disable
        definition.finalize_definition!
      end
      trace.enable
    end

    # Contexto de los bloques de refinamiento por canal (`email do ... end`).
    # Solo acepta las opciones de presentación que declara el renderer del canal.
    class OverrideBuilder
      def initialize(definition, channel, allowed)
        @definition = definition
        @channel = channel
        @allowed = allowed
        @values = {}
      end

      def t(key, **options)
        key = "notifications.#{@definition.notification_key}#{key}" if key.to_s.start_with?(".")
        I18n.t(key, **options, raise: true)
      end

      def method_missing(name, *args)
        if @allowed.include?(name) && args.size == 1
          @values[name] = args.first
        else
          raise DefinitionError,
                "#{@definition.name}: `#{name}` no es un refinamiento válido para #{@channel} " \
                "(permitidos: #{@allowed.join(', ')})"
        end
      end

      def respond_to_missing?(name, include_private = false)
        @allowed.include?(name) || super
      end

      def to_h
        @values
      end
    end

    module ClassMethods
      def inherited(subclass)
        super
        Notifications::DefinitionDsl.finalize_on_class_end(subclass)
      end

      # --- Declaraciones -------------------------------------------------------

      def key(value)
        unless value.to_s.match?(KEY_FORMAT)
          raise DefinitionError, "#{name}: la key debe ser snake_case (recibido #{value.inspect})"
        end

        @notification_key = value.to_sym
      end

      def category(value = nil)
        return @category if value.nil?

        unless Notifications.categories.include?(value.to_sym)
          raise DefinitionError, "#{name}: categoría #{value.inspect} inválida (usa #{Notifications.categories.join(', ')})"
        end

        @category = value.to_sym
      end

      def owner(value = nil)
        return @owner if value.nil?

        @owner = value.to_sym
      end

      def recipient(value = nil)
        return @recipient_type if value.nil?

        @recipient_type = value.to_sym
      end

      def param(param_name, required: false)
        params_schema[param_name.to_sym] = { required: required }
      end

      def cooldown(value = nil)
        return @cooldown if value.nil?

        @cooldown = value
      end

      def expires_in(value = nil)
        return @expires_in if value.nil?

        @expires_in = value
      end

      def version(value = nil)
        return @version || 1 if value.nil?

        @version = Integer(value)
      end

      def dedupe_by(&block)
        @dedupe_block = block
      end

      def content(&block)
        @content_block = block
      end

      def preview(&block)
        @preview_block = block
      end

      # Refina la presentación de un canal puntual sin afectar a los demás
      def channel_override(channel, &block)
        channel_overrides[channel.to_sym] = block
      end

      def email(&block)
        channel_override(:email, &block)
      end

      # --- Lectura -------------------------------------------------------------

      def notification_key
        @notification_key
      end

      def params_schema
        @params_schema ||= {}
      end

      def channel_overrides
        @channel_overrides ||= {}
      end

      def recipient_class
        @recipient_type.to_s.camelize.constantize
      end

      def finalize_definition!
        missing = REQUIRED.reject do |field|
          case field
          when :key then @notification_key
          when :recipient then @recipient_type
          when :content then @content_block
          else instance_variable_get("@#{field}")
          end
        end
        raise DefinitionError, "#{name}: falta declarar #{missing.join(', ')}" if missing.any?

        Notifications::Registry.register(self)
        self
      end

      # --- Uso por la central --------------------------------------------------

      def build_content(params, locale: I18n.default_locale)
        params = ParamSet.new(params) unless params.is_a?(ParamSet)
        builder = Content::Builder.new(self)
        I18n.with_locale(locale) { builder.instance_exec(params, &@content_block) }
        builder.build
      end

      def overrides_for(channel, params, allowed:, locale: I18n.default_locale)
        block = channel_overrides[channel.to_sym]
        return {} unless block

        params = ParamSet.new(params) unless params.is_a?(ParamSet)
        builder = OverrideBuilder.new(self, channel, allowed)
        I18n.with_locale(locale) { builder.instance_exec(params, &block) }
        builder.to_h
      end

      def dedupe_key(params)
        return unless @dedupe_block

        Array(@dedupe_block.call(ParamSet.new(params))).join(":")
      end

      def preview_params
        raise DefinitionError, "#{name}: falta declarar preview" unless @preview_block

        instance_exec(&@preview_block).to_h.symbolize_keys
      end

      # Valida los parámetros contra la definición y agrega el destinatario si es un param
      def normalize_params(to, params)
        unless to.is_a?(recipient_class)
          raise InvalidParamsError, "#{name}: el destinatario debe ser #{recipient_class.name} (recibido #{to.class.name})"
        end

        params = params.to_h.symbolize_keys
        params[@recipient_type] = to if params_schema.key?(@recipient_type) && !params.key?(@recipient_type)

        unknown = params.keys - params_schema.keys
        raise InvalidParamsError, "#{name}: parámetros no declarados: #{unknown.join(', ')}" if unknown.any?

        missing = params_schema.select { |param_name, options| options[:required] && params[param_name].nil? }.keys
        raise InvalidParamsError, "#{name}: faltan parámetros requeridos: #{missing.join(', ')}" if missing.any?

        params
      end

      # --- API de envío (1.2) --------------------------------------------------

      def deliver(to:, params: {}, idempotency_key: nil)
        Notifications::Enqueuer.new(self).deliver(to: to, params: params, idempotency_key: idempotency_key)
      end

      def deliver_many(to:, params: {})
        Notifications::Enqueuer.new(self).deliver_many(to: to, params: params)
      end

      # Alias de compatibilidad con el enunciado (`Notification.sent()`)
      def sent(**options)
        deliver(**options)
      end
    end
  end
end

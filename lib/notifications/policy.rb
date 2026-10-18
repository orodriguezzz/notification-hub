module Notifications
  # Política central de canales y anti-spam (D4 + D7). Se declara en
  # config/notifications/channel_policy.rb; los equipos solo declaran `category`.
  class Policy
    STRATEGIES = %i[first_available fallback].freeze
    OVERFLOWS = %i[defer digest].freeze
    PATH = "config/notifications/channel_policy.rb".freeze

    CategoryRule = Struct.new(:name, :strategy, :channels, :bypass_preferences, :bypass_rate_limit, keyword_init: true) do
      def bypass_preferences? = !!bypass_preferences
      def bypass_rate_limit? = !!bypass_rate_limit
      def fallback? = strategy == :fallback
    end

    RateLimit = Struct.new(:category, :max, :per, :overflow, keyword_init: true)

    QuietHours = Struct.new(:from, :to, :except, keyword_init: true) do
      def applies_to?(category)
        !Array(except).map(&:to_sym).include?(category.to_sym)
      end

      def from_minutes = minutes(from)
      def to_minutes = minutes(to)

      # ¿Es horario de silencio en esta hora local?
      def active_at?(local_time)
        now = local_time.hour * 60 + local_time.min
        if from_minutes > to_minutes
          now >= from_minutes || now < to_minutes
        else
          now >= from_minutes && now < to_minutes
        end
      end

      # Próximo término del horario de silencio (p. ej. 08:00 locales)
      def next_end_after(local_time)
        candidate = at(local_time, local_time.to_date)
        candidate <= local_time ? at(local_time, local_time.to_date + 1) : candidate
      end

      # Hora de término en un día dado
      def at(reference, date)
        hour, minute = to.split(":").map(&:to_i)
        reference.time_zone.local(date.year, date.month, date.day, hour, minute)
      end

      private

      def minutes(value)
        hour, minute = value.split(":").map(&:to_i)
        hour * 60 + minute
      end
    end

    attr_reader :rules, :rate_limits
    attr_accessor :quiet_hours, :shadow_mode

    def initialize
      @rules = {}
      @rate_limits = {}
      @quiet_hours = nil
      @shadow_mode = true
    end

    class << self
      attr_writer :current

      def define(&block)
        builder = Builder.new
        builder.instance_eval(&block)
        self.current = builder.policy.validate!
      end

      def current
        @current || load_default!
      end

      def load_default!
        load Rails.root.join(PATH).to_s
        @current
      end
    end

    def rule_for(category)
      rules.fetch(category.to_sym) { raise DefinitionError, "La política no define la categoría #{category}" }
    end

    def rate_limit_for(category)
      rate_limits[category.to_sym]
    end

    def shadow_mode?
      !!shadow_mode
    end

    def validate!
      missing = DefinitionDsl::CATEGORIES - rules.keys
      raise DefinitionError, "La política no define las categorías #{missing.join(', ')}" if missing.any?

      self
    end

    # Copia profunda, útil para cambiar la política en un test sin afectar a los demás
    def deep_copy
      Marshal.load(Marshal.dump(self))
    end

    class Builder
      attr_reader :policy

      def initialize
        @policy = Policy.new
      end

      def category(name, &block)
        rule = CategoryRule.new(name: name.to_sym, strategy: :first_available, channels: [],
                                bypass_preferences: false, bypass_rate_limit: false)
        CategoryBuilder.new(rule).instance_eval(&block)
        raise DefinitionError, "La categoría #{name} no declara canales" if rule.channels.empty?

        policy.rules[rule.name] = rule
      end

      def rate_limit(category, max:, per: :day, overflow: :defer)
        raise DefinitionError, "rate_limit solo admite per: :day" unless per == :day
        raise DefinitionError, "overflow inválido: #{overflow}" unless OVERFLOWS.include?(overflow)

        policy.rate_limits[category.to_sym] = RateLimit.new(category: category.to_sym, max: max, per: per, overflow: overflow)
      end

      def quiet_hours(from:, to:, except: [])
        policy.quiet_hours = QuietHours.new(from: from, to: to, except: Array(except))
      end

      def shadow_mode(enabled)
        policy.shadow_mode = enabled
      end
    end

    class CategoryBuilder
      def initialize(rule)
        @rule = rule
      end

      def strategy(value)
        raise DefinitionError, "Estrategia inválida: #{value}" unless STRATEGIES.include?(value)

        @rule.strategy = value
      end

      def channels(*names)
        @rule.channels = names.flatten.map(&:to_sym)
      end

      def bypass_preferences!
        @rule.bypass_preferences = true
      end

      def bypass_rate_limit!
        @rule.bypass_rate_limit = true
      end
    end
  end
end

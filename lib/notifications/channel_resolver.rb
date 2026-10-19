module Notifications
  # Decide por qué canales puede salir un envío. Tres capas, en orden:
  #   1. Política: canales de la categoría, en orden.
  #   2. Disponibilidad: kill switch global y por empresa (NotificationChannelSetting).
  #   3. Destinatario: tiene dato de contacto y no se desuscribió de la categoría (salvo críticas).
  class ChannelResolver
    Resolution = Data.define(:channels, :reasons, :rule) do
      def empty? = channels.empty?

      # Motivo resumido cuando no queda ningún canal
      def skip_reason
        values = reasons.values
        return Reasons::OPTED_OUT if values.include?(Reasons::OPTED_OUT)
        return Reasons::NO_CONTACT if values.include?(Reasons::NO_CONTACT)
        return Reasons::CHANNEL_DISABLED if values.any? { _1.start_with?("disabled") }

        Reasons::NO_CHANNEL
      end
    end

    def initialize(policy = Notifications.policy)
      @policy = policy
    end

    def call(category:, company_id:, recipient:, only: nil)
      rule = @policy.rule_for(category)
      candidates = only ? rule.channels & Array(only).map(&:to_sym) : rule.channels
      reasons = {}

      channels = candidates.select do |channel|
        reason = unavailability(channel, rule, company_id, recipient)
        reasons[channel] = reason || "available"
        reason.nil?
      end

      Resolution.new(channels: channels, reasons: reasons, rule: rule)
    end

    private

    def unavailability(channel, rule, company_id, recipient)
      return "not_registered" unless Channels::Registry.registered?(channel)

      setting = NotificationChannelSetting.unavailability_for(channel, company_id: company_id)
      return setting.to_s if setting

      return Reasons::NO_CONTACT if Channels::Registry.fetch(channel).adapter.contact_for(recipient).blank?

      if !rule.bypass_preferences? && recipient.respond_to?(:opted_out?) && recipient.opted_out?(rule.name)
        return Reasons::OPTED_OUT
      end

      nil
    end
  end
end

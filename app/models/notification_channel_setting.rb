# Disponibilidad de un canal: global (company_id nulo) o por empresa. Sin fila = habilitado.
class NotificationChannelSetting < ApplicationRecord
  belongs_to :company, optional: true

  validates :channel, presence: true, uniqueness: { scope: :company_id }

  scope :global, -> { where(company_id: nil) }

  # Devuelve :disabled_global, :disabled_company o nil si el canal está disponible
  def self.unavailability_for(channel, company_id:)
    disabled = where(channel: channel.to_s, company_id: [ nil, company_id ].uniq, enabled: false).pluck(:company_id)
    return :disabled_global if disabled.include?(nil)
    return :disabled_company if disabled.any?

    nil
  end

  def self.enabled?(channel, company_id:)
    unavailability_for(channel, company_id: company_id).nil?
  end

  def global?
    company_id.nil?
  end
end

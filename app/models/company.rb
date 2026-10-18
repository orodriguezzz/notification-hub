class Company < ApplicationRecord
  COUNTRIES = %w[CL PE CO MX].freeze

  has_many :employees, dependent: :destroy
  has_many :users, dependent: :destroy
  has_many :notification_channel_settings, dependent: :delete_all

  validates :name, presence: true
  validates :country, inclusion: { in: COUNTRIES }
  validates :time_zone, presence: true
  validate { errors.add(:time_zone, :invalid) if time_zone.present? && ActiveSupport::TimeZone[time_zone].nil? }

  def zone
    ActiveSupport::TimeZone[time_zone]
  end
end

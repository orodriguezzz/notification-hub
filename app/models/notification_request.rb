# Intención de enviar una notificación (outbox). Tabla particionada por mes:
# la PK física es (id, created_at), pero la app identifica por id.
class NotificationRequest < ApplicationRecord
  self.primary_key = :id

  STATUSES = %w[accepted processing deferred completed skipped expired undeliverable failed].freeze
  PENDING_STATUSES = %w[accepted deferred].freeze

  enum :status, STATUSES.index_by(&:itself), validate: true

  has_many :deliveries, class_name: "NotificationDelivery", foreign_key: :request_id, inverse_of: :request
  has_many :events, class_name: "NotificationEvent", foreign_key: :request_id, inverse_of: :request

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def definition
    Notifications::Registry.fetch(notification_key)
  end

  def recipient
    Notifications::Recipients.find(recipient_type, recipient_id)
  end

  def digest_pending?
    deferred? && status_reason == Notifications::Reasons::DIGEST
  end
end

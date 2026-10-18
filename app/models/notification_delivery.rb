# Entrega de una notificación por un canal. Tabla particionada por mes:
# la PK física es (id, created_at), pero la app identifica por id.
class NotificationDelivery < ApplicationRecord
  self.primary_key = :id

  STATUSES = %w[pending sent delivered bounced dropped failed undeliverable].freeze
  # Estados que cuentan como "ya se le envió" (cooldown)
  SENT_STATUSES = %w[pending sent delivered].freeze

  enum :status, STATUSES.index_by(&:itself), validate: true

  # Datos personales cifrados (Active Record Encryption)
  encrypts :address
  encrypts :subject
  encrypts :body_text

  # Sin FK entre tablas particionadas: la integridad la asegura la central, no una consulta por entrega
  belongs_to :request, class_name: "NotificationRequest", optional: true, inverse_of: :deliveries
  validates :request_id, presence: true

  has_many :events, class_name: "NotificationEvent", foreign_key: :delivery_id, inverse_of: :delivery

  def recipient
    recipient_type.constantize.find_by(id: recipient_id)
  end
end

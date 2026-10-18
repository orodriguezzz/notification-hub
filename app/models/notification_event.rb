# Historia inmutable de cada envío: los eventos solo se insertan.
# La base de datos lo garantiza con un trigger (y, en producción, sin permisos UPDATE/DELETE).
class NotificationEvent < ApplicationRecord
  self.primary_key = :id

  TYPES = %w[
    enqueued sent delivered opened clicked bounced dropped spam_report unsubscribed
    fallback_triggered throttled throttled_shadow deferred digested expired failed
    skipped undeliverable recovered
  ].freeze

  # Sin FK entre tablas particionadas: la integridad la asegura la central, no una consulta por evento
  belongs_to :request, class_name: "NotificationRequest", optional: true, inverse_of: :events
  belongs_to :delivery, class_name: "NotificationDelivery", optional: true, inverse_of: :events

  validates :request_id, presence: true
  validates :event_type, inclusion: { in: TYPES }

  before_validation { self.occurred_at ||= Time.current }

  scope :chronological, -> { order(:occurred_at, :created_at) }

  def readonly?
    persisted? || super
  end

  # Inserta un evento. Acepta request/delivery como modelo o como id.
  def self.record!(type, request:, delivery: nil, payload: {}, occurred_at: Time.current, provider_event_id: nil)
    create!(
      event_type: type.to_s,
      request_id: request.is_a?(NotificationRequest) ? request.id : request,
      delivery_id: delivery.is_a?(NotificationDelivery) ? delivery.id : delivery,
      payload: payload,
      occurred_at: occurred_at,
      provider_event_id: provider_event_id
    )
  end
end

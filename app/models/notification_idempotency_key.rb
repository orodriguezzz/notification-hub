# Clave de idempotencia de un envío (ventana de 30 días). No particionada.
class NotificationIdempotencyKey < ApplicationRecord
  WINDOW = 30.days

  scope :expired, ->(now = Time.current) { where(expires_at: ...now) }
end

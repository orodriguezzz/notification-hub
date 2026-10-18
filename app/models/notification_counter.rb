# Contador anti-spam por destinatario, día local y categoría (ver Notifications::AntiSpam::Counter)
class NotificationCounter < ApplicationRecord
  scope :older_than, ->(date) { where(bucket_date: ...date) }
end

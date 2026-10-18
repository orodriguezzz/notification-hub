module Notifications
  # Tarea diaria de limpieza:
  #   - borra claves de idempotencia vencidas (ventana de 30 días),
  #   - borra contadores anti-spam de más de 7 días,
  #   - registra (sin borrar) las particiones de más de 90 días listas para archivar.
  # El archivado a S3 y el DETACH/DROP de particiones quedan fuera de alcance local.
  class PurgeJob < ApplicationJob
    queue_as :default

    COUNTER_RETENTION = 7.days
    PARTITION_RETENTION = 90.days

    def perform(now: Time.current)
      keys = NotificationIdempotencyKey.expired(now).delete_all
      counters = NotificationCounter.older_than((now - COUNTER_RETENTION).to_date).delete_all
      archivable = Notifications::Partitions.older_than((now - PARTITION_RETENTION).to_date)

      result = { idempotency_keys: keys, counters: counters, archivable_partitions: archivable }
      Rails.logger.info({ event: "purge.notifications" }.merge(result).to_json)
      result
    end
  end
end

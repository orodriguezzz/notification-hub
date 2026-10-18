module Notifications
  # Tarea diaria: crea las particiones del mes actual y los 2 siguientes (idempotente)
  class PartitionMaintenanceJob < ApplicationJob
    queue_as :default

    def perform
      created = Notifications::Partitions.ensure!(from: Date.current, months_ahead: 2)
      Rails.logger.info({ event: "partitions.notifications", created: created }.to_json) if created.any?
      created
    end
  end
end

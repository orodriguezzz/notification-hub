module Notifications
  # Helpers para migraciones de las tablas particionadas de la central
  module MigrationHelpers
    private

    # Crea particiones para el mes actual y los dos siguientes
    def create_monthly_partitions(table)
      Notifications::Partitions.ensure!(tables: table, months_ahead: 2, connection: connection)
    end
  end
end

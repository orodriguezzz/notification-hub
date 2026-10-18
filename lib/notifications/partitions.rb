module Notifications
  # Particiones mensuales (sobre created_at) de las tablas de alto volumen.
  # Lo usan las migraciones (MigrationHelpers) y PartitionMaintenanceJob.
  module Partitions
    TABLES = %w[notification_requests notification_deliveries notification_events].freeze

    module_function

    # Crea, si no existen, las particiones desde el mes de `from` y los `months_ahead` siguientes.
    # Es idempotente: CREATE TABLE IF NOT EXISTS.
    def ensure!(tables: TABLES, from: Date.current, months_ahead: 2, connection: ActiveRecord::Base.lease_connection)
      start = from.beginning_of_month
      created = []

      Array(tables).each do |table|
        (0..months_ahead).each do |offset|
          month = start >> offset
          name = partition_name(table, month)
          next if connection.table_exists?(name)

          connection.execute(<<~SQL)
            CREATE TABLE IF NOT EXISTS #{connection.quote_table_name(name)}
            PARTITION OF #{connection.quote_table_name(table)}
            FOR VALUES FROM (#{connection.quote(month.to_s)}) TO (#{connection.quote((month >> 1).to_s)});
          SQL
          created << name
        end
      end

      created
    end

    def partition_name(table, month)
      "#{table}_#{month.strftime('%Y_%m')}"
    end

    # Particiones cuyo rango terminó antes de `before` (candidatas a archivar)
    def older_than(before, tables: TABLES, connection: ActiveRecord::Base.lease_connection)
      Array(tables).flat_map do |table|
        children = connection.select_values(<<~SQL)
          SELECT child.relname
          FROM pg_inherits
          JOIN pg_class parent ON parent.oid = pg_inherits.inhparent
          JOIN pg_class child  ON child.oid  = pg_inherits.inhrelid
          WHERE parent.relname = #{connection.quote(table)}
          ORDER BY child.relname
        SQL

        children.filter_map do |child|
          match = child.match(/_(\d{4})_(\d{2})\z/)
          next unless match

          month_end = Date.new(match[1].to_i, match[2].to_i, 1) >> 1
          child if month_end <= before
        end
      end
    end
  end
end

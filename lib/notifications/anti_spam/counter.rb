module Notifications
  module AntiSpam
    # Presupuesto diario por destinatario y categoría. Contador atómico en PostgreSQL:
    # el UPSERT solo suma si no se alcanzó el límite; sin filas devueltas = límite alcanzado.
    module Counter
      LIMITED_SQL = <<~SQL.freeze
        INSERT INTO notification_counters (recipient_type, recipient_id, bucket_date, category, count, created_at, updated_at)
        VALUES (?, ?, ?, ?, 1, now(), now())
        ON CONFLICT (recipient_type, recipient_id, bucket_date, category)
        DO UPDATE SET count = notification_counters.count + 1, updated_at = now()
        WHERE notification_counters.count < ?
        RETURNING count
      SQL

      # Sin límite (críticas): se cuenta igual, para métricas
      UNLIMITED_SQL = <<~SQL.freeze
        INSERT INTO notification_counters (recipient_type, recipient_id, bucket_date, category, count, created_at, updated_at)
        VALUES (?, ?, ?, ?, 1, now(), now())
        ON CONFLICT (recipient_type, recipient_id, bucket_date, category)
        DO UPDATE SET count = notification_counters.count + 1, updated_at = now()
        RETURNING count
      SQL

      module_function

      # Devuelve el nuevo valor del contador, o nil si el límite ya se alcanzó
      def increment!(recipient_type:, recipient_id:, bucket_date:, category:, limit: nil)
        # Con límite 0 el primer INSERT del día pasaría igual (el WHERE solo aplica al UPDATE)
        return if limit && limit <= 0

        binds = [ recipient_type, recipient_id, bucket_date, category.to_s ]
        sql = if limit
          NotificationCounter.sanitize_sql_array([ LIMITED_SQL, *binds, limit ])
        else
          NotificationCounter.sanitize_sql_array([ UNLIMITED_SQL, *binds ])
        end

        NotificationCounter.connection_pool.with_connection { |connection| connection.select_value(sql) }
      end
    end
  end
end

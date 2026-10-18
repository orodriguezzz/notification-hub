# Eventos: historia inmutable (append-only), particionada por mes sobre created_at
class CreateNotificationEvents < ActiveRecord::Migration[8.1]
  include Notifications::MigrationHelpers

  def up
    create_table :notification_events, primary_key: [ :id, :created_at ],
                 options: "PARTITION BY RANGE (created_at)" do |t|
      t.uuid :id, null: false, default: -> { "uuidv7()" }
      t.uuid :request_id, null: false
      t.uuid :delivery_id
      t.string :event_type, null: false   # ver NotificationEvent::TYPES
      t.string :provider_event_id
      t.jsonb :payload, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.datetime :created_at, null: false
    end

    add_index :notification_events, :request_id
    add_index :notification_events, :delivery_id

    # Inmutabilidad: ninguna fila puede modificarse ni borrarse (DROP de particiones sí está permitido)
    execute <<~SQL
      CREATE FUNCTION notification_events_immutable() RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION 'notification_events es append-only';
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER notification_events_no_update_delete
      BEFORE UPDATE OR DELETE ON notification_events
      FOR EACH ROW EXECUTE FUNCTION notification_events_immutable();
    SQL

    create_monthly_partitions(:notification_events)
  end

  def down
    drop_table :notification_events
    execute "DROP FUNCTION IF EXISTS notification_events_immutable();"
  end
end

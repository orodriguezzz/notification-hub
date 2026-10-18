# Solicitudes (intención / outbox), particionadas por mes sobre created_at
class CreateNotificationRequests < ActiveRecord::Migration[8.1]
  include Notifications::MigrationHelpers

  def up
    create_table :notification_requests, primary_key: [ :id, :created_at ],
                 options: "PARTITION BY RANGE (created_at)" do |t|
      t.uuid :id, null: false, default: -> { "uuidv7()" }
      t.bigint :company_id, null: false
      t.string :notification_key, null: false
      t.integer :notification_version, null: false, default: 1
      t.string :category, null: false
      t.string :recipient_type, null: false
      t.bigint :recipient_id, null: false
      t.jsonb :params, null: false, default: {}
      t.jsonb :origin, null: false, default: {}
      t.string :idempotency_key, null: false
      t.string :status, null: false, default: "accepted"
      t.string :status_reason
      t.datetime :scheduled_at
      t.datetime :expires_at
      t.timestamps
    end

    add_index :notification_requests, [ :status, :scheduled_at ]
    add_index :notification_requests, [ :company_id, :recipient_type, :recipient_id, :created_at ],
              name: "idx_notification_requests_recipient"

    create_monthly_partitions(:notification_requests)
  end

  def down
    drop_table :notification_requests
  end
end

# Entregas por canal, particionadas por mes sobre created_at
class CreateNotificationDeliveries < ActiveRecord::Migration[8.1]
  include Notifications::MigrationHelpers

  def up
    create_table :notification_deliveries, primary_key: [ :id, :created_at ],
                 options: "PARTITION BY RANGE (created_at)" do |t|
      t.uuid :id, null: false, default: -> { "uuidv7()" }
      t.uuid :request_id, null: false
      t.bigint :company_id, null: false
      t.string :notification_key, null: false      # desnormalizado para el historial
      t.string :category, null: false
      t.string :recipient_type, null: false
      t.bigint :recipient_id, null: false
      t.string :channel, null: false
      t.text :address                               # cifrado (Active Record Encryption)
      t.string :provider
      t.string :provider_message_id
      t.text :subject                               # cifrado
      t.text :body_text                             # cifrado
      t.string :content_hash
      t.string :html_ref                            # puntero a S3 (fuera de alcance local)
      t.string :status, null: false, default: "pending"
      t.jsonb :decision_reason, null: false, default: {}
      t.integer :attempts, null: false, default: 0
      t.text :last_error
      t.datetime :sent_at
      t.timestamps
    end

    add_index :notification_deliveries, :request_id
    add_index :notification_deliveries, [ :company_id, :recipient_type, :recipient_id, :created_at ],
              name: "idx_notification_deliveries_recipient"
    add_index :notification_deliveries, [ :company_id, :notification_key, :created_at ],
              name: "idx_notification_deliveries_key"
    add_index :notification_deliveries, [ :recipient_type, :recipient_id, :notification_key, :created_at ],
              name: "idx_notification_deliveries_cooldown"

    create_monthly_partitions(:notification_deliveries)
  end

  def down
    drop_table :notification_deliveries
  end
end

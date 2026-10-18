# Claves de idempotencia: tabla no particionada para que el índice único no dependa de created_at
class CreateNotificationIdempotencyKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_idempotency_keys do |t|
      t.string :notification_key, null: false
      t.string :recipient_type, null: false
      t.bigint :recipient_id, null: false
      t.string :idempotency_key, null: false
      t.uuid :request_id, null: false
      t.datetime :expires_at, null: false   # ventana de 30 días
      t.timestamps
    end

    add_index :notification_idempotency_keys,
              [ :notification_key, :recipient_type, :recipient_id, :idempotency_key ],
              unique: true, name: "idx_notification_idempotency_unique"
    add_index :notification_idempotency_keys, :expires_at
  end
end

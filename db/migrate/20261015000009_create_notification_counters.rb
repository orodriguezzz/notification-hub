# Contadores anti-spam: presupuesto diario por destinatario, día local y categoría
class CreateNotificationCounters < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_counters do |t|
      t.string :recipient_type, null: false
      t.bigint :recipient_id, null: false
      t.date :bucket_date, null: false
      t.string :category, null: false
      t.integer :count, null: false, default: 0
      t.timestamps
    end

    add_index :notification_counters, [ :recipient_type, :recipient_id, :bucket_date, :category ],
              unique: true, name: "idx_notification_counters_unique"
    add_index :notification_counters, :bucket_date
  end
end

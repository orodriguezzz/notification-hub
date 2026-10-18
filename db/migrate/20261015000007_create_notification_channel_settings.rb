# Disponibilidad de canales (kill switch global y por empresa)
class CreateNotificationChannelSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_channel_settings do |t|
      t.bigint :company_id                 # nulo = configuración global
      t.string :channel, null: false
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end

    add_index :notification_channel_settings, [ :company_id, :channel ],
              unique: true, nulls_not_distinct: true, name: "idx_notification_channel_settings_unique"
    add_foreign_key :notification_channel_settings, :companies
  end
end

# El dominio de ejemplo (vacaciones, liquidaciones, documentos firmados) queda fuera del alcance:
# la app se limita a la central de notificaciones y al historial.
class DropDomainExampleTables < ActiveRecord::Migration[8.1]
  def change
    drop_table :leave_requests do |t|
      t.references :employee, null: false, foreign_key: true
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.string :status, null: false, default: "pending"
      t.timestamps
    end

    drop_table :payslips do |t|
      t.references :employee, null: false, foreign_key: true
      t.date :period, null: false
      t.datetime :published_at
      t.timestamps
      t.index [ :employee_id, :period ], unique: true
    end

    drop_table :signed_documents do |t|
      t.references :employee, null: false, foreign_key: true
      t.string :title, null: false
      t.datetime :signed_at, null: false
      t.timestamps
    end
  end
end

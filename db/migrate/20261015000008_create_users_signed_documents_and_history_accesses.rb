# Usuarios del cliente, documentos firmados y meta-auditoría del historial
class CreateUsersSignedDocumentsAndHistoryAccesses < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email, null: false
      t.string :role, null: false, default: "member"   # company_admin | member
      t.timestamps
    end
    add_index :users, :email, unique: true

    create_table :signed_documents do |t|
      t.references :employee, null: false, foreign_key: true
      t.string :title, null: false
      t.datetime :signed_at, null: false
      t.timestamps
    end

    # Registro de quién consultó el historial, con qué filtros y cuándo
    create_table :notification_history_accesses do |t|
      t.references :company, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.jsonb :filters, null: false, default: {}
      t.uuid :viewed_request_id
      t.datetime :created_at, null: false
    end
    add_index :notification_history_accesses, [ :company_id, :created_at ]
  end
end

class CreateDomainTables < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.string :name, null: false
      t.string :country, null: false, limit: 2
      t.string :time_zone, null: false, default: "America/Santiago"
      t.timestamps
    end

    create_table :employees do |t|
      t.references :company, null: false, foreign_key: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email
      t.string :phone
      t.string :time_zone
      t.date :birth_date
      t.jsonb :notification_opt_outs, null: false, default: []
      t.timestamps
    end
    add_index :employees, [ :company_id, :birth_date ]

    create_table :leave_requests do |t|
      t.references :employee, null: false, foreign_key: true
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.string :status, null: false, default: "pending"
      t.timestamps
    end

    create_table :payslips do |t|
      t.references :employee, null: false, foreign_key: true
      t.date :period, null: false
      t.datetime :published_at
      t.timestamps
    end
    add_index :payslips, [ :employee_id, :period ], unique: true
  end
end

class CreateServiceStatuses < ActiveRecord::Migration[7.1]
  def change
    create_table :service_statuses do |t|
      t.string :service_name, null: false
      t.string :status, null: false
      t.decimal :response_time, precision: 10, scale: 3
      t.text :error_message

      t.timestamps
    end

    add_index :service_statuses, :service_name
    add_index :service_statuses, :created_at
    add_index :service_statuses, [:service_name, :created_at]
  end
end

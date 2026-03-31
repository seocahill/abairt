class CreateEmails < ActiveRecord::Migration[7.1]
  def change
    create_table :emails do |t|
      t.string :subject
      t.text :message
      t.datetime :sent_at
      t.references :sent_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end

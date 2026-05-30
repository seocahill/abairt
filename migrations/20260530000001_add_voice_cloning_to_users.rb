class AddVoiceCloningToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :cloned_voice_id, :string
    add_column :users, :voice_clone_status, :integer, default: 0, null: false
    add_column :users, :voice_clone_provider, :string
    add_column :users, :voice_cloned_at, :datetime
    add_column :users, :voice_clone_error, :text

    add_index :users, :cloned_voice_id, unique: true, where: "cloned_voice_id IS NOT NULL"
    add_index :users, :voice_clone_status
  end
end

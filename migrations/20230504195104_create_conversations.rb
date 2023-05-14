class CreateConversations < ActiveRecord::Migration[6.1]
  def change
    create_table :conversations do |t|
      t.belongs_to :user, null: false, foreign_key: true
      t.belongs_to :voice_recording, null: false, foreign_key: true

      t.timestamps
    end
  end
end

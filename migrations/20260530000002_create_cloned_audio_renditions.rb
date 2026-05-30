class CreateClonedAudioRenditions < ActiveRecord::Migration[8.1]
  def change
    create_table :cloned_audio_renditions do |t|
      t.references :voice_user, null: false, foreign_key: { to_table: :users }
      t.references :source, polymorphic: true, null: false
      t.integer :status, default: 0, null: false
      t.text :error_message

      t.timestamps
    end

    add_index :cloned_audio_renditions,
      [:voice_user_id, :source_type, :source_id],
      unique: true,
      name: "idx_cloned_audio_renditions_unique"
  end
end

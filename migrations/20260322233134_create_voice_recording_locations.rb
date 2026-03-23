class CreateVoiceRecordingLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :voice_recording_locations do |t|
      t.references :voice_recording, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.string :confidence, default: "medium"
      t.string :source
      t.text :context

      t.timestamps
    end

    add_index :voice_recording_locations,
      [:voice_recording_id, :location_id],
      unique: true,
      name: "idx_vr_locations_unique"
  end
end

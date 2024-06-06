class AddDurationSecondsToVoiceRecordings < ActiveRecord::Migration[7.0]
  def change
    add_column :voice_recordings, :duration_seconds, :float, null: false, default: 0.0
  end
end

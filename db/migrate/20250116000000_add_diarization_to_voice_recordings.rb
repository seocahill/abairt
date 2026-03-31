class AddDiarizationToVoiceRecordings < ActiveRecord::Migration[7.0]
  def change
    add_column :voice_recordings, :diarization_data, :jsonb
    add_column :voice_recordings, :diarization_status, :string
    add_index :voice_recordings, :diarization_status
  end
end

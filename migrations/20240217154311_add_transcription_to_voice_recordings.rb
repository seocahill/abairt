class AddTranscriptionToVoiceRecordings < ActiveRecord::Migration[7.0]
  def change
    add_column :voice_recordings, :transcription, :text
  end
end

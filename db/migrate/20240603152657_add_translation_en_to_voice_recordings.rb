class AddTranslationEnToVoiceRecordings < ActiveRecord::Migration[7.0]
  def change
    add_column :voice_recordings, :transcription_en, :text
  end
end

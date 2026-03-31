class AddVoiceRecordingToDictionaryEntry < ActiveRecord::Migration[6.1]
  def change
    add_reference :dictionary_entries, :voice_recording, foreign_key: false
  end
end

class AddTranslationEnToVoiceRecordings < ActiveRecord::Migration[7.0]
  def change
    add_column :voice_recordings, :translation_en, :text
  end
end

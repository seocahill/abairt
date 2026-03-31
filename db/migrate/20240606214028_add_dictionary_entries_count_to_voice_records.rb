class AddDictionaryEntriesCountToVoiceRecords < ActiveRecord::Migration[7.0]
  def change
    add_column :voice_recordings, :dictionary_entries_count, :integer, null: false, default: 0
  end
end

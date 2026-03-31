class AddImportStatusToVoiceRecordings < ActiveRecord::Migration[7.1]
  def change
    add_column :voice_recordings, :import_status, :string
  end
end

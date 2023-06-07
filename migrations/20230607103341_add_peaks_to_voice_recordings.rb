class AddPeaksToVoiceRecordings < ActiveRecord::Migration[6.1]
  def change
    add_column :voice_recordings, :peaks, :json
  end
end

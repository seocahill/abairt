class AddUserNotNullToVoiceRecording < ActiveRecord::Migration[7.0]
  def change
    change_column_null :voice_recordings, :user_id, false
  end
end

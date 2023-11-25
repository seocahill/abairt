class AddUserToVoiceRecording < ActiveRecord::Migration[7.0]
  def change
    add_reference :voice_recordings, :user, foreign_key: true
  end
end

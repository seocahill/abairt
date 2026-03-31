class AddUserDataToVoiceRecording < ActiveRecord::Migration[7.0]
  def up
    ActiveRecord::Base.connection.execute("UPDATE voice_recordings SET user_id = 1")
  end

  def down
    # noop - Data migration, not reversing to avoid data inconsistency.
  end
end

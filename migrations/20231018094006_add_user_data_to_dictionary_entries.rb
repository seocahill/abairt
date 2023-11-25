class AddUserDataToDictionaryEntries < ActiveRecord::Migration[7.0]
  def up
    # darren
    ActiveRecord::Base.connection.execute("UPDATE dictionary_entries SET user_id = 2 WHERE speaker_id = 2")
    # seo
    ActiveRecord::Base.connection.execute("UPDATE dictionary_entries SET user_id = 1 WHERE speaker_id != 2 OR speaker_id IS NULL")
  end

  def down
    # noop - Data migration, not reversing to avoid data inconsistency.
  end
end

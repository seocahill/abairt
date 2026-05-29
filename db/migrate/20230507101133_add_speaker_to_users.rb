class AddSpeakerToUsers < ActiveRecord::Migration[6.1]
  def change
    add_reference :dictionary_entries, :speaker, foreign_key: false
  end
end

# Word lists, the Practice list and the learner's own recordings against it are
# retired: learning lives in the Mayo Irish course now. Irreversible as to
# data — `down` restores the tables empty.
class DropWordLists < ActiveRecord::Migration[8.1]
  def up
    # Practice recordings hang off the join rows. Detach them so the blobs are
    # left unattached, to be purged the usual way, rather than pointing at a
    # model that no longer exists.
    execute "DELETE FROM active_storage_attachments WHERE record_type = 'WordListDictionaryEntry'"

    drop_table :user_lists
    drop_table :word_list_dictionary_entries
    drop_table :word_lists
  end

  def down
    create_table :word_lists do |t|
      t.string :name
      t.string :description
      t.boolean :starred
      t.text :script
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end

    create_table :word_list_dictionary_entries do |t|
      t.references :dictionary_entry, null: false, foreign_key: true
      t.references :word_list, null: false, foreign_key: true
      t.timestamps
    end

    create_table :user_lists do |t|
      t.references :user, null: false, foreign_key: true
      t.references :word_list, null: false, foreign_key: true
      t.timestamps
    end
  end
end

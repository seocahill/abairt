# Word lists are retired: learning lives in the Mayo Irish course now. Each
# list is kept as a tag of the same name on the entries it held, then the
# tables are dropped.
#
# Nothing here destroys an entry or its media. Dropping the join table only
# removes the rows that said "this entry is on that list"; the entries are
# untouched (and the code no longer has `dependent: :destroy` to cascade from
# them). Practice recordings are left exactly as they are: their attachment
# rows still point at the old join table, so the blobs stay attached and are
# never purged as unattached.
#
# `down` restores the tables empty; the lists themselves live on as tags.
class DropWordLists < ActiveRecord::Migration[8.1]
  # The app's own models are gone, so read the old tables through these.
  class WordList < ActiveRecord::Base
    self.table_name = "word_lists"
  end

  class WordListEntry < ActiveRecord::Base
    self.table_name = "word_list_dictionary_entries"
  end

  # Created for every signed-in user on their first visit to the dictionary,
  # to hold their own pronunciation practice. Not a list anyone curated, so it
  # does not become a tag.
  AUTO_LIST_NAME = "Practice"

  def up
    convert_lists_to_tags

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

  private

  # Lists with the same name (two speakers' "Food") share one tag. Rows are
  # inserted directly so no entry callbacks (versions, embeddings) fire.
  def convert_lists_to_tags
    WordList.where.not(name: [nil, "", AUTO_LIST_NAME]).find_each do |list|
      tag = ActsAsTaggableOn::Tag.find_or_create_with_like_by_name(list.name.strip)
      entry_ids = WordListEntry.where(word_list_id: list.id).distinct.pluck(:dictionary_entry_id)
      tag_entries(tag, entry_ids)
    end
  end

  def tag_entries(tag, entry_ids)
    already_tagged = ActsAsTaggableOn::Tagging
      .where(tag_id: tag.id, taggable_type: "DictionaryEntry", context: "tags", taggable_id: entry_ids)
      .pluck(:taggable_id)

    now = Time.current
    rows = (entry_ids - already_tagged).map do |entry_id|
      {tag_id: tag.id, taggable_type: "DictionaryEntry", taggable_id: entry_id, context: "tags", created_at: now}
    end
    ActsAsTaggableOn::Tagging.insert_all(rows) if rows.any?

    tag.update_columns(taggings_count: ActsAsTaggableOn::Tagging.where(tag_id: tag.id).count)
  end
end

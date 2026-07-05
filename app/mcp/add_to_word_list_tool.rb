# frozen_string_literal: true

# Add or remove entries on an existing word list you own.
class AddToWordListTool < ApplicationTool
  tool_name "add_to_word_list"
  description "Add and/or remove dictionary entries on a word list you own. Pass `add` and/or " \
              "`remove` as lists of entry ids."
  input_schema(
    properties: {
      word_list_id: {type: "integer", description: "The word list id"},
      add: {type: "array", items: {type: "integer"}, description: "Entry ids to add"},
      remove: {type: "array", items: {type: "integer"}, description: "Entry ids to remove"}
    },
    required: ["word_list_id"]
  )

  def self.call(word_list_id:, server_context:, add: [], remove: [])
    guard do
      list = WordList.find(word_list_id)
      authorize!(current_user(server_context), list, :update?)

      return error("Provide at least one entry id to add or remove.") if Array(add).empty? && Array(remove).empty?

      list.dictionary_entries << DictionaryEntry.where(id: Array(add) - list.dictionary_entry_ids) if add.present?
      list.dictionary_entries.destroy(DictionaryEntry.where(id: Array(remove))) if remove.present?

      ok(id: list.id, name: list.name, entries_count: list.dictionary_entries.reload.size)
    end
  end
end

# frozen_string_literal: true

# Create a new word list owned by the acting admin, optionally seeded with entries.
class CreateWordListTool < ApplicationTool
  tool_name "create_word_list"
  description "Create a new word list (curated collection) owned by the current user, optionally " \
              "seeded with dictionary entry ids."
  input_schema(
    properties: {
      name: {type: "string", description: "Name of the word list"},
      description: {type: "string", description: "Optional description"},
      entry_ids: {type: "array", items: {type: "integer"}, description: "Entry ids to add (optional)"}
    },
    required: ["name"]
  )

  def self.call(name:, server_context:, description: nil, entry_ids: [])
    guard do
      user = current_user(server_context)
      list = WordList.new(name: name, description: description, user: user)
      list.dictionary_entries = DictionaryEntry.where(id: Array(entry_ids)) if entry_ids.present?
      list.save!

      ok(id: list.id, name: list.name, description: list.description,
        owner: user.name, entries_count: list.dictionary_entries.size)
    end
  end
end

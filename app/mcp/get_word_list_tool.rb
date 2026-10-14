# frozen_string_literal: true

# Fetch a word list with its entries in full.
class GetWordListTool < ApplicationTool
  tool_name "get_word_list"
  description "Fetch a word list by id with its entries."
  input_schema(
    properties: {id: {type: "integer", description: "The word list id"}},
    required: ["id"]
  )

  def self.call(id:, server_context:)
    guard do
      list = WordList.includes(dictionary_entries: [:speaker, :translator, :tags, :voice_recording, {media_attachment: :blob}]).find(id)
      entries = Mcp::EntrySerializer.new(list.dictionary_entries, params: {host: host(server_context)}).serializable_hash

      ok(
        id: list.id, name: list.name, description: list.description,
        starred: list.starred, owner: list.user&.name,
        count: entries.size, entries: entries
      )
    end
  end
end

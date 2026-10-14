# frozen_string_literal: true

# Browse word lists (curated study/collection sets) with their owner and size.
class ListWordListsTool < ApplicationTool
  tool_name "list_word_lists"
  description "List word lists (curated collections of entries) with owner and entry count."
  input_schema(
    properties: {limit: {type: "integer", description: "Max results (default 30, max 100)"}},
    required: []
  )

  def self.call(server_context:, limit: 30)
    guard do
      lists = WordList.includes(:user)
        .left_joins(:word_list_dictionary_entries)
        .group(:id)
        .order("word_lists.updated_at DESC")
        .limit(limit.to_i.clamp(1, 100))

      data = lists.map do |list|
        {id: list.id, name: list.name, description: list.description,
         starred: list.starred, owner: list.user&.name,
         entries_count: list.word_list_dictionary_entries.size}
      end
      ok(count: data.size, word_lists: data)
    end
  end
end

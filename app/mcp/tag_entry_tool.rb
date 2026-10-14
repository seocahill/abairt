# frozen_string_literal: true

# Add and/or remove tags on an entry - the assistant's way of grouping entries by topic, register
# or any editorial theme discovered during research.
class TagEntryTool < ApplicationTool
  tool_name "tag_entry"
  description "Add and/or remove tags on a dictionary entry. Pass `add` and/or `remove` as lists " \
              "of tag names."
  input_schema(
    properties: {
      id: {type: "integer", description: "The dictionary entry id"},
      add: {type: "array", items: {type: "string"}, description: "Tag names to add"},
      remove: {type: "array", items: {type: "string"}, description: "Tag names to remove"}
    },
    required: ["id"]
  )

  def self.call(id:, server_context:, add: [], remove: [])
    guard do
      entry = DictionaryEntry.find(id)
      authorize!(current_user(server_context), entry, :update?)

      return error("Provide at least one tag to add or remove.") if Array(add).empty? && Array(remove).empty?

      entry.tag_list.add(Array(add)) if add.present?
      entry.tag_list.remove(Array(remove)) if remove.present?
      entry.save!

      ok(id: entry.id, tags: entry.tag_list)
    end
  end
end

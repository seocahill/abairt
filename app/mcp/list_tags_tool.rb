# frozen_string_literal: true

# The tag vocabulary, most-used first - lets the assistant discover topical groupings to search
# within or apply.
class ListTagsTool < ApplicationTool
  tool_name "list_tags"
  description "List tags used across the corpus with their usage counts, most used first."
  input_schema(
    properties: {
      query: {type: "string", description: "Optional substring to filter tag names"},
      limit: {type: "integer", description: "Max results (default 50, max 200)"}
    },
    required: []
  )

  def self.call(server_context:, query: nil, limit: 50)
    guard do
      tags = ActsAsTaggableOn::Tag.order(taggings_count: :desc).limit(limit.to_i.clamp(1, 200))
      tags = tags.where("name LIKE ?", "%#{query}%") if query.present?

      ok(count: tags.size, tags: tags.map { |t| {id: t.id, name: t.name, count: t.taggings_count} })
    end
  end
end

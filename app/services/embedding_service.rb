# frozen_string_literal: true

# Generates and stores OpenAI text embeddings for dictionary entries,
# persisting them to the sqlite-vec virtual table.
#
# Usage:
#   EmbeddingService.generate("text to embed")           # => Array of 1536 floats
#   EmbeddingService.new.store(dictionary_entry)         # embed + persist
#   EmbeddingService.new.search(query_text, limit: 10)   # KNN lookup
class EmbeddingService
  EMBEDDING_MODEL = "text-embedding-3-small"
  DIMENSIONS = 1536
  TABLE = "vec_dictionary_entry_embeddings"

  def self.generate(text)
    new.generate(text)
  end

  def initialize
    @client = OpenAI::Client.new(
      access_token: Rails.application.credentials.dig(:openai, :openai_key),
      organization_id: Rails.application.credentials.dig(:openai, :openai_org)
    )
  end

  def generate(text)
    response = @client.embeddings(parameters: { model: EMBEDDING_MODEL, input: text.truncate(8000) })
    response.dig("data", 0, "embedding")
  end

  def store(entry)
    text = entry.translation
    vector = generate(text)

    db = ActiveRecord::Base.connection.raw_connection
    db.execute("DELETE FROM #{TABLE} WHERE dictionary_entry_id = ?", [entry.id])
    db.execute(
      "INSERT INTO #{TABLE}(dictionary_entry_id, embedding) VALUES (?, ?)",
      [entry.id, vector.pack("f*")]
    )
    true
  end

  # Returns DictionaryEntry records ordered by vector similarity to query_text.
  # Only returns entries that have been embedded (inner join via WHERE IN).
  def search(query_text, limit: 20)
    vector = generate(query_text)
    return DictionaryEntry.none unless vector

    db = ActiveRecord::Base.connection.raw_connection
    rows = db.execute(<<~SQL, [vector.pack("f*"), limit])
      SELECT dictionary_entry_id, distance
      FROM #{TABLE}
      WHERE embedding MATCH ?
      ORDER BY distance
      LIMIT ?
    SQL

    ids_in_order = rows.map { |r| r["dictionary_entry_id"] || r[0] }
    return DictionaryEntry.none if ids_in_order.empty?

    # Preserve distance order
    entries_by_id = DictionaryEntry.where(id: ids_in_order).index_by(&:id)
    ids_in_order.filter_map { |id| entries_by_id[id] }
  rescue => e
    Rails.logger.error("EmbeddingService#search failed: #{e.message}")
    DictionaryEntry.none
  end
end

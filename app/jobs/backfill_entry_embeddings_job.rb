# frozen_string_literal: true

# Queues EmbedDictionaryEntryJob for all confirmed mayo dialect entries
# that don't yet have a vector embedding.
#
# Run once after deploying the migration:
#   BackfillEntryEmbeddingsJob.perform_later
#   # or from console: BackfillEntryEmbeddingsJob.new.perform
class BackfillEntryEmbeddingsJob < ApplicationJob
  queue_as :default

  def perform
    already_embedded_ids = ActiveRecord::Base.connection
      .execute("SELECT dictionary_entry_id FROM vec_dictionary_entry_embeddings")
      .map { |r| r["dictionary_entry_id"] || r[0] }

    DictionaryEntry
      .confirmed_accuracy
      .mayo_dialect
      .has_recording
      .where.not(id: already_embedded_ids)
      .find_each { |entry| EmbedDictionaryEntryJob.perform_later(entry.id) }
  end
end

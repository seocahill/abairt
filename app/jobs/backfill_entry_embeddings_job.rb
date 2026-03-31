# frozen_string_literal: true

# Queues EmbedDictionaryEntryJob for all confirmed mayo dialect entries
# that don't yet have a vector embedding. Resumable via ActiveJob::Continuable.
#
#   BackfillEntryEmbeddingsJob.perform_later
class BackfillEntryEmbeddingsJob < ApplicationJob
  include ActiveJob::Continuable

  queue_as :default

  def perform
    service = EmbeddingService.new

    step(:embed_entries) do |step|
      entries_to_embed.find_each(start: step.cursor) do |entry|
        service.store(entry)
        step.advance! from: entry.id
      end
    end
  end

  private

  def entries_to_embed
    already_embedded_ids = VectorsRecord.connection
      .execute("SELECT dictionary_entry_id FROM vec_dictionary_entry_embeddings")
      .map { |r| r["dictionary_entry_id"] || r[0] }

    DictionaryEntry
      .has_recording
      .has_translation
      .where.not(id: already_embedded_ids)
  end
end

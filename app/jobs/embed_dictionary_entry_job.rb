# frozen_string_literal: true

# Generates and stores a vector embedding for a single confirmed dictionary entry.
# Enqueued after an entry is confirmed, or via BackfillEntryEmbeddingsJob.
class EmbedDictionaryEntryJob < ApplicationJob
  queue_as :default

  def perform(entry_id)
    entry = DictionaryEntry.find_by(id: entry_id)
    return unless entry&.confirmed?

    EmbeddingService.new.store(entry)
  end
end

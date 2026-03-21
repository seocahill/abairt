# frozen_string_literal: true

# Generates and stores a vector embedding for a single confirmed dictionary entry.
# Enqueued after an entry is confirmed.
class EmbedDictionaryEntryJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(entry_id)
    entry = DictionaryEntry.find_by(id: entry_id)
    return unless entry&.confirmed?

    EmbeddingService.new.store(entry)
  end
end

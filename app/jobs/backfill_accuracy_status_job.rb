# frozen_string_literal: true

class BackfillAccuracyStatusJob < ApplicationJob
  include ActiveJob::Continuable

  queue_as :default

  def perform
    # Process records in batches, saving cursor to resume from last processed ID
    step :backfill_accuracy_status do |step|
      DictionaryEntry
        .where(quality: [2, 3])
        .where(accuracy_status: 0) # Only process unconfirmed entries
        .order(:id)
        .find_each(start: step.cursor) do |entry|
          entry.update_column(:accuracy_status, 1)
          step.advance! from: entry.id
        end
    end
  end
end


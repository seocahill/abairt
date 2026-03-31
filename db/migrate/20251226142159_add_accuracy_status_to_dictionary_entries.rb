class AddAccuracyStatusToDictionaryEntries < ActiveRecord::Migration[8.1]
  def up
    add_column :dictionary_entries, :accuracy_status, :integer, default: 0, null: false
    
    # Backfill: Mark entries with quality 'good' or 'excellent' as confirmed (1)
    # quality enum: low=0, fair=1, good=2, excellent=3
    # Enqueue job with ActiveJob::Continuable for resumable backfill
    begin
      BackfillAccuracyStatusJob.perform_later
    rescue => e
      Rails.logger.error "Error backfilling accuracy status: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  def down
    remove_column :dictionary_entries, :accuracy_status
  end
end

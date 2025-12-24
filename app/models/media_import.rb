class MediaImport < ApplicationRecord
  enum :status, { pending: 0, imported: 1, skipped: 2, failed: 100}

  validates :url, presence: true, uniqueness: true
  validates :title, presence: true
  validates :status, presence: true

  scope :pending, -> { where(status: :pending) }
  scope :imported, -> { where(status: :imported) }
  scope :skipped, -> { where(status: :skipped) }

  def mark_as_imported!
    update!(status: :imported, imported_at: Time.current, error_message: nil)
  end

  def mark_as_skipped!(reason = nil)
    update!(status: :skipped, error_message: reason)
  end

  def mark_as_failed!(error)
    update!(status: :failed, error_message: error)
  end

  # Queue this MediaImport for processing
  def queue_for_processing!
    ProcessMediaImportJob.perform_later(id)
  end

  # Process this MediaImport immediately (synchronous)
  def process_now!
    ProcessMediaImportJob.perform_now(id)
  end

  # Queue all pending MediaImport items for processing
  def self.queue_all_pending!
    pending.find_each do |media_import|
      media_import.queue_for_processing!
    end
  end

  # Process a batch of pending items
  def self.process_batch(limit = 10)
    pending.limit(limit).find_each do |media_import|
      media_import.process_now!
    end
  end
end

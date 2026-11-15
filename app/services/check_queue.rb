# frozen_string_literal: true

# The unchecked lines of a recording, in the order they are heard.
#
# Plain Ruby so it can be tried from the console:
#   CheckQueue.new(VoiceRecording.find(207)).current
class CheckQueue
  def initialize(recording)
    @recording = recording
  end

  # The line asked for if it is still unchecked, otherwise the first one left.
  def current(entry_id = nil)
    queue.find_by(id: entry_id) || queue.first
  end

  # The next unchecked line after this one, wrapping round to the start.
  def following(entry)
    queue.where("region_start > :start OR (region_start = :start AND id > :id)", start: entry.region_start, id: entry.id).first || queue.where.not(id: entry.id).first
  end

  # The unchecked line before this one, wrapping round to the end.
  def preceding(entry)
    before = queue.where("region_start < :start OR (region_start = :start AND id < :id)", start: entry.region_start, id: entry.id)
    before.last || queue.where.not(id: entry.id).last
  end

  def remaining
    @remaining ||= queue.count
  end

  def total
    @total ||= @recording.dictionary_entries.count
  end

  private

  def queue
    @recording.dictionary_entries.unconfirmed_accuracy.includes(:speaker, media_attachment: :blob).reorder(:region_start, :id)
  end
end

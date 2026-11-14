# Turns a shared moment (`?t=83.4`, `?t=1:23`, `?t=1m23s`) into seconds, and
# works out which page of a recording's lines holds that moment.
#
#   MomentLink.parse("1:23")                  # => 83.0
#   MomentLink.new(recording, 83.0).page(15)  # => 2
class MomentLink
  CLOCK = /\A(?:(\d+):)?(\d{1,2}):(\d{1,2}(?:\.\d+)?)\z/
  UNITS = /\A(?:(\d+)h)?(?:(\d+)m)?(?:(\d+(?:\.\d+)?)s?)?\z/

  def self.parse(value)
    text = value.to_s.strip.delete_prefix("t=")
    seconds = from_clock(text) || from_units(text) || from_number(text)
    seconds if seconds&.finite? && seconds >= 0
  end

  def self.from_clock(text)
    return unless (m = CLOCK.match(text))
    (m[1].to_i * 3600) + (m[2].to_i * 60) + m[3].to_f
  end

  def self.from_units(text)
    return unless text.match?(/[hms]/) && (m = UNITS.match(text))
    (m[1].to_i * 3600) + (m[2].to_i * 60) + m[3].to_f
  end

  def self.from_number(text)
    Float(text, exception: false)
  end

  def initialize(recording, seconds)
    @recording = recording
    @seconds = seconds
  end

  attr_reader :seconds

  # The line being spoken at `seconds`: the latest one to have started.
  def entry
    @entry ||= lines.where("region_start <= ?", seconds).reorder(region_start: :desc).first
  end

  # 1-based page of `per_page` lines that contains the moment.
  def page(per_page)
    return 1 unless entry
    # Lines without a start time sort first on the page, so they count too.
    before = @recording.dictionary_entries.where("region_start IS NULL OR region_start < ?", entry.region_start)
    (before.count / per_page) + 1
  end

  private

  def lines
    @recording.dictionary_entries.where.not(region_start: nil)
  end
end

# frozen_string_literal: true

module Transcription
  # The usable segments of a run's raw transcript (#133), with the words in
  # each. The transcript only says when a segment starts and ends, so each
  # word gets an even share of its segment's time: good enough to find a line
  # in the audio, not to the word.
  #
  # A segment that can't be used (no text, no or backwards times, not a hash)
  # is left out.
  #
  #   Transcription::Heard.new(run.segments).segments
  class Heard
    Segment = Data.define(:index, :id, :start, :finish, :speaker, :words)
    Word = Data.define(:text, :key, :segment, :start, :finish)

    def initialize(raw_segments)
      @raw = Array(raw_segments)
    end

    # In the order they are heard.
    def segments
      @segments ||= @raw.filter_map { |raw| parse(raw) }
        .sort_by { |parsed| [parsed[:start], parsed[:finish]] }
        .each_with_index.map { |parsed, index| build(parsed, index) }
    end

    private

    def parse(raw)
      return unless raw.is_a?(Hash)

      start = Float(raw["startTimeSeconds"], exception: false)
      finish = Float(raw["endTimeSeconds"], exception: false)
      text = raw["text"].to_s.strip
      return if start.nil? || finish.nil? || start.negative? || finish <= start || text.empty?

      {id: raw["id"]&.to_s, start:, finish:, speaker: raw["speaker"], text:}
    end

    def build(parsed, index)
      texts = Text.words(parsed[:text])
      share = (parsed[:finish] - parsed[:start]) / texts.size
      words = texts.each_with_index.map do |text, position|
        start = parsed[:start] + share * position
        finish = (position == texts.size - 1) ? parsed[:finish] : parsed[:start] + share * (position + 1)
        Word.new(text:, key: Text.key(text), segment: index, start:, finish:)
      end
      Segment.new(index:, id: parsed[:id], start: parsed[:start], finish: parsed[:finish], speaker: parsed[:speaker], words:)
    end
  end
end

# frozen_string_literal: true

module Transcription
  # Sorts a recording's entries and a run's segments into stretches that can
  # be compared with each other on their own (#133).
  #
  # - An entry with times and the segments that share time with it belong
  #   together. Stretches that touch join up, so a line that was cut
  #   differently (split, merged, or someone talking over it) still ends up
  #   in one stretch with all its counterparts.
  # - Entries with no times at all (text typed in or copied from elsewhere)
  #   can't be placed by time. They are compared as one stretch, in the order
  #   they were added, with every segment no timed entry claimed.
  # - Segments no entry claimed, when there are no untimed entries either,
  #   form a stretch with no entries: all of it is new.
  # - Entries with a half-set or backwards time are left out; so is any entry
  #   with no text.
  #
  # A segment and an entry share time when they overlap by more than a fifth
  # of the shorter of the two, so a tiny overlap at a boundary doesn't join
  # neighbours, and a short interjection inside a long turn still does.
  class Grouping
    SHARED = 0.2

    Group = Data.define(:entries, :segments, :timed)

    def initialize(entries, segments)
      @entries = entries.select { |entry| entry.word_or_phrase.present? }
      @segments = segments
    end

    def groups
      @groups ||= timed_groups + [leftover_group].compact
    end

    private

    def timed
      @timed ||= @entries.select { |entry| span?(entry) }.sort_by { |entry| [entry.region_start, entry.id] }
    end

    def untimed
      @untimed ||= @entries.select { |entry| entry.region_start.nil? && entry.region_end.nil? }.sort_by(&:id)
    end

    def span?(entry)
      entry.region_start.present? && entry.region_end.present? && entry.region_end > entry.region_start
    end

    def timed_groups
      @timed_groups ||= components.map do |entries, segments|
        Group.new(entries: entries.sort_by { |entry| [entry.region_start, entry.id] }, segments: segments.sort_by(&:index), timed: true)
      end
    end

    def leftover_group
      segments = @segments - timed_groups.flat_map(&:segments)
      Group.new(entries: untimed, segments:, timed: false) if untimed.any? || segments.any?
    end

    # [[entries, segments], ...] of timed entries and the segments that touch
    # them, joined through anything either has in common.
    def components
      seen = Set.new
      timed.filter_map do |entry|
        next if seen.include?(entry)

        entries, segments = reach(entry, seen)
        [entries, segments]
      end
    end

    def reach(start, seen)
      entries = []
      segments = Set.new
      queue = [start]
      until queue.empty?
        entry = queue.shift
        next unless seen.add?(entry)

        entries << entry
        touching = @segments.select { |segment| share_time?(entry, segment) }
        segments.merge(touching)
        queue.concat(touching.flat_map { |segment| timed.select { |other| share_time?(other, segment) } })
      end
      [entries, segments.to_a]
    end

    def share_time?(entry, segment)
      common = [entry.region_end.to_f, segment.finish].min - [entry.region_start.to_f, segment.start].max
      shorter = [entry.region_end.to_f - entry.region_start.to_f, segment.finish - segment.start].min
      common > shorter * SHARED
    end
  end
end

# frozen_string_literal: true

module TrainingData
  # Read-only count of how far each speaker is from the training-data targets.
  # Console use:
  #
  #   TrainingData::Progress.call
  #   # => {targets: {...}, speakers: [{speaker_id:, name:, total_hours:, ...}], needs_work: [...]}
  #
  # "Checked" means the same as the ASR evaluation set: confirmed by a human,
  # with audio, a transcription, and a non-temporary speaker
  # (DictionaryEntry.asr_eval_candidates). Never changes content.
  class Progress
    SECONDS_PER_HOUR = 3600.0
    NEEDS_WORK_LIMIT = 10

    def self.call(targets: Rails.application.config_for(:training_targets))
      new(targets).call
    end

    def initialize(targets)
      @targets = targets.to_h.symbolize_keys
    end

    def call
      {targets: @targets, speakers: speakers, needs_work: needs_work}
    end

    private

    def speakers
      names = User.where(id: totals.keys).pluck(:id, :name).to_h
      totals.map { |id, row| speaker_row(id, names[id], row) }.sort_by { |row| -row[:checked_hours] }
    end

    def speaker_row(id, name, row)
      checked = checked_seconds.fetch(id, [0, 0])
      {
        speaker_id: id,
        name: name.presence || "Speaker ##{id}",
        total_hours: hours(row[1]),
        checked_hours: hours(checked[1]),
        lines_total: row[0],
        lines_checked: checked[0],
        lines_to_check: row[0] - checked[0],
        tts_progress_percent: percent(checked[1], @targets[:tts_hours_per_speaker]),
        asr_progress_percent: percent(checked[1], @targets[:asr_hours_per_speaker])
      }
    end

    # {speaker_id => [line count, seconds]} for every line with a speaker.
    def totals
      @totals ||= aggregate(counted_lines)
    end

    def checked_seconds
      @checked_seconds ||= aggregate(DictionaryEntry.asr_eval_candidates)
    end

    # Same population as the checked lines: real (non-temporary) speakers, with
    # a transcription and a time range.
    def counted_lines
      DictionaryEntry.joins(:speaker).where.not(users: {role: :temporary})
        .where.not(word_or_phrase: [nil, ""]).where.not(region_start: nil).where.not(region_end: nil)
    end

    def aggregate(scope)
      scope.group(:speaker_id)
        .pluck(:speaker_id, Arel.sql("COUNT(*)"), Arel.sql("COALESCE(SUM(dictionary_entries.region_end - dictionary_entries.region_start), 0)"))
        .to_h { |id, count, seconds| [id, [count, seconds.to_f]] }
    end

    # The (speaker, recording) pairs with the most lines still to check.
    def needs_work
      counted_lines.where.not(voice_recording_id: nil).unconfirmed_accuracy
        .group(:speaker_id, :voice_recording_id).order(Arel.sql("COUNT(*) DESC")).limit(NEEDS_WORK_LIMIT).count
        .map { |(speaker_id, recording_id), lines| {speaker_id:, voice_recording_id: recording_id, lines_to_check: lines} }
    end

    def hours(seconds) = (seconds / SECONDS_PER_HOUR).round(2)

    def percent(seconds, target_hours)
      return 0 if target_hours.to_f.zero?

      [(seconds / SECONDS_PER_HOUR / target_hours * 100).round, 100].min
    end
  end
end

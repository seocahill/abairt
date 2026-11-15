# frozen_string_literal: true

# Scores one provider against an AsrEvalSet and stores the result as an
# AsrEvalRun. Console use:
#
#   AsrEvaluation.new(AsrEvalSet.last, provider: "fotheidil").call
#   AsrEvaluation.new(set, provider: "abair", transcriber: ->(entry) { ... }).call
#
# Without a transcriber it scores the newest stored hypothesis per entry. With
# one, each entry is re-transcribed first and the output stored as a hypothesis
# (the transcriber takes an entry and returns text or nil).
class AsrEvaluation
  def initialize(eval_set, provider:, transcriber: nil)
    @eval_set = eval_set
    @provider = provider
    @transcriber = transcriber
  end

  def call
    pairs = entries.filter_map { |entry| score(entry) }

    @eval_set.asr_eval_runs.create!(
      provider: @provider,
      entries_scored: pairs.size,
      results: {
        "overall" => summarise(pairs.map(&:last)),
        "by_speaker" => group(pairs) { |entry| entry.speaker&.name.presence || "Speaker ##{entry.speaker_id}" },
        "by_dialect" => group(pairs) { |entry| entry.speaker&.dialect || "unknown" },
        "entries_in_set" => @eval_set.asr_eval_set_entries.count
      }
    )
  end

  private

  def entries
    @eval_set.dictionary_entries.includes(:speaker, :asr_hypotheses)
  end

  def score(entry)
    text = @transcriber ? transcribe(entry) : latest_hypothesis(entry)
    return if text.blank? || entry.word_or_phrase.blank?

    [entry, Asr::ErrorRate.call(entry.word_or_phrase, text)]
  end

  def transcribe(entry)
    text = @transcriber.call(entry)
    AsrHypothesis.record(entry, provider: @provider, text: text)
    text
  end

  def latest_hypothesis(entry)
    entry.asr_hypotheses.select { |h| h.provider == @provider }.max_by(&:created_at)&.text
  end

  def group(pairs)
    pairs.group_by { |entry, _| yield entry }.transform_values { |rows| summarise(rows.map(&:last)) }
  end

  def summarise(results)
    words = results.sum(&:word_total)
    chars = results.sum(&:char_total)
    {
      "segments" => results.size,
      "wer" => words.zero? ? nil : (results.sum(&:word_errors).fdiv(words) * 100).round(1),
      "cer" => chars.zero? ? nil : (results.sum(&:char_errors).fdiv(chars) * 100).round(1)
    }
  end
end

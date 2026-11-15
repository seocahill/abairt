require "test_helper"

class AsrEvaluationTest < ActiveSupport::TestCase
  setup do
    @entry = dictionary_entries(:two)
    @set = AsrEvalSet.create!(name: "t", version: 1, frozen_at: Time.current)
    @set.asr_eval_set_entries.create!(dictionary_entry: @entry)
  end

  test "scores stored hypotheses per provider by speaker and dialect" do
    AsrHypothesis.create!(dictionary_entry: @entry, provider: "fotheidil", text: @entry.word_or_phrase)
    AsrHypothesis.create!(dictionary_entry: @entry, provider: "abair", text: "rud eile")

    perfect = AsrEvaluation.new(@set, provider: "fotheidil").call
    assert_equal 0.0, perfect.results.dig("overall", "wer")
    assert_equal 1, perfect.entries_scored
    assert_includes perfect.results["by_speaker"].keys, @entry.speaker.name

    bad = AsrEvaluation.new(@set, provider: "abair").call
    assert_operator bad.results.dig("overall", "wer"), :>, 0
    assert_equal @entry.speaker.dialect || "unknown", bad.results["by_dialect"].keys.first
  end

  test "skips entries with no hypothesis" do
    run = AsrEvaluation.new(@set, provider: "fotheidil").call
    assert_equal 0, run.entries_scored
    assert_nil run.results.dig("overall", "wer")
  end

  test "a transcriber re-transcribes and stores the hypothesis" do
    run = AsrEvaluation.new(@set, provider: "abair", transcriber: ->(_entry) { "cén chaoi" }).call
    assert_equal 1, run.entries_scored
    assert_equal "cén chaoi", @entry.asr_hypotheses.last.text
  end
end

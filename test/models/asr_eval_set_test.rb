require "test_helper"

class AsrEvalSetTest < ActiveSupport::TestCase
  test "freeze_from stores membership and bumps the version" do
    scope = DictionaryEntry.where(id: dictionary_entries(:two).id)
    first = AsrEvalSet.freeze_from(name: "mayo", scope: scope)
    second = AsrEvalSet.freeze_from(name: "mayo", scope: scope)

    assert_equal [1, 2], [first.version, second.version]
    assert_equal [dictionary_entries(:two)], first.dictionary_entries.to_a
  end

  test "candidates are confirmed entries with audio and text" do
    assert_not_includes DictionaryEntry.asr_eval_candidates, dictionary_entries(:one)
  end

  test "AsrHypothesis.record ignores blank text" do
    assert_no_difference "AsrHypothesis.count" do
      AsrHypothesis.record(dictionary_entries(:one), provider: "abair", text: "")
    end
    assert_difference "AsrHypothesis.count", 1 do
      AsrHypothesis.record(dictionary_entries(:one), provider: "abair", text: "x")
    end
  end

  test "an entry in a frozen set cannot be deleted" do
    entry = dictionary_entries(:two)
    AsrEvalSet.freeze_from(name: "mayo", scope: DictionaryEntry.where(id: entry.id))
    assert_not entry.destroy
    assert DictionaryEntry.exists?(entry.id)
  end

  test "temporary speakers are not candidates" do
    entry = dictionary_entries(:two)
    entry.speaker.update_columns(role: User.roles[:temporary])
    assert_not_includes DictionaryEntry.asr_eval_candidates, entry
  end

  test "freeze_from with an empty scope makes an empty set" do
    assert_equal 0, AsrEvalSet.freeze_from(name: "x", scope: DictionaryEntry.none).dictionary_entries.count
  end
end

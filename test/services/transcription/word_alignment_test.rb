require "test_helper"

class Transcription::WordAlignmentTest < ActiveSupport::TestCase
  def pairs(left, right)
    Transcription::WordAlignment.new(left, right).pairs.map { [it.left, it.right, it.exact?] }
  end

  test "equal words are paired exactly" do
    assert_equal [[0, 0, true], [1, 1, true]], pairs(%w[a b], %w[a b])
  end

  test "a changed word is paired, not exactly" do
    assert_equal [[0, 0, true], [1, 1, false], [2, 2, true]], pairs(%w[a b c], %w[a x c])
  end

  test "extra words on either side are left unpaired" do
    assert_equal [[0, 0, true], [1, 2, true]], pairs(%w[a c], %w[a b c])
    assert_equal [[0, 0, true], [2, 1, true]], pairs(%w[a b c], %w[a c])
  end

  test "nothing in common is paired word for word, so a caller has to judge it" do
    assert_equal [[0, 0, false], [1, 1, false]], pairs(%w[a b], %w[x y])
  end

  test "an empty side pairs nothing" do
    assert_empty pairs([], %w[a])
    assert_empty pairs(%w[a], [])
  end

  test "pairs run in order on both sides" do
    result = pairs(%w[a b c d e], %w[a x c y e z])
    assert_equal result.map(&:first).sort, result.map(&:first)
    assert_equal result.map(&:second).sort, result.map(&:second)
  end

  test "lists that are far too long are refused" do
    long = Array.new(Transcription::WordAlignment::MAX_WORDS + 1, "a")
    assert_raises(Transcription::WordAlignment::TooLong) { Transcription::WordAlignment.new(long, %w[a]) }
  end
end

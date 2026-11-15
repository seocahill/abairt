require "test_helper"

class Asr::ErrorRateTest < ActiveSupport::TestCase
  test "identical text has no errors" do
    r = Asr::ErrorRate.call("a b c", "a b c")
    assert_equal [0, 3, 0], [r.word_errors, r.word_total, r.char_errors]
  end

  test "counts substitutions, insertions and deletions" do
    assert_equal 1, Asr::ErrorRate.call("a b c", "a x c").word_errors
    assert_equal 1, Asr::ErrorRate.call("a b c", "a b c d").word_errors
    assert_equal 2, Asr::ErrorRate.call("a b c", "a").word_errors
  end

  test "ignores case and punctuation but keeps fadas and mutations" do
    assert_equal 0, Asr::ErrorRate.call("Tá sé go maith!", "tá sé go maith").word_errors
    assert_equal 1, Asr::ErrorRate.call("tá sé", "ta sé").word_errors
    assert_equal 1, Asr::ErrorRate.call("an bhó", "an bó").word_errors
  end

  test "normalises decomposed and composed accents the same" do
    assert_equal 0, Asr::ErrorRate.call("tá", "tá").word_errors
  end

  test "empty hypothesis is all deletions" do
    assert_equal 2, Asr::ErrorRate.call("a b", "").word_errors
  end
end

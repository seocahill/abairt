require "test_helper"

class Transcription::TextTest < ActiveSupport::TestCase
  Text = Transcription::Text

  test "words keeps the words as written, in order" do
    assert_equal ["Tá", "an", "lá", "go", "deas,", "a", "Sheáin."], Text.words("  Tá an lá  go deas,\na Sheáin. ")
  end

  test "a mark standing alone stays with the word before it" do
    assert_equal ["bhí –", "sé", "ann"], Text.words("bhí – sé ann")
    assert_equal ["…"], Text.words("…")
  end

  test "an accent is the same however it is encoded" do
    assert_equal Text.words("café"), Text.words("café")
  end

  test "a key ignores case and punctuation but not a fada" do
    assert_equal Text.key("Deas,"), Text.key("deas")
    assert_equal Text.key("d’fhág"), Text.key("d'fhág")
    refute_equal Text.key("sean"), Text.key("seán")
  end

  test "same? ignores only whitespace and encoding" do
    assert Text.same?("a  b", " a b ")
    refute Text.same?("a b", "A b")
    refute Text.same?("a b", "a b.")
  end

  test "a cosmetic difference is one of case or punctuation only" do
    assert Text.cosmetic_difference?("tá sé go maith", "Tá sé go maith.")
    refute Text.cosmetic_difference?("tá sé go maith", "tá sé go maith")
    refute Text.cosmetic_difference?("tá sé go maith", "tá sé go dona")
    refute Text.cosmetic_difference?("tá sé", "tá sé go maith")
  end
end

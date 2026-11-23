require "test_helper"

class TranscriptionRunsHelperTest < ActionView::TestCase
  test "marks the words that go and the words that come in" do
    current, fresh = word_diff("one two three", "one too three four")

    assert_equal 'one <del class="bg-red-100 text-red-800 rounded-sm px-0.5">two</del> three', current
    assert_equal 'one <ins class="bg-green-100 text-green-800 rounded-sm px-0.5 no-underline">too</ins> three ' \
      '<ins class="bg-green-100 text-green-800 rounded-sm px-0.5 no-underline">four</ins>', fresh
  end

  test "escapes the text" do
    current, fresh = word_diff("<b>x</b>", "<b>x</b> y")

    assert_includes current, "&lt;b&gt;x&lt;/b&gt;"
    assert_not_includes fresh, "<b>"
  end

  test "summarises what is waiting" do
    run = TranscriptionRun.new
    run.stubs(:pending_counts).returns({"differs" => 1})
    assert_equal "1 line differs, 0 new", pending_candidates_summary(run)
    run.stubs(:pending_counts).returns({"differs" => 2, "new_segment" => 1})
    assert_equal "2 lines differ, 1 new", pending_candidates_summary(run)
  end

  test "says how many lines need times" do
    run = TranscriptionRun.new
    run.stubs(:pending_counts).returns({"differs" => 1, "new_segment" => 2, "timing" => 3})
    assert_equal "1 line differs, 2 new, 3 need times", pending_candidates_summary(run)
    run.stubs(:pending_counts).returns({"timing" => 1})
    assert_equal "0 lines differ, 0 new, 1 needs times", pending_candidates_summary(run)
  end
end

require "test_helper"

# Flag f170_search_to_moment: search hits open recordings at the matching line.
class SearchToMomentTest < ActionDispatch::IntegrationTest
  setup do
    @recording = voice_recordings(:one)
    speaker = users(:one)
    @kettle = DictionaryEntry.create!(voice_recording: @recording, speaker: speaker, owner: speaker,
      word_or_phrase: "kettle boiling", region_start: 42.0, region_end: 50.0)
    @other = DictionaryEntry.create!(voice_recording: @recording, speaker: speaker, owner: speaker,
      word_or_phrase: "window open", region_start: 60.0, region_end: 70.0)
    ActiveRecord::Base.connection.execute <<-SQL
      INSERT INTO fts_dictionary_entries(rowid, translation, word_or_phrase)
      SELECT id, translation, word_or_phrase FROM dictionary_entries;
    SQL
    ApplicationController.any_instance.stubs(:current_user).returns(users(:one))
  end

  test "flag off: dictionary result links to the recording without a time" do
    Flipper.disable(:f170_search_to_moment)
    get dictionary_entries_url(search: "kettle", show_all: "1")
    assert_response :success
    assert_select "a[href='#{voice_recording_path(@recording)}']"
    assert_select "a[href*='t=']", false
  end

  test "flag on: dictionary result links to the matching moment" do
    Flipper.enable(:f170_search_to_moment)
    get dictionary_entries_url(search: "kettle", show_all: "1")
    assert_response :success
    assert_select "a[href='#{voice_recording_path(@recording, t: 42.0)}']"
  end

  test "flag off: q is ignored on the recording page" do
    Flipper.disable(:f170_search_to_moment)
    get voice_recording_url(@recording, q: "kettle")
    assert_response :success
    assert_select "input[name='q']", false
    assert_select "#dictionary_entry_#{@other.id}"
  end

  test "flag on: recording page filters lines by q" do
    Flipper.enable(:f170_search_to_moment)
    get voice_recording_url(@recording, q: "kettle")
    assert_response :success
    assert_select "input[name='q'][value='kettle']"
    assert_select "#dictionary_entry_#{@kettle.id}"
    assert_select "#dictionary_entry_#{@other.id}", false
  end

  test "flag on: punctuation in q does not raise" do
    Flipper.enable(:f170_search_to_moment)
    ["kettle?", "sean-bhean", '"x', "?!"].each do |typed|
      get voice_recording_url(@recording, q: typed)
      assert_response :success
    end
  end

  test "flag on: a shared t opens the player at the moment" do
    Flipper.enable(:f170_search_to_moment)
    get voice_recording_url(@recording, t: 42)
    assert_select "[data-waveform-start-at-value='42.0']"
  end

  test "flag on: recordings search lists matching lines with moment links" do
    Flipper.enable(:f170_search_to_moment)
    get voice_recordings_url(search: "kettle", view: "list")
    assert_response :success
    assert_select "a[href='#{voice_recording_path(@recording, t: 42.0)}']", text: /kettle boiling/
    assert_select "a[href='#{voice_recording_path(@recording, t: 60.0)}']", false
  end

  test "flag off: recordings search does not search inside lines" do
    Flipper.disable(:f170_search_to_moment)
    get voice_recordings_url(search: "kettle", view: "list")
    assert_response :success
    assert_select "a[href*='t=']", false
  end

  test "flag on: recordings search with punctuation does not raise" do
    Flipper.enable(:f170_search_to_moment)
    get voice_recordings_url(search: "kettle?", view: "list")
    assert_response :success
  end

  test "flag on: links use the exact start so a line starting at 42.449 resolves to itself" do
    Flipper.enable(:f170_search_to_moment)
    speaker = users(:one)
    precise = DictionaryEntry.create!(voice_recording: @recording, speaker: speaker, owner: speaker,
      word_or_phrase: "teapot ready", region_start: 42.449, region_end: 43.0)
    DictionaryEntry.connection.execute("INSERT INTO fts_dictionary_entries(rowid, translation, word_or_phrase) VALUES (#{precise.id}, '', 'teapot ready')")
    get voice_recordings_url(search: "teapot", view: "list")
    assert_select "a[href='#{voice_recording_path(@recording, t: 42.449)}']"
    assert_equal precise, MomentLink.new(@recording, 42.449).entry
  end

  test "flag on: only three lines are listed per recording" do
    Flipper.enable(:f170_search_to_moment)
    speaker = users(:one)
    5.times do |i|
      e = DictionaryEntry.create!(voice_recording: @recording, speaker: speaker, owner: speaker,
        word_or_phrase: "spoon #{i}", region_start: 100 + i, region_end: 101 + i)
      DictionaryEntry.connection.execute("INSERT INTO fts_dictionary_entries(rowid, translation, word_or_phrase) VALUES (#{e.id}, '', 'spoon #{i}')")
    end
    get voice_recordings_url(search: "spoon", view: "list")
    assert_select "ul li a[href*='t=']", 3
  end

  test "flag on: an entry without a start time links to the plain recording" do
    Flipper.enable(:f170_search_to_moment)
    @kettle.update_columns(region_start: nil)
    get dictionary_entries_url(search: "kettle", show_all: "1")
    assert_select "a[href='#{voice_recording_path(@recording)}']"
  end
end

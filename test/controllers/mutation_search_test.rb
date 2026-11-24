require "test_helper"

# Flag f171_mutation_search: search finds mutated Irish spellings and half-typed words.
class MutationSearchTest < ActionDispatch::IntegrationTest
  setup do
    @recording = voice_recordings(:one)
    speaker = users(:one)
    line = ->(irish, start) {
      DictionaryEntry.create!(voice_recording: @recording, speaker: speaker, owner: speaker,
        word_or_phrase: irish, translation: "line at #{start}", region_start: start, region_end: start + 5)
    }
    @lenited = line.call("Mo bhean!", 10.0)
    @eclipsed = line.call("ár mbean", 20.0)
    @plain = line.call("bean", 30.0)
    @prefixed = line.call("ár nUisce", 40.0)
    @other = line.call("fear", 50.0)
    ActiveRecord::Base.connection.execute("INSERT INTO fts_dictionary_entries(fts_dictionary_entries) VALUES('rebuild')")
    ApplicationController.any_instance.stubs(:current_user).returns(users(:one))
  end

  test "flag off: the dictionary finds only the spelling typed" do
    Flipper.disable(:f171_mutation_search)
    get dictionary_entries_url(search: "bean", show_all: "1")
    assert_response :success
    assert_select "#dictionary_entry_#{@plain.id}"
    assert_select "#dictionary_entry_#{@lenited.id}", false
    assert_select "#dictionary_entry_#{@eclipsed.id}", false
  end

  test "flag off: a half-typed word finds nothing" do
    Flipper.disable(:f171_mutation_search)
    get dictionary_entries_url(search: "bhea", show_all: "1")
    assert_select "#dictionary_entry_#{@lenited.id}", false
  end

  test "flag on: the plain word finds its lenited and eclipsed forms" do
    Flipper.enable(:f171_mutation_search)
    get dictionary_entries_url(search: "bean", show_all: "1")
    assert_response :success
    [@plain, @lenited, @eclipsed].each { |entry| assert_select "#dictionary_entry_#{entry.id}" }
    assert_select "#dictionary_entry_#{@other.id}", false
  end

  test "flag on: a mutated word finds the plain word" do
    Flipper.enable(:f171_mutation_search)
    get dictionary_entries_url(search: "mbean", show_all: "1")
    [@plain, @lenited, @eclipsed].each { |entry| assert_select "#dictionary_entry_#{entry.id}" }
  end

  test "flag on: a word starting with a vowel finds it with a joined prefix" do
    Flipper.enable(:f171_mutation_search)
    get dictionary_entries_url(search: "uisce", show_all: "1")
    assert_select "#dictionary_entry_#{@prefixed.id}"
  end

  test "flag on: a half-typed last word finds the whole word" do
    Flipper.enable(:f171_mutation_search)
    get dictionary_entries_url(search: "bhea", show_all: "1")
    assert_select "#dictionary_entry_#{@lenited.id}"
    assert_select "#dictionary_entry_#{@other.id}", false
  end

  test "flag on: English is still searched" do
    Flipper.enable(:f171_mutation_search)
    get dictionary_entries_url(search: "line at 50", show_all: "1")
    assert_select "#dictionary_entry_#{@other.id}"
  end

  test "flag on: punctuation and operator words do not raise" do
    Flipper.enable(:f171_mutation_search)
    ["bean.", "a bhean?", "sean-bhean", '"bhean', "AND NOT", "?!", "*", "b"].each do |typed|
      get dictionary_entries_url(search: typed, show_all: "1")
      assert_response :success, typed
    end
  end

  test "flag on: searching inside a recording finds mutated lines" do
    Flipper.enable(:f170_search_to_moment)
    Flipper.enable(:f171_mutation_search)
    get voice_recording_url(@recording, q: "bean")
    assert_response :success
    [@plain, @lenited, @eclipsed].each { |entry| assert_select "#dictionary_entry_#{entry.id}" }
    assert_select "#dictionary_entry_#{@other.id}", false
  end

  test "flag off: searching inside a recording matches the spelling typed" do
    Flipper.enable(:f170_search_to_moment)
    Flipper.disable(:f171_mutation_search)
    get voice_recording_url(@recording, q: "bean")
    assert_select "#dictionary_entry_#{@plain.id}"
    assert_select "#dictionary_entry_#{@lenited.id}", false
  end

  test "flag on: the recordings search lists the mutated matching lines" do
    Flipper.enable(:f170_search_to_moment)
    Flipper.enable(:f171_mutation_search)
    get voice_recordings_url(search: "bean", view: "list")
    assert_response :success
    assert_select "a[href='#{voice_recording_path(@recording, t: 10.0)}']"
    assert_select "a[href='#{voice_recording_path(@recording, t: 20.0)}']"
  end

  test "flag off: the recordings search lists only the exact spelling" do
    Flipper.enable(:f170_search_to_moment)
    Flipper.disable(:f171_mutation_search)
    get voice_recordings_url(search: "bean", view: "list")
    assert_select "a[href='#{voice_recording_path(@recording, t: 30.0)}']"
    assert_select "a[href='#{voice_recording_path(@recording, t: 10.0)}']", false
  end

  test "flag on: a short word only finds itself, not every word sharing its vowel" do
    Flipper.enable(:f171_mutation_search)
    speaker = users(:one)
    short = DictionaryEntry.create!(voice_recording: @recording, speaker: speaker, owner: speaker,
      word_or_phrase: "tá sé", region_start: 60.0, region_end: 61.0)
    ActiveRecord::Base.connection.execute("INSERT INTO fts_dictionary_entries(fts_dictionary_entries) VALUES('rebuild')")

    get dictionary_entries_url(search: "tá", show_all: "1")
    assert_select "#dictionary_entry_#{short.id}"
    assert_select "#dictionary_entry_#{@prefixed.id}", false
    assert_select "#dictionary_entry_#{@eclipsed.id}", false
  end

  test "flag on: the recordings search matches a half-typed word" do
    Flipper.enable(:f170_search_to_moment)
    Flipper.enable(:f171_mutation_search)
    get voice_recordings_url(search: "bhea", view: "list")
    assert_select "a[href='#{voice_recording_path(@recording, t: 10.0)}']"
  end

  test "f171 on without f170: the recordings search does not look inside lines" do
    Flipper.disable(:f170_search_to_moment)
    Flipper.enable(:f171_mutation_search)
    get voice_recordings_url(search: "bean", view: "list")
    assert_response :success
    assert_select "a[href*='t=']", false
  end
end

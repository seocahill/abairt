# frozen_string_literal: true

require "test_helper"

module Api
  class VoiceRecordingsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      @user.regenerate_api_token
      @recording = voice_recordings(:one)
      @recording.media.attach(io: StringIO.new("fake audio"), filename: "story.mp3", content_type: "audio/mpeg")
    end

    def auth = {"Authorization" => "Bearer #{@user.api_token}"}

    def line(text, start, confirmed: true, speaker: users(:one))
      @recording.dictionary_entries.create!(word_or_phrase: text, translation: "#{text} in English", speaker: speaker, owner: users(:one),
        region_start: start, region_end: start + 2, accuracy_status: confirmed ? 1 : 0)
    end

    test "requires a token" do
      get api_voice_recording_path(@recording)

      assert_response :unauthorized
    end

    test "returns the recording's audio and its confirmed lines in order, with times" do
      later = line("second line", 12.5)
      earlier = line("first line", 3.2)
      line("not checked yet", 7.0, confirmed: false)

      get api_voice_recording_path(@recording), headers: auth

      assert_response :success
      json = JSON.parse(response.body)
      assert_equal @recording.title, json["title"]
      assert_match %r{/rails/active_storage/blobs/}, json["audio_url"]
      assert_equal [earlier.id, later.id], json["lines"].pluck("id")
      assert_equal({"irish" => "first line", "translation" => "first line in English", "start" => 3.2, "end" => 5.2},
        json["lines"].first.slice("irish", "translation", "start", "end"))
      assert_equal users(:one).name, json["lines"].first.dig("speaker", "name")
    end

    test "leaves out placeholder speakers" do
      line("who said this", 1.0, speaker: users(:temporary))

      get api_voice_recording_path(@recording), headers: auth

      assert_nil JSON.parse(response.body)["lines"].sole["speaker"]
    end

    test "a recording with nothing to play isn't found" do
      @recording.media.purge

      get api_voice_recording_path(@recording), headers: auth

      assert_response :not_found
    end

    test "an unknown recording isn't found" do
      get api_voice_recording_path(id: 0), headers: auth

      assert_response :not_found
    end

    test "leaves out segments that have no words yet" do
      spoken = line("a line", 1.0, confirmed: false)
      line("placeholder", 4.0, confirmed: false).update_column(:word_or_phrase, nil)
      line("placeholder", 7.0, confirmed: false).update_column(:word_or_phrase, "")

      get api_voice_recording_path(@recording, unchecked: true), headers: auth
      assert_equal [spoken.id], JSON.parse(response.body)["lines"].pluck("id")
    end

    test "leaves out lines nobody has checked unless asked for them" do
      checked = line("checked line", 1.0)
      unchecked = line("machine line", 4.0, confirmed: false)

      get api_voice_recording_path(@recording), headers: auth
      assert_equal [checked.id], JSON.parse(response.body)["lines"].pluck("id")

      get api_voice_recording_path(@recording, unchecked: true), headers: auth
      lines = JSON.parse(response.body)["lines"]
      assert_equal [checked.id, unchecked.id], lines.pluck("id")
      assert_equal [true, false], lines.pluck("checked")
    end

    test "lists recordings that have audio and a transcript, newest first, without the transcript" do
      line("a line", 1.0, confirmed: false)
      silent = VoiceRecording.create!(title: "Silent", owner: users(:one))
      silent.dictionary_entries.create!(word_or_phrase: "no audio", translation: "no audio", speaker: users(:one), owner: users(:one), region_start: 1, region_end: 2)

      get api_voice_recordings_path, headers: auth

      assert_response :success
      recordings = JSON.parse(response.body)["recordings"]
      assert_equal [@recording.id], recordings.pluck("id")
      assert_match %r{/rails/active_storage/blobs/}, recordings.first["audio_url"]
      assert_equal 1, recordings.first["lines_count"]
      assert_not_includes recordings.first.keys, "lines"
    end

    test "a shuffled list skips recordings already heard and respects the limit" do
      other = VoiceRecording.create!(title: "Another", owner: users(:one))
      other.media.attach(io: StringIO.new("more audio"), filename: "other.mp3", content_type: "audio/mpeg")
      other.dictionary_entries.create!(word_or_phrase: "another line", translation: "another", speaker: users(:one), owner: users(:one), region_start: 1, region_end: 2)
      line("a line", 1.0, confirmed: false)

      get api_voice_recordings_path(shuffle: true, exclude_ids: [@recording.id]), headers: auth
      assert_equal [other.id], JSON.parse(response.body)["recordings"].pluck("id")

      get api_voice_recordings_path(shuffle: true, limit: 1), headers: auth
      assert_equal 1, JSON.parse(response.body)["recordings"].size
    end

    test "listing requires a token" do
      get api_voice_recordings_path

      assert_response :unauthorized
    end
  end
end

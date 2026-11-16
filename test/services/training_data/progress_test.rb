require "test_helper"

module TrainingData
  class ProgressTest < ActiveSupport::TestCase
    setup do
      @speaker = users(:two)
      @recording = voice_recordings(:one)
      DictionaryEntry.where(speaker: @speaker).delete_all
    end

    test "counts total and checked hours per speaker against targets" do
      entry(0, 1800, :confirmed)
      entry(1800, 5400, :unconfirmed)

      row = TrainingData::Progress.call(targets: {tts_hours_per_speaker: 2, asr_hours_per_speaker: 1})[:speakers].find { |r| r[:speaker_id] == @speaker.id }

      assert_equal 1.5, row[:total_hours]
      assert_equal 0.5, row[:checked_hours]
      assert_equal 1, row[:lines_to_check]
      assert_equal 25, row[:tts_progress_percent]
      assert_equal 50, row[:asr_progress_percent]
    end

    test "caps progress at 100 and lists recordings needing work" do
      entry(0, 7200, :confirmed)
      entry(0, 10, :unconfirmed)

      result = TrainingData::Progress.call(targets: {tts_hours_per_speaker: 1, asr_hours_per_speaker: 1})

      assert_equal 100, result[:speakers].find { |r| r[:speaker_id] == @speaker.id }[:tts_progress_percent]
      assert_includes result[:needs_work].pluck(:voice_recording_id), @recording.id
    end

    test "default targets come from config and temporary speakers are excluded" do
      entry(0, 3600, :confirmed)
      temp = users(:one)
      temp.update_columns(role: User.roles[:temporary])
      DictionaryEntry.new(speaker: temp, user_id: temp.id, voice_recording: @recording, word_or_phrase: "y", region_start: 0, region_end: 60).save!(validate: false)

      result = TrainingData::Progress.call

      assert_operator result[:targets][:tts_hours_per_speaker], :>, 0
      assert_not_includes result[:speakers].pluck(:speaker_id), temp.id
      assert_equal 10, result[:speakers].find { |r| r[:speaker_id] == @speaker.id }[:tts_progress_percent]
    end

    test "a speaker with no checked lines shows zero" do
      entry(0, 60, :unconfirmed)

      row = TrainingData::Progress.call[:speakers].find { |r| r[:speaker_id] == @speaker.id }

      assert_equal 0, row[:checked_hours]
      assert_equal 0, row[:tts_progress_percent]
    end

    private

    def entry(start, finish, status)
      e = DictionaryEntry.new(speaker: @speaker, user_id: @speaker.id, voice_recording: @recording, word_or_phrase: "x", region_start: start, region_end: finish, accuracy_status: status)
      e.media.attach(io: StringIO.new("a"), filename: "a.mp3", content_type: "audio/mpeg")
      e.save!(validate: false)
    end
  end
end

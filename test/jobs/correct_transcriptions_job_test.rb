# frozen_string_literal: true

require "test_helper"

class CorrectTranscriptionsJobTest < ActiveJob::TestCase
  setup do
    @voice_recording = voice_recordings(:one)
    @voice_recording.update!(
      transcription: "Tá mé ag dul go dtí an siopa.",
      transcription_en: "I am going to the shop."
    )

    # Create some dictionary entries
    @entry1 = DictionaryEntry.create!(
      voice_recording: @voice_recording,
      word_or_phrase: "Tá mé ag dul",
      translation: "I am going",
      region_start: 0.0,
      region_end: 2.0,
      speaker: users(:one),
      owner: users(:one)
    )

    @entry2 = DictionaryEntry.create!(
      voice_recording: @voice_recording,
      word_or_phrase: "go dtí an siopa",
      translation: "to the shop",
      region_start: 2.0,
      region_end: 4.0,
      speaker: users(:one),
      owner: users(:one)
    )
  end

  test "performs correction when voice recording exists" do
    mock_openai_response = {
      "choices" => [{
        "message" => {
          "content" => {
            "corrections" => [
              {
                "id" => @entry1.id,
                "corrected_text" => "Tá mé ag dul",
                "corrected_translation" => "I am going",
                "confidence" => "high"
              },
              {
                "id" => @entry2.id,
                "corrected_text" => "chun a tsiop",
                "corrected_translation" => "to the shop",
                "confidence" => "high"
              }
            ]
          }.to_json
        }
      }]
    }

    OpenAI::Client.any_instance.stubs(:chat).returns(mock_openai_response)

    assert_no_changes -> { @entry1.reload.word_or_phrase } do
      assert_changes -> { @entry2.reload.word_or_phrase }, from: "go dtí an siopa", to: "chun a tsiop" do
        CorrectTranscriptionsJob.perform_now(@voice_recording.id)
      end
    end
  end

  test "does nothing when voice recording doesn't exist" do
    assert_no_changes -> { @entry1.reload.word_or_phrase } do
      CorrectTranscriptionsJob.perform_now(-1)
    end
  end

  test "handles service errors gracefully" do
    OpenAI::Client.any_instance.stubs(:chat).raises(StandardError.new("API Error"))
    
    assert_no_changes -> { @entry1.reload.word_or_phrase } do
      CorrectTranscriptionsJob.perform_now(@voice_recording.id)
    end
  end
end 
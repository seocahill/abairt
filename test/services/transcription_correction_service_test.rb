# frozen_string_literal: true

require "test_helper"

class TranscriptionCorrectionServiceTest < ActiveSupport::TestCase
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

    @service = TranscriptionCorrectionService.new(@voice_recording)
  end

  test "returns false if no transcription present" do
    @voice_recording.update!(transcription: nil)
    assert_not @service.correct_transcriptions
  end

  test "returns false if no dictionary entries" do
    @voice_recording.dictionary_entries.destroy_all
    assert_not @service.correct_transcriptions
  end

  test "corrects transcriptions when differences found" do
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
                "corrected_text" => "go dtí an siopa",
                "corrected_translation" => "to the shop",
                "confidence" => "high"
              }
            ]
          }.to_json
        }
      }]
    }

    OpenAI::Client.any_instance.stubs(:chat).returns(mock_openai_response)

    assert @service.correct_transcriptions
    @entry1.reload
    @entry2.reload

    assert_equal "Tá mé ag dul", @entry1.word_or_phrase
    assert_equal "I am going", @entry1.translation
    assert_equal "go dtí an siopa", @entry2.word_or_phrase
    assert_equal "to the shop", @entry2.translation
  end

  test "handles OpenAI API errors gracefully" do
    OpenAI::Client.any_instance.stubs(:chat).raises(StandardError.new("API Error"))
    
    assert_not @service.correct_transcriptions
  end

  test "handles JSON parsing errors gracefully" do
    mock_openai_response = {
      "choices" => [{
        "message" => {
          "content" => "invalid json"
        }
      }]
    }

    OpenAI::Client.any_instance.stubs(:chat).returns(mock_openai_response)
    
    assert_not @service.correct_transcriptions
  end
end 
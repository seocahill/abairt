# frozen_string_literal: true

require "test_helper"

module VoiceCloning
  class VoiceChangerServiceTest < ActiveSupport::TestCase
    def setup
      @sample = Rails.root.join("test/fixtures/files/sample.mp3").to_s
      @client = mock("ElevenLabs::Client")
    end

    test "delegates to the ElevenLabs client and returns bytes" do
      @client.expects(:speech_to_speech)
        .with(voice_id: "voice_abc", source_path: @sample)
        .returns("mp3-bytes")

      service = VoiceChangerService.new(voice_id: "voice_abc", client: @client)
      assert_equal "mp3-bytes", service.call(source_path: @sample)
    end

    test "raises when source file is missing" do
      service = VoiceChangerService.new(voice_id: "voice_abc", client: @client)

      assert_raises(VoiceChangerService::Error) do
        service.call(source_path: "/nonexistent/path.mp3")
      end
    end
  end
end

# frozen_string_literal: true

require "test_helper"

module ElevenLabs
  class ClientTest < ActiveSupport::TestCase
    def setup
      @client = Client.new(api_key: "test_key")
      @sample = Rails.root.join("test/fixtures/files/sample.mp3").to_s
    end

    test "raises when no api key is configured" do
      Rails.application.credentials.stubs(:dig).returns(nil)
      ENV.stubs(:[]).with("ELEVENLABS_API_KEY").returns(nil)

      assert_raises(Client::Error) { Client.new(api_key: nil) }
    end

    test "add_voice posts to ElevenLabs and returns voice_id" do
      response = mock("Response")
      response.stubs(:success?).returns(true)
      response.stubs(:parsed_response).returns({ "voice_id" => "voice_xyz" })

      Client.expects(:post).with(
        "/voices/add",
        has_entries(headers: { "xi-api-key" => "test_key" }, multipart: true)
      ).returns(response)

      result = @client.add_voice(name: "Test", sample_paths: [@sample])
      assert_equal "voice_xyz", result
    end

    test "add_voice raises on API failure" do
      response = mock("Response")
      response.stubs(:success?).returns(false)
      response.stubs(:code).returns(400)
      response.stubs(:body).returns("bad request")

      Client.stubs(:post).returns(response)

      assert_raises(Client::Error) do
        @client.add_voice(name: "Test", sample_paths: [@sample])
      end
    end

    test "speech_to_speech posts source audio and returns body bytes" do
      response = mock("Response")
      response.stubs(:success?).returns(true)
      response.stubs(:body).returns("mp3-bytes")

      Client.expects(:post).with(
        "/speech-to-speech/voice_xyz",
        has_entries(headers: { "xi-api-key" => "test_key" }, multipart: true)
      ).returns(response)

      result = @client.speech_to_speech(voice_id: "voice_xyz", source_path: @sample)
      assert_equal "mp3-bytes", result
    end

    test "speech_to_speech raises on API failure" do
      response = mock("Response")
      response.stubs(:success?).returns(false)
      response.stubs(:code).returns(500)
      response.stubs(:body).returns("server error")

      Client.stubs(:post).returns(response)

      assert_raises(Client::Error) do
        @client.speech_to_speech(voice_id: "voice_xyz", source_path: @sample)
      end
    end

    test "delete_voice returns true on success" do
      response = mock("Response")
      response.stubs(:success?).returns(true)
      response.stubs(:code).returns(200)

      Client.stubs(:delete).returns(response)

      assert @client.delete_voice("voice_xyz")
    end
  end
end

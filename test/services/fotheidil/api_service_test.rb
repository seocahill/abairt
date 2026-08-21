# frozen_string_literal: true

require "test_helper"

module Fotheidil
  class ApiServiceTest < ActiveSupport::TestCase
    setup do
      @service = ApiService.new("test_key")
      @file = Rails.root.join("test/fixtures/files/deasaigh.mp3").to_s
    end

    def stub_response(code:, body:)
      response = mock("response")
      response.stubs(:code).returns(code)
      response.stubs(:success?).returns(code.between?(200, 299))
      response.stubs(:parsed_response).returns(body)
      response.stubs(:body).returns(body.to_json)
      response
    end

    test "submit returns the job id" do
      HTTParty.stubs(:post).returns(stub_response(code: 200, body: {"id" => 3826, "status" => "queued"}))

      assert_equal 3826, @service.submit(@file, file_name: "deasaigh.mp3")
    end

    test "submit raises when the file is missing" do
      error = assert_raises(ApiService::Error) do
        @service.submit("/tmp/does-not-exist.mp3", file_name: "nope.mp3")
      end

      assert_includes error.message, "File not found"
    end

    test "submit raises on a duplicate media name" do
      HTTParty.stubs(:post).returns(stub_response(code: 500, body: {"message" => "audio already uploaded"}))

      error = assert_raises(ApiService::Error) do
        @service.submit(@file, file_name: "deasaigh.mp3")
      end

      assert_includes error.message, "audio already uploaded"
    end

    test "transcript returns segments when ready" do
      segments = [
        {"id" => "0000", "text" => "Dia dhuit", "speaker" => "SPEAKER_00",
         "startTimeSeconds" => 0.57, "endTimeSeconds" => 2.87}
      ]
      HTTParty.stubs(:get).returns(
        stub_response(code: 200, body: {"id" => 3826, "status" => "completed", "transcript" => segments})
      )

      assert_equal segments, @service.transcript(3826)
    end

    test "transcript returns nil while recognition is still running" do
      HTTParty.stubs(:get).returns(
        stub_response(code: 409, body: {"message" => "Transcript is not ready yet"})
      )

      assert_nil @service.transcript(3826)
    end

    test "transcript raises on an unauthorised key" do
      HTTParty.stubs(:get).returns(stub_response(code: 401, body: {"message" => "Unauthorized"}))

      error = assert_raises(ApiService::Error) { @service.transcript(3826) }

      assert_includes error.message, "401"
    end

    test "raises when no api key is configured" do
      ApiService.stubs(:api_key).returns(nil)

      error = assert_raises(ApiService::Error) { ApiService.new.key_status }

      assert_includes error.message, "No Abair API key configured"
    end
  end
end

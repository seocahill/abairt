require 'test_helper'

module Api
  module VoiceRecordings
    class DiarizationWebhooksControllerTest < ActionDispatch::IntegrationTest
      test "handles successful webhook" do
        voice_recording = voice_recordings(:one)
        mock_service = mock('DiarizationService')

        DiarizationService.expects(:new)
                         .with(voice_recording)
                         .returns(mock_service)

        mock_service.expects(:handle_webhook)
                   .with(has_entries('jobId' => '123', 'status' => 'succeeded'))
                   .returns(true)

        post api_voice_recording_diarization_webhook_url(voice_recording),
             params: { jobId: '123', status: 'succeeded' }

        assert_response :success
      end

      test "handles failed webhook" do
        voice_recording = voice_recordings(:one)
        mock_service = mock('DiarizationService')

        DiarizationService.expects(:new)
                         .with(voice_recording)
                         .returns(mock_service)

        mock_service.expects(:handle_webhook)
                   .with(has_entries('jobId' => '123', 'status' => 'failed'))
                   .returns(false)

        post api_voice_recording_diarization_webhook_url(voice_recording),
             params: { jobId: '123', status: 'failed' }

        assert_response :unprocessable_entity
      end

      test "handles non-existent voice recording" do
        post api_voice_recording_diarization_webhook_url(-1)
        assert_response :not_found
      end

      test "rejects a missing or wrong token once a secret is configured" do
        voice_recording = voice_recordings(:one)
        DiarizationService.expects(:new).never

        with_secret("s3cret") do
          post api_voice_recording_diarization_webhook_url(voice_recording), params: {jobId: "123", status: "succeeded"}
          assert_response :unauthorized

          post api_voice_recording_diarization_webhook_url(voice_recording, token: "nope"), params: {jobId: "123", status: "succeeded"}
          assert_response :unauthorized
        end
      end

      test "accepts the right token once a secret is configured" do
        voice_recording = voice_recordings(:one)
        DiarizationService.stubs(:new).returns(stub(handle_webhook: true))

        with_secret("s3cret") do
          post api_voice_recording_diarization_webhook_url(voice_recording, token: "s3cret"), params: {jobId: "123", status: "succeeded"}
          assert_response :success
        end
      end

      private

      def with_secret(value)
        ENV["DIARIZATION_WEBHOOK_SECRET"] = value
        yield
      ensure
        ENV.delete("DIARIZATION_WEBHOOK_SECRET")
      end
    end
  end
end

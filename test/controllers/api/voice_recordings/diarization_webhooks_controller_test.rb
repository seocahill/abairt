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
        assert_raises(ActiveRecord::RecordNotFound) do
          post api_voice_recording_diarization_webhook_url(-1)
        end
      end
    end
  end
end

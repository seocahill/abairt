require 'test_helper'
require 'httparty'

class DiarizationServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    @voice_recording = voice_recordings(:one)
    @service = DiarizationService.new(@voice_recording)

    # Stub the API key

    # Stub the URL helpers
    Rails.application.routes.url_helpers.stubs(:url_for).returns('https://example.com/media.mp3')
    Rails.application.routes.url_helpers.stubs(:api_voice_recording_diarization_webhook_url)
             .returns('https://example.com/webhook')

    # Stub Rails.application.config
    Rails.application.config.stubs(:action_mailer).returns(
      OpenStruct.new(default_url_options: { host: 'example.com' })
    )
  end

  test "diarize returns false when media is not attached" do
    @voice_recording.media.stubs(:attached?).returns(false)
    assert_not @service.diarize
  end

  test "diarize makes API request and updates status on success" do
    @voice_recording.media.stubs(:attached?).returns(true)

    success_response = mock('Response')
    success_response.stubs(:success?).returns(true)
    success_response.stubs(:[]).with('jobId').returns('123')

    HTTParty.expects(:post).with(
      "https://api.pyannote.ai/v1/diarize",
      has_entries(
        headers: {
          "Authorization" => "Bearer test_key",
          "Content-Type" => "application/json"
        },
        body: {
          webhook: "https://example.com/webhook",
          url: "https://example.com/media.mp3"
        }.to_json
      )
    ).returns(success_response)

    assert @service.diarize
    assert_equal 'pending', @voice_recording.diarization_status
    assert_equal({ 'job_id' => '123' }, @voice_recording.diarization_data)
  end

  test "diarize handles API failure" do
    @voice_recording.media.stubs(:attached?).returns(true)

    error_response = mock('Response')
    error_response.stubs(:success?).returns(false)
    error_response.stubs(:body).returns('error')

    HTTParty.expects(:post).returns(error_response)

    assert_not @service.diarize
    assert_nil @voice_recording.diarization_status
  end

  test "handle_webhook processes successful diarization" do
    @voice_recording.update(diarization_data: { 'job_id' => '123' })
    @voice_recording.dictionary_entries.delete_all

    payload = {
      'jobId' => '123',
      'status' => 'succeeded',
      'output' => {
        'diarization' => [
          { 'speaker' => 'SPEAKER_01', 'start' => 0.0, 'end' => 1.0 },
          { 'speaker' => 'SPEAKER_02', 'start' => 1.0, 'end' => 2.0 }
        ]
      }
    }

    perform_enqueued_jobs do
      assert @service.handle_webhook(payload)
    end

    assert_equal 'completed', @voice_recording.diarization_status
    assert_equal payload['output'], @voice_recording.diarization_data
    assert_equal 2, @voice_recording.dictionary_entries.count
  end

  test "handle_webhook ignores mismatched job_id" do
    @voice_recording.update(diarization_data: { 'job_id' => '123' })

    payload = {
      'jobId' => '456',
      'status' => 'succeeded',
      'output' => { 'diarization' => [] }
    }

    assert_not @service.handle_webhook(payload)
    assert_not_equal 'completed', @voice_recording.diarization_status
  end

  test "handle_webhook handles failed status" do
    @voice_recording.update(diarization_data: { 'job_id' => '123' })

    payload = {
      'jobId' => '123',
      'status' => 'failed'
    }

    assert_not @service.handle_webhook(payload)
    assert_equal 'failed', @voice_recording.diarization_status
  end
end

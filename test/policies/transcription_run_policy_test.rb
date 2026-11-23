require "test_helper"

class TranscriptionRunPolicyTest < ActiveSupport::TestCase
  setup do
    @recording = voice_recordings(:two) # owned by users(:two)
    @run = TranscriptionRun.new(voice_recording: @recording)
    @candidate = TranscriptionCandidate.new(transcription_run: @run)
  end

  test "an admin or the recording's owner may start, review and resolve" do
    [users(:admin), users(:two)].each do |user|
      policy = TranscriptionRunPolicy.new(user, @run)
      assert policy.create?, user.name
      assert policy.show?, user.name
      assert policy.update?, user.name
      assert TranscriptionCandidatePolicy.new(user, @candidate).update?, user.name
    end
  end

  test "nobody else may" do
    [nil, users(:one), users(:four)].each do |user|
      policy = TranscriptionRunPolicy.new(user, @run)
      assert_not policy.create?
      assert_not policy.show?
      assert_not policy.update?
      assert_not TranscriptionCandidatePolicy.new(user, @candidate).update?
    end
  end
end

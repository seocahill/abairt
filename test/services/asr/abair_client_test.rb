require "test_helper"

class Asr::AbairClientTest < ActiveSupport::TestCase
  test "returns the utterance from the response" do
    AudioBlob.stubs(:wav_base64).returns("x")
    Net::HTTP.any_instance.stubs(:request).returns(stub(code: "200", body: {transcriptions: [{utterance: "dia duit"}]}.to_json))
    assert_equal "dia duit", Asr::AbairClient.transcribe("f.wav")
  end

  test "returns nil on failure" do
    AudioBlob.stubs(:wav_base64).raises("boom")
    assert_nil Asr::AbairClient.transcribe("f.wav")
  end
end

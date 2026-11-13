# frozen_string_literal: true

require "test_helper"

class SynthesizeTextToSpeechServiceTest < ActiveSupport::TestCase
  setup do
    audio = Base64.strict_encode64("RIFFfakewav")
    Net::HTTP.any_instance.stubs(:request).returns(stub(body: {audioContent: audio}.to_json))
  end

  test "attaches audio to a saved entry" do
    entry = dictionary_entries(:one)

    SynthesizeTextToSpeechService.new(entry).process

    assert entry.reload.media.attached?
  end

  test "attaches audio even when the entry would fail validation" do
    entry = dictionary_entries(:one)
    duplicate = DictionaryEntry.new(entry.attributes.except("id"))
    duplicate.save!(validate: false)
    assert_not duplicate.valid?

    SynthesizeTextToSpeechService.new(duplicate).process

    assert duplicate.reload.media.attached?
  end

  test "does not attach audio to an unsaved entry" do
    entry = DictionaryEntry.new(word_or_phrase: "uair")

    result = SynthesizeTextToSpeechService.new(entry).process

    assert_not entry.media.attached?
    assert_equal Base64.strict_encode64("RIFFfakewav"), result
  end
end

require "test_helper"

class DictionaryEntryTest < ActiveSupport::TestCase
  test "uniqueness" do
    refute DictionaryEntry.new(word_or_phrase: dictionary_entries(:one).word_or_phrase).valid?
    assert DictionaryEntry.new(word_or_phrase: dictionary_entries(:one).word_or_phrase, voice_recording_id: voice_recordings(:one).id,  user_id: users(:one).id).valid?
  end
end

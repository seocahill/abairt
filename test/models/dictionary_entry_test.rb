require "test_helper"

class DictionaryEntryTest < ActiveSupport::TestCase
  test "uniqueness" do
    refute DictionaryEntry.new(word_or_phrase: dictionary_entries(:one).word_or_phrase).valid?
    assert DictionaryEntry.new(word_or_phrase: dictionary_entries(:one).word_or_phrase, voice_recording_id: voice_recordings(:one).id,  user_id: users(:one).id).valid?
  end

  test "defaults to unconfirmed" do
    entry = DictionaryEntry.new(word_or_phrase: "Test", translation: "Test", user_id: users(:one).id)
    assert entry.unconfirmed?
  end

  test "cannot edit when confirmed" do
    entry = dictionary_entries(:two) # confirmed entry
    assert entry.confirmed?
    
    entry.word_or_phrase = "Changed"
    refute entry.valid?
    assert_includes entry.errors[:base], "Cannot edit confirmed entries. Please deconfirm first."
  end

  test "can deconfirm confirmed entry" do
    entry = dictionary_entries(:two) # confirmed entry
    entry.accuracy_status = :unconfirmed
    assert entry.valid?
  end

  test "unconfirmed_accuracy scope returns unconfirmed entries" do
    entry_one = dictionary_entries(:one)
    entry_two = dictionary_entries(:two)
    
    # Reload to ensure enum values are correct
    entry_one.reload
    entry_two.reload
    
    assert entry_one.unconfirmed?, "Entry one should be unconfirmed (got: #{entry_one.accuracy_status})"
    assert entry_two.confirmed?, "Entry two should be confirmed (got: #{entry_two.accuracy_status})"
    
    # Test the scope by checking IDs - use unconfirmed_accuracy to avoid conflict with status enum
    unconfirmed_ids = DictionaryEntry.unconfirmed_accuracy.pluck(:id)
    assert_includes unconfirmed_ids, entry_one.id, "Entry one should be in unconfirmed scope"
    refute_includes unconfirmed_ids, entry_two.id, "Entry two should NOT be in unconfirmed scope (found in: #{unconfirmed_ids})"
  end

  test "confirmed_accuracy scope returns confirmed entries" do
    entry_one = dictionary_entries(:one)
    entry_two = dictionary_entries(:two)
    
    confirmed_ids = DictionaryEntry.confirmed_accuracy.pluck(:id)
    assert_includes confirmed_ids, entry_two.id
    refute_includes confirmed_ids, entry_one.id
  end
end

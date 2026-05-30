# frozen_string_literal: true

require "test_helper"

class ClonedAudioRenditionTest < ActiveSupport::TestCase
  def setup
    @voice_user = users(:one)
    @voice_user.update!(cloned_voice_id: "voice_abc", voice_clone_status: :ready)
    @entry = dictionary_entries(:two)
  end

  test "requires voice_user with a cloned voice" do
    bare_user = users(:two)
    rendition = ClonedAudioRendition.new(voice_user: bare_user, source: @entry)

    assert_not rendition.valid?
    assert_includes rendition.errors[:voice_user], "must have a cloned voice"
  end

  test "is valid with a voice user who has a cloned voice" do
    rendition = ClonedAudioRendition.new(voice_user: @voice_user, source: @entry)
    assert rendition.valid?
  end

  test "uniqueness on voice_user + source" do
    ClonedAudioRendition.create!(voice_user: @voice_user, source: @entry)
    duplicate = ClonedAudioRendition.new(voice_user: @voice_user, source: @entry)

    assert_not duplicate.valid?
  end

  test "default status is pending" do
    rendition = ClonedAudioRendition.new(voice_user: @voice_user, source: @entry)
    assert rendition.pending?
  end
end

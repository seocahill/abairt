# frozen_string_literal: true

require "test_helper"

module VoiceCloning
  class RenderRenditionServiceTest < ActiveSupport::TestCase
    def setup
      @voice_user = users(:one)
      @voice_user.update!(cloned_voice_id: "voice_abc", voice_clone_status: :ready)

      @entry = dictionary_entries(:two)
      sample = Rails.root.join("test/fixtures/files/sample.mp3")
      @entry.media.attach(io: File.open(sample), filename: "sample.mp3", content_type: "audio/mpeg")

      @rendition = ClonedAudioRendition.create!(voice_user: @voice_user, source: @entry)
      @changer = mock("VoiceChangerService")
    end

    test "attaches converted audio and marks rendition ready" do
      @changer.expects(:call).returns("converted-bytes")

      service = RenderRenditionService.new(@rendition, changer: @changer)
      service.call

      @rendition.reload
      assert @rendition.ready?
      assert @rendition.media.attached?
      assert_equal "audio/mpeg", @rendition.media.content_type
    end

    test "marks rendition failed when changer raises" do
      @changer.expects(:call).raises(VoiceChangerService::Error.new("boom"))

      service = RenderRenditionService.new(@rendition, changer: @changer)
      assert_raises(VoiceChangerService::Error) { service.call }

      @rendition.reload
      assert @rendition.failed?
      assert_equal "boom", @rendition.error_message
    end

    test "raises when source has no media" do
      @entry.media.purge
      service = RenderRenditionService.new(@rendition, changer: @changer)

      assert_raises(RenderRenditionService::Error) { service.call }
    end
  end
end

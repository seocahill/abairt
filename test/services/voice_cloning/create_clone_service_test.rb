# frozen_string_literal: true

require "test_helper"

module VoiceCloning
  class CreateCloneServiceTest < ActiveSupport::TestCase
    def setup
      @user = users(:four) # speaker
      @user.update!(role: :speaker, dialect: :acaill)

      sample = Rails.root.join("test/fixtures/files/sample.mp3")
      CreateCloneService::MIN_SAMPLES.times do |i|
        entry = DictionaryEntry.create!(
          word_or_phrase: "phrase_#{i}_#{SecureRandom.hex(2)}",
          owner: @user,
          speaker: @user,
          accuracy_status: 1
        )
        entry.media.attach(io: File.open(sample), filename: "sample_#{i}.mp3", content_type: "audio/mpeg")
      end

      @client = mock("ElevenLabs::Client")
    end

    test "creates a cloned voice and stores the voice_id" do
      @client.expects(:add_voice).returns("voice_abc")

      service = CreateCloneService.new(@user, client: @client)
      service.call

      @user.reload
      assert_equal "voice_abc", @user.cloned_voice_id
      assert @user.voice_clone_ready?
      assert_equal "elevenlabs", @user.voice_clone_provider
      assert_not_nil @user.voice_cloned_at
    end

    test "raises and marks failed when not enough samples" do
      @user.spoken_dictionary_entries.destroy_all

      service = CreateCloneService.new(@user, client: @client)
      assert_raises(CreateCloneService::Error) { service.call }

      @user.reload
      assert @user.voice_clone_failed?
      assert_match(/not enough audio samples/, @user.voice_clone_error)
    end

    test "raises when user already has a cloned voice" do
      @user.update!(cloned_voice_id: "existing", voice_clone_status: :ready)

      service = CreateCloneService.new(@user, client: @client)
      assert_raises(CreateCloneService::Error) { service.call }
    end

    test "marks failed when client raises" do
      @client.expects(:add_voice).raises(ElevenLabs::Client::Error.new("boom"))

      service = CreateCloneService.new(@user, client: @client)
      assert_raises(ElevenLabs::Client::Error) { service.call }

      @user.reload
      assert @user.voice_clone_failed?
      assert_equal "boom", @user.voice_clone_error
    end
  end
end

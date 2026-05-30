# frozen_string_literal: true

require "test_helper"

module DictionaryEntries
  class ClonedRenditionsControllerTest < ActionDispatch::IntegrationTest
    def setup
      @user = users(:one)
      @voice_user = users(:four)
      @voice_user.update!(cloned_voice_id: "voice_abc", voice_clone_status: :ready)
      @entry = dictionary_entries(:two)
      sample = Rails.root.join("test/fixtures/files/sample.mp3")
      @entry.media.attach(io: File.open(sample), filename: "sample.mp3", content_type: "audio/mpeg")
      sign_in_as(@user)
    end

    test "first show enqueues a render job and returns pending" do
      assert_enqueued_jobs 1, only: RenderClonedRenditionJob do
        get dictionary_entry_cloned_rendition_path(@entry, @voice_user)
      end

      assert_response :accepted
      assert_equal "pending", JSON.parse(response.body)["status"]
    end

    test "show returns ready audio url when rendition is ready" do
      rendition = ClonedAudioRendition.create!(voice_user: @voice_user, source: @entry, status: :ready)
      sample = Rails.root.join("test/fixtures/files/sample.mp3")
      rendition.media.attach(io: File.open(sample), filename: "rendered.mp3", content_type: "audio/mpeg")

      get dictionary_entry_cloned_rendition_path(@entry, @voice_user)

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal "ready", body["status"]
      assert body["audioUrl"].present?
    end

    test "show returns 404 for a user without a cloned voice" do
      bare_user = users(:two)

      get dictionary_entry_cloned_rendition_path(@entry, bare_user)
      assert_response :not_found
    end

    private

    def sign_in_as(user)
      unless user.login_token.present?
        user.regenerate_login_token
        user.save!
      end
      post login_path, params: { token: user.login_token }
    end
  end
end

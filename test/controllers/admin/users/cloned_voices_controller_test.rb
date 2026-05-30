# frozen_string_literal: true

require "test_helper"

module Admin
  module Users
    class ClonedVoicesControllerTest < ActionDispatch::IntegrationTest
      def setup
        @admin = users(:one)
        @admin.update(role: :admin)
        @speaker = users(:four)
        sign_in_as(@admin)
      end

      test "create enqueues the clone job and marks user pending" do
        assert_enqueued_with(job: CreateClonedVoiceJob, args: [@speaker.id]) do
          post admin_user_cloned_voice_path(@speaker)
        end

        assert_redirected_to admin_user_path(@speaker)
        assert @speaker.reload.voice_clone_pending?
      end

      test "create refuses when user already has a cloned voice" do
        @speaker.update!(cloned_voice_id: "voice_abc", voice_clone_status: :ready)

        assert_no_enqueued_jobs only: CreateClonedVoiceJob do
          post admin_user_cloned_voice_path(@speaker)
        end
        assert_redirected_to admin_user_path(@speaker)
      end

      test "destroy clears voice metadata" do
        @speaker.update!(cloned_voice_id: "voice_abc", voice_clone_status: :ready, voice_clone_provider: "elevenlabs")

        client = mock("ElevenLabs::Client")
        client.stubs(:delete_voice).returns(true)
        ElevenLabs::Client.stubs(:new).returns(client)

        delete admin_user_cloned_voice_path(@speaker)

        assert_redirected_to admin_user_path(@speaker)
        @speaker.reload
        assert_nil @speaker.cloned_voice_id
        assert @speaker.voice_clone_none?
      end

      test "non-admin is denied" do
        sign_in_as(users(:two))
        post admin_user_cloned_voice_path(@speaker)
        assert_redirected_to root_path
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
end

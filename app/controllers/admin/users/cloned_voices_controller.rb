# frozen_string_literal: true

module Admin
  module Users
    class ClonedVoicesController < ApplicationController
      before_action :ensure_admin
      before_action :set_user

      def create
        authorize :cloned_voice, :create?, policy_class: Admin::ClonedVoicePolicy

        if @user.cloned_voice?
          redirect_to admin_user_path(@user), alert: "User already has a cloned voice."
          return
        end

        @user.update(voice_clone_status: :pending, voice_clone_error: nil)
        CreateClonedVoiceJob.perform_later(@user.id)

        redirect_to admin_user_path(@user), notice: "Voice cloning started. This usually takes a minute."
      end

      def destroy
        authorize :cloned_voice, :destroy?, policy_class: Admin::ClonedVoicePolicy

        voice_id = @user.cloned_voice_id
        if voice_id.present?
          begin
            ElevenLabs::Client.new.delete_voice(voice_id)
          rescue
            nil
          end
        end

        @user.update!(
          cloned_voice_id: nil,
          voice_clone_status: :none,
          voice_clone_provider: nil,
          voice_cloned_at: nil,
          voice_clone_error: nil
        )

        redirect_to admin_user_path(@user), notice: "Cloned voice removed."
      end

      private

      def set_user
        @user = User.find(params[:user_id])
      end

      def ensure_admin
        user = User.find_by(id: session[:user_id])
        redirect_to(root_path, alert: "Not logged in.") and return if user.nil?
        redirect_to(root_path, alert: "Admin only.") and return unless user.admin?
      end
    end
  end
end

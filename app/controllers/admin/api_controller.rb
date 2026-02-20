# frozen_string_literal: true

module Admin
  class ApiController < ApplicationController
    include Pagy::Backend

    before_action :ensure_admin
    skip_after_action :verify_authorized

    def index
      scope = User.where.not(api_token: nil).order(updated_at: :desc)
      scope = scope.where("name ILIKE ? OR email ILIKE ?", "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?

      @pagy, @api_users = pagy(scope, items: 25)

      @stats = {
        total_tokens: User.where.not(api_token: nil).count,
        active_today: User.where.not(api_token: nil).where("updated_at > ?", 24.hours.ago).count,
        by_role: User.where.not(api_token: nil).group(:role).count
      }
    end

    def generate
      @user = User.find(params[:user_id])
      @user.regenerate_api_token
      redirect_to admin_api_index_path, notice: "API token generated for #{@user.name}"
    end

    def regenerate
      @user = User.find(params[:user_id])
      @user.regenerate_api_token
      redirect_to admin_api_index_path, notice: "API token regenerated for #{@user.name}"
    end

    def revoke
      @user = User.find(params[:user_id])
      @user.update(api_token: nil)
      redirect_to admin_api_index_path, notice: "API token revoked for #{@user.name}"
    end
  end
end

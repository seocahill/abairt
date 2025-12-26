# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    include HasScope

    before_action :ensure_admin
    before_action :set_user, only: [:show, :edit, :update, :approve, :reject, :destroy, :generate_api_token, :regenerate_api_token, :revoke_api_token]

    has_scope :pending, type: :boolean
    has_scope :by_role, as: :role
    has_scope :search

    def index
      @users = apply_scopes(User.order(created_at: :desc))
      @pagy, @users = pagy(@users, items: params[:per_page] || 50)
      # Authorization handled by ensure_admin
    end

    def show
      # Authorization handled by ensure_admin
    end

    def edit
      authorize @user, :update?
    end

    def update
      authorize @user, :update?
      if @user.update(user_params)
        redirect_to admin_user_path(@user), notice: 'User updated successfully.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def approve
      authorize @user, :approve?
      @user.update(confirmed: true)
      redirect_to admin_user_path(@user), notice: 'User approved successfully.'
    end

    def reject
      authorize @user, :reject?
      @user.destroy
      redirect_to admin_users_path(pending: true), notice: 'User rejected and deleted.'
    end

    def bulk_approve
      authorize User, :bulk_approve?
      user_ids = params[:user_ids] || []
      User.where(id: user_ids).update_all(confirmed: true)
      redirect_to admin_users_path(pending: true), notice: "#{user_ids.count} users approved."
    end

    def bulk_reject
      authorize User, :bulk_reject?
      user_ids = params[:user_ids] || []
      count = User.where(id: user_ids).count
      User.where(id: user_ids).destroy_all
      redirect_to admin_users_path(pending: true), notice: "#{count} users rejected and deleted."
    end

    def destroy
      authorize @user, :destroy?
      @user.destroy
      redirect_to admin_users_path, notice: 'User deleted successfully.'
    end

    def generate_api_token
      authorize :api_token, :create?, policy_class: Admin::ApiTokenPolicy
      @user.regenerate_api_token
      @user.save!
      redirect_to admin_user_path(@user), notice: 'API token generated successfully.'
    end

    def regenerate_api_token
      authorize :api_token, :update?, policy_class: Admin::ApiTokenPolicy
      @user.regenerate_api_token
      @user.save!
      redirect_to admin_user_path(@user), notice: 'API token regenerated successfully.'
    end

    def revoke_api_token
      authorize :api_token, :destroy?, policy_class: Admin::ApiTokenPolicy
      @user.update_column(:api_token, nil)
      redirect_to admin_user_path(@user), notice: 'API token revoked successfully.'
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def ensure_admin
      redirect_to root_path unless current_user&.admin?
    end

    def user_params
      params.require(:user).permit(:name, :email, :role, :about, :voice, :dialect, :ability, :address, :confirmed)
    end
  end
end


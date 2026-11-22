# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    include HasScope

    before_action :ensure_admin
    before_action :set_user, only: [:show, :edit, :update, :approve, :reject, :destroy, :telegram_invite, :generate_api_token, :regenerate_api_token, :revoke_api_token]
    skip_after_action :verify_authorized, only: [:index, :show]

    # The tabs of the users list, one per kind of person, then everyone.
    KIND_TABS = [*User::KINDS.keys.map(&:to_s), "all"].freeze
    # The role a new user starts with on each kind's "New" form.
    NEW_ROLES = {"members" => "student", "speakers" => "speaker", "staff" => "api_user"}.freeze

    has_scope :pending, type: :boolean
    has_scope :by_role, as: :role
    has_scope :search

    def index
      # Authorization handled by ensure_admin
      @kind = params[:kind].presence_in(KIND_TABS) || kind_of_role || "members"
      # Diarisation leaves many unnamed speakers behind; only Other and All
      # list them.
      base = @kind.in?(%w[other all]) ? User.all : User.active
      @users = apply_scopes(base.of_kind(@kind).order(created_at: :desc))
      @pagy, @users = pagy(@users, items: params[:per_page] || 50)
      # Where approve, reject and delete come back to: this tab, as filtered.
      session[:admin_users_filter] = filter_params.to_h.merge(kind: @kind)
    end

    def show
      # Authorization handled by ensure_admin
    end

    # Opens on the speaker form unless another kind is asked for: speakers
    # are the people admin most often has to set up by hand.
    def new
      @user = User.new(role: NEW_ROLES.fetch(params[:kind], "speaker"))
      authorize @user, :create?
    end

    # Speakers have no way to sign up: they never see a web page. This is where
    # they come from.
    def create
      @user = User.new(user_params)
      authorize @user, :create?

      if @user.save
        redirect_to admin_user_path(@user), notice: "User created successfully."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
      authorize @user, :update?
    end

    # A speaker who predates invite links has no token, and one who lost their
    # link or changed phone needs a new one. Issuing a new token invalidates
    # the old link.
    def telegram_invite
      authorize @user, :update?
      @user.regenerate_telegram_invite_token

      redirect_to admin_user_path(@user), notice: "New invite link ready to send."
    end

    def update
      authorize @user, :update?
      if @user.update(user_params)
        redirect_to admin_user_path(@user), notice: "User updated successfully."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def approve
      authorize @user, :approve?
      @user.update(confirmed: true)
      UserMailer.account_approved_email(@user).deliver_later
      redirect_to admin_user_path(@user), notice: "User approved successfully."
    end

    def reject
      authorize @user, :reject?
      @user.destroy
      redirect_to admin_users_path(saved_filter_params), notice: "User rejected and deleted."
    end

    def bulk_approve
      authorize User, :bulk_approve?
      user_ids = params[:user_ids] || []
      users = User.where(id: user_ids)
      users.update_all(confirmed: true)
      users.each { |user| UserMailer.account_approved_email(user).deliver_later }
      redirect_to admin_users_path(saved_filter_params), notice: "#{user_ids.count} users approved."
    end

    def bulk_reject
      authorize User, :bulk_reject?
      user_ids = params[:user_ids] || []
      count = User.where(id: user_ids).count
      User.where(id: user_ids).destroy_all
      redirect_to admin_users_path(saved_filter_params), notice: "#{count} users rejected and deleted."
    end

    def destroy
      authorize @user, :destroy?
      @user.destroy
      redirect_to admin_users_path(saved_filter_params), notice: "User deleted successfully."
    end

    def generate_api_token
      authorize :api_token, :create?, policy_class: Admin::ApiTokenPolicy
      @user.regenerate_api_token
      @user.save!
      redirect_to admin_user_path(@user), notice: "API token generated successfully."
    end

    def regenerate_api_token
      authorize :api_token, :update?, policy_class: Admin::ApiTokenPolicy
      @user.regenerate_api_token
      @user.save!
      redirect_to admin_user_path(@user), notice: "API token regenerated successfully."
    end

    def revoke_api_token
      authorize :api_token, :destroy?, policy_class: Admin::ApiTokenPolicy
      @user.update_column(:api_token, nil)
      redirect_to admin_user_path(@user), notice: "API token revoked successfully."
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def ensure_admin
      user = User.find_by(id: session[:user_id])
      if user.nil?
        redirect_to root_path, alert: "Not logged in. Please log in first."
        return
      end

      redirect_to root_path, alert: "Access denied. Admin privileges required." unless user.admin?
    end

    # An older link that filters by role opens on that role's tab.
    def kind_of_role
      User.new(role: params[:role]).kind.to_s if User.roles.key?(params[:role])
    end

    def filter_params
      params.permit(:pending, :search, :per_page)
    end

    def saved_filter_params
      session[:admin_users_filter] || {}
    end

    def user_params
      params.require(:user).permit(:name, :email, :role, :about, :voice, :dialect, :ability, :address, :confirmed,
        :phone_number, :answers_questions, :telegram_chat_id)
    end
  end
end

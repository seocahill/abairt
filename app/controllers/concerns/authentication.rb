# frozen_string_literal: true

module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate
  end

  private

  def authenticate
    if authenticated_user = User.find_by(id: session[:user_id], confirmed: true)
      Current.user = authenticated_user
    end
  end
end

# frozen_string_literal: true

module Authentication
  extend ActiveSupport::Concern

  REMEMBER_COOKIE = :remember_token

  included do
    before_action :authenticate
  end

  private

  def authenticate
    resume_session_from_cookie if session[:user_id].blank?

    Current.user = User.find_by(id: session[:user_id], confirmed: true)
  end

  # A learner asking a question is standing in a field holding a toddler. If the
  # session has lapsed, "record and send" becomes "go and find a login link in
  # your email", which is the same as the feature not existing. So a signed
  # permanent cookie resurrects the session instead.
  #
  # It repopulates session[:user_id] rather than replacing it, so everything
  # already reading the session keeps working unchanged.
  def resume_session_from_cookie
    token = cookies.signed[REMEMBER_COOKIE]
    return if token.blank?

    user = User.find_by(remember_token: token, confirmed: true)
    return cookies.delete(REMEMBER_COOKIE) if user.nil?

    session[:user_id] = user.id
  end

  def remember(user)
    user.regenerate_remember_token
    cookies.permanent.signed[REMEMBER_COOKIE] = {
      value: user.remember_token,
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production?
    }
  end

  def forget(user)
    user&.regenerate_remember_token
    cookies.delete(REMEMBER_COOKIE)
  end
end

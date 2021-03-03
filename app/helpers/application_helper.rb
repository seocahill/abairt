# frozen_string_literal: true

module ApplicationHelper
  include Pagy::Frontend

  def current_user_can_edit
    current_user
  end

  def user_gravatar(user)
    return 'http://secure.gravatar.com/avatar/' unless user

    gravatar_id = Digest::MD5.hexdigest(user.email.downcase)
    gravatar_url = "http://secure.gravatar.com/avatar/#{gravatar_id}"
    image_tag(gravatar_url, alt: user.name)
  end

  def page_title
    controller.controller_name.humanize.capitalize
  end
end

# frozen_string_literal: true

module ApplicationHelper
  include Pagy::Frontend

  def current_user_can_edit
    current_user
  end
end

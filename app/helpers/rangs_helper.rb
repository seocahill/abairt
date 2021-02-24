# frozen_string_literal: true

module RangsHelper
  def current_user_can_edit
    current_user&.rangs&.include?(@rang)
  end
end

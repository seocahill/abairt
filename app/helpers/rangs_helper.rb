# frozen_string_literal: true

module RangsHelper
  def current_user_can_edit
    current_user&.rangs&.include?(@rang)
  end

  def type(rang)
    if rang.url
      ["Alt", "green"]
    elsif rang.media.attached?
      ["Tras-scríbhinn", "purple"]
    else
      ["Comhrá", "gray"]
    end
  end
end

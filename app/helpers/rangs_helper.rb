# frozen_string_literal: true

module RangsHelper
  def current_user_can_edit
    current_user&.rangs&.include?(@rang)
  end

  def other_participents
    users = @rang.users.where.not(id: nil) + [@rang.teacher] - [current_user]
    users.pluck(:name)
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

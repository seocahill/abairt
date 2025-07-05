# frozen_string_literal: true

class StatusPolicy < ApplicationPolicy
  def index?
    # Allow anyone to view service status - it's public information
    true
  end
end 
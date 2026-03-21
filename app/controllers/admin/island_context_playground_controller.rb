# frozen_string_literal: true

module Admin
  class IslandContextPlaygroundController < ApplicationController
    before_action :ensure_admin
    skip_after_action :verify_authorized

    def index
      @description = params[:description].to_s.strip
      return if @description.blank?

      limit = (params[:limit].presence || 20).to_i.clamp(1, 50)
      @results = IslandContextService.new(@description, limit: limit).call
    end
  end
end

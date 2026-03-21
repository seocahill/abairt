# frozen_string_literal: true

module Api
  class IslandContextController < BaseController
    rate_limit to: 100, within: 1.hour, by: -> { current_api_user&.id || request.remote_ip }

    # POST /api/island_context
    # Params:
    #   description (required) - English description of the island scenario
    #   limit (optional)       - max results to return, default 20, max 50
    def create
      description = params[:description].to_s.strip

      if description.blank?
        return render json: { error: "description is required" }, status: :unprocessable_entity
      end

      entries = IslandContextService.new(description, limit: params[:limit]).call

      render json: {
        entries: serialize_entries(entries),
        meta: { count: entries.size }
      }
    end

    private

    def serialize_entries(entries)
      entries.map do |entry|
        Api::TranscriptionSerializer.new(
          entry,
          params: { url_helper: method(:url_for), host: request.host_with_port }
        ).serializable_hash
      end
    end
  end
end

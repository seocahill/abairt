# frozen_string_literal: true

module Api
  class TranscriptionsController < BaseController
    include HasScope
    include Pagy::Backend

    rate_limit to: 100, within: 1.hour, by: -> { current_api_user&.id || request.remote_ip }

    has_scope :updated_since do |controller, scope, value|
      timestamp = Time.parse(value)
      scope.updated_since(timestamp)
    rescue ArgumentError, TypeError
      scope
    end

    def index
      entries = apply_scopes(DictionaryEntry.confirmed_accuracy)
        .with_attached_media
        .includes(:speaker, :voice_recording)
        .order(updated_at: :desc)

      @pagy, @entries = pagy(entries, items: params[:per_page] || 50)

      render json: {
        entries: @entries.map { |entry| Api::TranscriptionSerializer.new(entry, params: { url_helper: method(:url_for), host: request.host_with_port }).serializable_hash },
        pagination: {
          page: @pagy.page,
          per_page: @pagy.items,
          total: @pagy.count
        }
      }
    end

    def show
      entry = DictionaryEntry.confirmed_accuracy.with_attached_media.find(params[:id])
      render json: Api::TranscriptionSerializer.new(entry, params: { url_helper: method(:url_for), host: request.host_with_port }).serializable_hash
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Not found' }, status: :not_found
    end
  end
end


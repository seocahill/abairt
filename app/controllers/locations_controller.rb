# frozen_string_literal: true

# Public place page: the recordings and speakers from one place. Flag f172_place_pages.
class LocationsController < ApplicationController
  # Deliberately public (read-only), like the recordings index: no Pundit authorize.
  def show
    raise ActiveRecord::RecordNotFound unless Flipper.enabled?(:f172_place_pages, current_user)

    @location = Location.find(params[:id])
    records = @location.all_voice_recordings.joins(:media_attachment).order(created_at: :desc, id: :desc)
    raise ActiveRecord::RecordNotFound if records.none?

    @pagy, @recordings = pagy(records.includes(:tags, :users).with_attached_media, items: PAGE_SIZE)

    respond_to do |format|
      format.html do
        @speakers = @location.speakers
        @pins = [place_pin].compact
      end
      # "Load More" appends the next page below the cards already shown.
      format.turbo_stream
    end
  end

  private

  def place_pin
    @location.coordinates&.merge(location_name: @location.name, recordings: [], more: 0)
  end
end

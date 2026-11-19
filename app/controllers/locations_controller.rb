# frozen_string_literal: true

# Public place page: the recordings and speakers from one place. Flag f172_place_pages.
class LocationsController < ApplicationController
  def show
    raise ActionController::RoutingError, "Not Found" unless Flipper.enabled?(:f172_place_pages, current_user)

    @location = Location.find(params[:id])
    records = @location.all_voice_recordings
    raise ActiveRecord::RecordNotFound if records.none?

    @pagy, @recordings = pagy(records.includes(:tags, :users).with_attached_media, items: PAGE_SIZE)
    @speakers = @location.speakers
    @pins = pins_for(@location, records.first)
    @view_mode = "list"
  end

  private

  def pins_for(location, recording)
    return [] unless location.coordinates

    [{recording_id: recording.id, recording_title: recording.title, location_name: location.name,
      lat: location.latitude.to_f, lng: location.longitude.to_f}]
  end
end

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
    @speakers = @location.speakers
    @pins = pins_for(@location, records.first)
  end

  private

  def pins_for(location, recording)
    return [] unless location.coordinates

    [{recording_id: recording.id, recording_title: recording.title, location_name: location.name,
      lat: location.latitude.to_f, lng: location.longitude.to_f}]
  end
end

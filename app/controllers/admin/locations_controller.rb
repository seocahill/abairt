# frozen_string_literal: true

module Admin
  class LocationsController < ApplicationController
    before_action :ensure_admin
    skip_after_action :verify_authorized

    def index
      @locations = Location.left_joins(:voice_recording_locations)
        .select("locations.*, COUNT(voice_recording_locations.id) AS recordings_count")
        .group("locations.id")
        .order(:dialect_region, :name)
      @locations = @locations.where(dialect_region: params[:dialect_region]) if params[:dialect_region].present?
      @locations = @locations.where("name LIKE ? OR irish_name LIKE ?", "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?

      @stats = {
        total: Location.count,
        with_coordinates: Location.with_coordinates.count,
        precise: Location.with_coordinates.count(&:has_precise_coordinates?),
        by_region: Location.group(:dialect_region).count
      }

      @pagy, @locations = pagy(@locations, items: 50)
    end

    def edit
      @location = Location.find(params[:id])
    end

    def update
      @location = Location.find(params[:id])

      if @location.update(location_params)
        redirect_to admin_locations_path, notice: "#{@location.name} updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def geocode
      @location = Location.find(params[:id])

      if @location.geocode!
        redirect_to edit_admin_location_path(@location), notice: "Geocoded to #{@location.latitude}, #{@location.longitude}."
      else
        redirect_to edit_admin_location_path(@location), alert: "Geocoding failed. Try setting coordinates manually."
      end
    end

    private

    def ensure_admin
      user = User.find_by(id: session[:user_id])
      if user.nil?
        redirect_to root_path, alert: "Not logged in. Please log in first."
        return
      end

      unless user.admin?
        redirect_to root_path, alert: "Access denied. Admin privileges required."
      end
    end

    def location_params
      params.require(:location).permit(:name, :irish_name, :latitude, :longitude, :dialect_region, :location_type, :parent_id)
    end
  end
end

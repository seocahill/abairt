# frozen_string_literal: true

class Location < ApplicationRecord
  has_many :users
  has_many :voice_recordings
  has_many :voice_recording_locations, dependent: :destroy
  has_many :associated_voice_recordings, through: :voice_recording_locations, source: :voice_recording
  has_many :children, class_name: "Location", foreign_key: "parent_id"
  belongs_to :parent, class_name: "Location", optional: true

  enum :location_type, {
    townland: 0,
    parish: 1,
    barony: 2,
    county: 3,
    region: 4
  }

  enum :dialect_region, {
    erris: 0,        # Iorras - northwest Mayo
    achill: 1,       # Acaill - Achill Island
    tourmakeady: 2,  # Tuar Mhic Éadaigh - south Mayo
    east_mayo: 3,    # East Mayo / Sligo border
    other: 4         # Other areas (Roscommon, etc.)
  }

  validates :name, presence: true
  validates :dialect_region, presence: true

  scope :with_coordinates, -> { where.not(latitude: nil, longitude: nil) }
  scope :by_dialect, ->(region) { where(dialect_region: region) }

  # Known Mayo Irish-speaking areas with approximate coordinates
  DIALECT_REGIONS = {
    erris: {
      center: { lat: 54.15, lng: -9.85 },
      areas: %w[Iorras Erris Béal\ an\ Mhuirthead Belmullet Gleann\ na\ Muaidhe Glenamoy
                Ceathrú\ Thaidhg Carrowteige Barr\ na\ Trá Barnatra Dumha\ Thuama Doohoma
                Gaoth\ Sáile Geesala Cill\ Ghallagáin Kilgalligan]
    },
    achill: {
      center: { lat: 53.95, lng: -10.05 },
      areas: %w[Acaill Achill Dúgh\ Aill Dooagh Dún\ Ibhir Dooniver Gob\ an\ Choire Gob\ an\ Choire
                An\ Chorrán Corrán Bun\ na\ hAbhna Bunacurry Dumha\ Éige Dooega
                Cill\ Damhnait Kildavnet Sáile Saula]
    },
    tourmakeady: {
      center: { lat: 53.62, lng: -9.45 },
      areas: %w[Tuar\ Mhic\ Éadaigh Tourmakeady Fionnaithe Finny Srath\ Salach Srathsalach
                Leac\ an\ Anfa Letterkeen Partaí Partry Loch\ Measca Lough\ Mask
                Gleann\ Caisil Glencastle An\ Fhairche Farrhy]
    },
    east_mayo: {
      center: { lat: 53.85, lng: -9.0 },
      areas: %w[Béal\ Átha\ hAmhnais Ballyhaunis Caisleán\ an\ Bharraigh Castlebar
                Clár\ Chlainne\ Mhuiris Claremorris Baile\ an\ Róba Ballinrobe]
    }
  }.freeze

  def coordinates
    return nil unless latitude && longitude
    {lat: latitude.to_f, lng: longitude.to_f}
  end

  def has_precise_coordinates?
    return false unless latitude && longitude

    DIALECT_REGIONS.none? do |_, data|
      center = data[:center]
      latitude.to_f == center[:lat] && longitude.to_f == center[:lng]
    end
  end

  def full_name
    parent ? "#{name}, #{parent.name}" : name
  end

  # Merge this location into another, moving all associations, then delete self
  def merge_into!(target)
    raise ArgumentError, "Cannot merge into self" if target.id == id

    transaction do
      # Move voice_recording_locations (skip if target already has the association)
      voice_recording_locations.find_each do |vrl|
        if target.voice_recording_locations.exists?(voice_recording_id: vrl.voice_recording_id)
          vrl.destroy!
        else
          vrl.update!(location_id: target.id)
        end
      end

      # Move voice_recordings FK
      voice_recordings.update_all(location_id: target.id)

      # Move users FK
      users.update_all(location_id: target.id)

      # Move children
      children.update_all(parent_id: target.id)

      # Fill in any missing data on target
      target.update!(irish_name: irish_name) if irish_name.present? && target.irish_name.blank?
      target.update!(latitude: latitude, longitude: longitude) if has_precise_coordinates? && !target.has_precise_coordinates?

      destroy!
    end

    target
  end

  def geocode!
    coords = self.class.geocode_with_logainm(name)
    coords ||= self.class.geocode_with_logainm(irish_name) if irish_name.present? && irish_name != name
    coords ||= self.class.geocode_with_nominatim(name)
    coords ||= self.class.geocode_with_nominatim(irish_name) if irish_name.present? && irish_name != name
    update!(latitude: coords[:lat], longitude: coords[:lng]) if coords
    coords.present?
  end

  class << self
    def find_or_create_from_analysis(name:, dialect_region: nil, latitude: nil, longitude: nil)
      # Try exact match first
      location = find_by("LOWER(name) = ? OR LOWER(irish_name) = ?", name.downcase, name.downcase)
      return location if location

      # Discard unrecognised values from the LLM (e.g. "unknown") so we fall back to inference
      dialect_region = nil unless dialect_regions.key?(dialect_region.to_s)

      # Infer dialect region from name if not provided
      dialect_region ||= infer_dialect_region(name)

      # Try to get coordinates if not provided
      if latitude.nil? && longitude.nil?
        coords = lookup_coordinates(name, dialect_region)
        latitude = coords[:lat] if coords
        longitude = coords[:lng] if coords
      end

      create!(
        name: name,
        dialect_region: dialect_region,
        latitude: latitude,
        longitude: longitude
      )
    end

    def infer_dialect_region(name)
      normalized = name.downcase.gsub(/[^a-záéíóú\s]/, "")

      DIALECT_REGIONS.each do |region, data|
        data[:areas].each do |area|
          return region.to_s if normalized.include?(area.downcase)
        end
      end

      "other"
    end

    CONNACHT_COUNTIES = %w[Mayo Galway Roscommon Sligo Leitrim].freeze

    def lookup_coordinates(name, _dialect_region = nil)
      geocode_with_logainm(name) || geocode_with_nominatim(name)
    end

    def geocode_with_logainm(name)
      return nil if name.blank?

      api_key = ENV["GAOIS_API_KEY"]
      return nil if api_key.blank?

      query = URI.encode_www_form_component(name)
      uri = URI.parse("https://www.logainm.ie/api/v1.0/?Query=#{query}&PerPage=10")

      request = Net::HTTP::Get.new(uri)
      request["X-Api-Key"] = api_key

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      return nil unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      results = data["results"] || []

      # Find the first result in a Connacht county with coordinates
      results.each do |place|
        coords = place.dig("geography", "coordinates")&.first
        next unless coords

        county = place.dig("includedIn", 0, "nameEN")
        next unless CONNACHT_COUNTIES.include?(county)

        return {lat: coords["latitude"].to_f, lng: coords["longitude"].to_f}
      end

      nil
    rescue => e
      Rails.logger.warn("Logainm geocoding failed for '#{name}': #{e.message}")
      nil
    end

    def geocode_with_nominatim(name)
      return nil if name.blank?

      query = URI.encode_www_form_component("#{name}, Connacht, Ireland")
      uri = URI.parse("https://nominatim.openstreetmap.org/search?q=#{query}&format=json&limit=1&countrycodes=ie")

      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "Abairt/1.0 (Irish language archive)"
      request["Accept-Language"] = "ga,en"

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      return nil unless response.is_a?(Net::HTTPSuccess)

      results = JSON.parse(response.body)
      return nil if results.empty?

      {lat: results.first["lat"].to_f, lng: results.first["lon"].to_f}
    rescue => e
      Rails.logger.warn("Nominatim geocoding failed for '#{name}': #{e.message}")
      nil
    end
  end
end

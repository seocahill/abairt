# frozen_string_literal: true

class Location < ApplicationRecord
  has_many :users
  has_many :voice_recordings
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
    { lat: latitude.to_f, lng: longitude.to_f }
  end

  def full_name
    parent ? "#{name}, #{parent.name}" : name
  end

  class << self
    def find_or_create_from_analysis(name:, dialect_region: nil, latitude: nil, longitude: nil)
      # Try exact match first
      location = find_by("LOWER(name) = ? OR LOWER(irish_name) = ?", name.downcase, name.downcase)
      return location if location

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

    def lookup_coordinates(name, dialect_region)
      # Return center of dialect region as fallback
      region_data = DIALECT_REGIONS[dialect_region.to_sym]
      region_data&.dig(:center)
    end
  end
end

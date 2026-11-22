# frozen_string_literal: true

# Map pins for the recordings map, one per place rather than one per recording
# (flag f172_place_pages). A place with many recordings is a single pin whose
# popup lists a few of them, instead of a cluster that breaks out into a pin
# for every recording.
#
# Recordings with no mapped place fall back to their speakers' coordinates,
# grouped the same way. Those pins carry no place name, so the map can say
# "No place set" rather than showing a speaker's name where a place belongs.
#
#   PlacePins.new.call
#   # => [{lat: 54.2, lng: -9.9, location_id: 3, location_name: "Belmullet",
#   #      recordings: [{id: 12, title: "..."}], more: 17}, ...]
class PlacePins
  RECORDINGS_PER_PIN = 5

  def call
    place_pins + speaker_pins
  end

  private

  def place_pins
    placed_recordings
      .order(VoiceRecording.arel_table[:created_at].desc, VoiceRecording.arel_table[:id].desc)
      .pluck("locations.id", "locations.name", "locations.latitude", "locations.longitude",
        "voice_recordings.id", "voice_recordings.title")
      .group_by(&:first)
      .map do |location_id, rows|
        _, name, lat, lng = rows.first
        pin(lat.to_f, lng.to_f, rows.map { |row| row.last(2) }).merge(location_id: location_id, location_name: name)
      end
  end

  def speaker_pins
    VoiceRecording
      .joins(:users)
      .where.not(users: {lat_lang: [nil, ""]})
      .where.not(id: placed_recordings.select(:id))
      .distinct
      .order(VoiceRecording.arel_table[:created_at].desc, VoiceRecording.arel_table[:id].desc)
      .pluck("users.lat_lang", "voice_recordings.id", "voice_recordings.title", "voice_recordings.created_at")
      .group_by(&:first)
      .map do |lat_lang, rows|
        lat, lng = lat_lang.split(",").map(&:to_f)
        pin(lat, lng, rows.map { |row| row[1, 2] }.uniq)
      end
  end

  def placed_recordings
    VoiceRecording.joins(:location).merge(Location.with_coordinates)
  end

  def pin(lat, lng, recordings)
    {
      lat: lat,
      lng: lng,
      recordings: recordings.first(RECORDINGS_PER_PIN).map { |id, title| {id: id, title: title} },
      more: [recordings.size - RECORDINGS_PER_PIN, 0].max
    }
  end
end

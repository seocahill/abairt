# frozen_string_literal: true

# Map pins for the recordings map, one per place rather than one per recording
# (flag f172_place_pages). A place with many recordings is a single pin whose
# popup lists a few of them, instead of a cluster that breaks out into a pin
# for every recording.
#
# A place's recordings are the ones its place page lists (Location#all_voice_recordings
# with audio): tagged directly or through a recording location. So every place pin
# leads to a page that exists, and its count matches that page.
#
# Recordings with no place on the map fall back to their speakers' coordinates,
# grouped the same way. Those pins carry no place name, so the map can say the
# place isn't on the map rather than showing a speaker's name where a place belongs.
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
    titles = playable_titles(placements.values.flatten.uniq)

    mapped_places.filter_map do |id, name, lat, lng|
      placed = placements.fetch(id, []).to_set
      recordings = titles.to_a.select { |pair| placed.include?(pair.first) }
      next if recordings.empty?

      pin(lat.to_f, lng.to_f, recordings).merge(location_id: id, location_name: name)
    end
  end

  def speaker_pins
    VoiceRecording
      .joins(:users)
      .where.not(users: {lat_lang: [nil, ""]})
      .where.not(id: placements.values.flatten)
      .distinct
      .order(VoiceRecording.arel_table[:created_at].desc, VoiceRecording.arel_table[:id].desc)
      .pluck("users.lat_lang", "voice_recordings.id", "voice_recordings.title", "voice_recordings.created_at")
      .group_by(&:first)
      .map do |lat_lang, rows|
        lat, lng = lat_lang.split(",").map(&:to_f)
        pin(lat, lng, rows.map { |row| row[1, 2] }.uniq)
      end
  end

  # Places on the map, with the ids of every recording tagged to them.
  def placements
    @placements ||= begin
      pairs = VoiceRecording.where.not(location_id: nil).pluck(:location_id, :id) +
        VoiceRecordingLocation.pluck(:location_id, :voice_recording_id)
      mapped = mapped_places.map(&:first).to_set
      pairs.select { |pair| mapped.include?(pair.first) }
        .group_by(&:first)
        .transform_values { |rows| rows.map(&:last).uniq }
    end
  end

  def mapped_places
    @mapped_places ||= Location.with_coordinates.order(:name).pluck(:id, :name, :latitude, :longitude)
  end

  # Recordings with audio, newest first, as {id => title}: the place page lists only these.
  def playable_titles(ids)
    VoiceRecording.joins(:media_attachment).where(id: ids)
      .order(created_at: :desc, id: :desc).pluck(:id, :title).to_h
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

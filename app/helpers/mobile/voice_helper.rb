# frozen_string_literal: true

module Mobile
  module VoiceHelper
    def entry_position(session)
      return 0 unless session.current_entry && session.voice_recording

      session.voice_recording.dictionary_entries
        .where("region_start <= ?", session.current_entry.region_start)
        .count
    end
  end
end

class ProcessDiarizationSegmentJob < ApplicationJob
  queue_as :transcription_queue

  # Rate limit to avoid pounding abair.ie APIs
  RATE_LIMIT_DELAY = 3.seconds

  def perform(voice_recording_id, segment_data, speaker_id)
    # Rate limit BEFORE making any API calls
    sleep(RATE_LIMIT_DELAY)
    
    voice_recording = VoiceRecording.find(voice_recording_id)
    
    # Check for overlapping dictionary entries
    # Don't create if human version already exists in this region
    # Two segments overlap if: NOT (segment1_end <= segment2_start OR segment1_start >= segment2_end)
    # Simplified: they overlap if segment1_start < segment2_end AND segment1_end > segment2_start
    existing_entry = DictionaryEntry
      .where(voice_recording: voice_recording)
      .where(
        "region_start < ? AND region_end > ?",
        segment_data['end'], segment_data['start']
      )
      .where.not(speaker: User.where(role: :temporary))
      .first

    if existing_entry
      Rails.logger.info("Skipping segment #{segment_data['start']}-#{segment_data['end']} - overlaps with human entry #{existing_entry.id}")
      return
    end

    # Find or create temporary speaker user
    name = "#{speaker_id}_#{voice_recording.id}"
    temp_user = User.find_or_create_by(email: "#{name.downcase}@temporary.abairt") do |user|
      user.name = name
      user.password = SecureRandom.hex(16)
      user.role = :temporary
    end

    # Create dictionary entry
    entry = DictionaryEntry.create!(
      speaker: temp_user,
      voice_recording: voice_recording,
      owner: voice_recording.owner,
      region_start: segment_data['start'],
      region_end: segment_data['end']
    )

    # Create audio snippet and transcribe (this will hit abair.ie API)
    entry.create_audio_snippet
    
    Rails.logger.info("Created dictionary entry #{entry.id} for segment #{segment_data['start']}-#{segment_data['end']}")
  end
end
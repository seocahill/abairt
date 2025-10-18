# frozen_string_literal: true

module Fotheidil
  # Creates dictionary entries from Fotheidil diarization segments
  # Reuses the existing ProcessDiarizationSegmentJob pattern
  class CreateSpeakerEntriesService
    def initialize(voice_recording)
      @voice_recording = voice_recording
    end

    def call
      return if @voice_recording.segments.blank?

      speakers = extract_unique_speakers(@voice_recording.segments)
      queue_speaker_segments(speakers, @voice_recording.segments)
    end

    private

    def extract_unique_speakers(segments)
      segments.pluck("speaker").uniq
    end

    def queue_speaker_segments(speakers, segments)
      speakers.each do |speaker_id|
        speaker_segments = segments.select { |segment| segment["speaker"] == speaker_id }

        speaker_segments.each do |segment|
          normalized_segment = normalize_segment(segment)

          if normalized_segment["errors"].present?
            Rails.logger.warn "Skipping invalid segment #{segment['id']}: #{normalized_segment['errors'].join(', ')}"
            next
          end

          queue_segment_processing(normalized_segment, speaker_id)
        end
      end
    end

    def queue_segment_processing(segment, speaker_id)
      ProcessDiarizationSegmentJob.perform_later(
        @voice_recording.id,
        segment,
        speaker_id,
        segment["text"] # Fotheidil provides transcription
      )
    end

    # Transform Fotheidil segment format to match ProcessDiarizationSegmentJob expectations
    # Validates and adds errors array for invalid segments
    def normalize_segment(segment)
      normalized = {
        "start" => segment["startTimeSeconds"],
        "end" => segment["endTimeSeconds"],
        "text" => segment["text"],
        "speaker" => segment["speaker"],
        "fotheidil_id" => segment["id"]
      }

      errors = validate_segment(normalized)
      normalized["errors"] = errors if errors.any?

      normalized
    end

    # Validate segment can create a valid dictionary entry
    def validate_segment(segment)
      errors = []

      errors << "Missing start time" if segment["start"].blank?
      errors << "Missing end time" if segment["end"].blank?
      errors << "Missing text" if segment["text"].blank?
      errors << "Missing speaker" if segment["speaker"].blank?

      if segment["start"].present? && segment["end"].present?
        errors << "Start time must be less than end time" if segment["start"] >= segment["end"]
        errors << "Start time cannot be negative" if segment["start"] < 0
        errors << "End time cannot be negative" if segment["end"] < 0
      end

      errors
    end
  end
end

# frozen_string_literal: true

# Converts a VoiceRecording's VBR MP3 media to a CBR MP3 and stores it as
# audio_track.  The waveform player prefers audio_track over media, so this
# fixes the browser VBR timing drift that causes highlight sync issues.
#
#   TranscodeAudioTrackJob.perform_later(voice_recording)
class TranscodeAudioTrackJob < ApplicationJob
  queue_as :default

  def perform(recording)
    return if recording.audio_track.attached?
    return unless recording.media.attached?
    return unless recording.media.content_type == "audio/mpeg"

    recording.media.open do |input|
      Tempfile.create([ "cbr_audio", ".mp3" ], binmode: true) do |output|
        success = system(
          "ffmpeg", "-i", input.path,
          "-vn",
          "-acodec", "libmp3lame",
          "-b:a", "128k",   # CBR — eliminates browser VBR timing drift
          "-y",
          output.path,
          err: File::NULL
        )

        unless success
          Rails.logger.error("TranscodeAudioTrackJob: ffmpeg failed for VoiceRecording##{recording.id}")
          return
        end

        recording.audio_track.attach(
          io: File.open(output.path),
          filename: "#{recording.media.filename.base}_cbr.mp3",
          content_type: "audio/mpeg"
        )

        Rails.logger.info("TranscodeAudioTrackJob: attached CBR audio_track for VoiceRecording##{recording.id}")
      end
    end
  end
end

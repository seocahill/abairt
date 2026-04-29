# frozen_string_literal: true

# Downsamples a VoiceRecording's MP3 media to 64kbps mono 16kHz and stores it
# as audio_track. Used by the waveform player and as the upload source for
# Fotheidil/pyannote, keeping file sizes well under the 100MB API limit.
#
#   TranscodeAudioTrackJob.perform_later(voice_recording)
class TranscodeAudioTrackJob < ApplicationJob
  queue_as :default

  def perform(recording)
    return if recording.audio_track.attached?
    return unless recording.media.attached?
    return unless recording.media.content_type == "audio/mpeg"

    recording.media.open do |input|
      Tempfile.create([ "audio_track", ".mp3" ], binmode: true) do |output|
        success = system(
          "ffmpeg", "-i", input.path,
          "-vn",
          "-acodec", "libmp3lame",
          "-b:a", "128k",    # 128bps — sufficient for speech ASR
          "-ac", "1",       # mono
          "-ar", "16000",   # 16kHz — matches abair.ie ASR target rate
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
          filename: "#{recording.media.filename.base}_track.mp3",
          content_type: "audio/mpeg"
        )

        Rails.logger.info("TranscodeAudioTrackJob: attached audio_track for VoiceRecording##{recording.id}")
      end
    end
  end
end

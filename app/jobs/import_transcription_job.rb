class ImportTranscriptionJob < ApplicationJob
  queue_as :default

  def perform(voice_recording, speaker_id)
    # TODO: Implement this
  end
end

class ImportTranscriptionJob < ApplicationJob
  queue_as :long_running

  def perform(voice_recording, speaker_id)
    transcripts = voice_recording.transcription.split("\n")
    translations = voice_recording.transcription_en.split("\n")
    transcripts.each_with_index do |transcript, index|
      voice_recording.dictionary_entries.create!(word_or_phrase: transcript, translation: translations[index], user_id: voice_recording.user_id, quality: :good, speaker_id: speaker_id)
    end
  end
end

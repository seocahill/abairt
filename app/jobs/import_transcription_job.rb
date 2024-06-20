class ImportTranscriptionJob < ApplicationJob
  queue_as :default

  def perform(voice_recording, speaker_id)
    transcripts = voice_recording.transcription.split("\n")
    translations = voice_recording.transcription_en.split("\n")
    current_speaker_id = nil
    transcripts.each_with_index do |transcript, index|
      current_speaker_id, transcript = get_user_from_transcript(current_speaker_id, transcript)
      voice_recording.dictionary_entries.create!(word_or_phrase: transcript, translation: translations[index], user_id: voice_recording.user_id, quality: :good, speaker_id: current_speaker_id)
    end
  end

  def get_user_from_transcript(id, transcript)
    if transcript =~ /^(\d+):\s*(.*)$/
      user_id = $1.to_i
      rest_of_string = $2
      return user_id, rest_of_string
    else
      return id, transcript
    end
  end
end

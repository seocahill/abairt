class ProcessVoiceRecordingEntryJob < ApplicationJob
  queue_as :default

  def perform
    # Find the last dictionary entry that:
    # - has a voice_recording_id
    # - has a transcription (word_or_phrase)
    # - has no translation
    # - is not already processed
    entry = DictionaryEntry
      .where.not(voice_recording_id: nil)
      .where.not(word_or_phrase: [nil, ""])
      .where(translation: [nil, ""])
      .where.not(status: :processed)
      .order(created_at: :desc)
      .first

    return unless entry

    entry.translate
    entry.auto_tag
    # Always mark as processed to avoid duplicate processing
    entry.update!(status: :processed)
  end
end

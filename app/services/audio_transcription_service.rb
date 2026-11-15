class AudioTranscriptionService
  def initialize(dictionary_entry, file_path)
    @dictionary_entry = dictionary_entry
    @file_path = file_path
  end

  def process
    if @dictionary_entry.word_or_phrase.blank?
      irish_text = transcribe_audio
      # no point continuing if no transcription
      return nil unless irish_text.present?
      @dictionary_entry.word_or_phrase = irish_text
    end

    if @dictionary_entry.translation.blank?
      translation_text = TranslationService.new(@dictionary_entry).translate
      @dictionary_entry.translation = translation_text if translation_text.present?
    end

    if @dictionary_entry.changed?
      @dictionary_entry.save!
    end
  rescue => e
    Rails.logger.error("Auto transcription failed: #{e.message}")
    nil
  end

  private

  def transcribe_audio
    text = Asr::AbairClient.transcribe(@file_path)
    AsrHypothesis.record(@dictionary_entry, provider: Asr::AbairClient::PROVIDER, model: Asr::AbairClient::MODEL, text: text)
    text
  end
end

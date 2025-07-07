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
    audio_blob = `ffmpeg -i "#{@file_path}" -f wav -acodec pcm_s16le -ac 1 -ar 16000 - | base64`
    uri = URI.parse('https://phoneticsrv3.lcs.tcd.ie/asr_api/recognise')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30
    http.open_timeout = 30
    request = Net::HTTP::Post.new(uri.path)

    payload = {
      recogniseBlob: audio_blob,
      developer: true,
      method: 'online2bin'
    }

    request.body = payload.to_json
    request['Content-Type'] = 'application/json'

    response = http.request(request)
    Rails.logger.debug(response)
    JSON.parse(response.body).dig("transcriptions", 0, "utterance")
  rescue => e
    Rails.logger.error("Transcription failed: #{e.message}")
    nil
  end
end

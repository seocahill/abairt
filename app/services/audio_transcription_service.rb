class AudioTranscriptionService
  def initialize(dictionary_entry, file_path)
    @dictionary_entry = dictionary_entry
    @file_path = file_path
  end

  def process
    irish_text = transcribe_audio
    return nil unless irish_text.present?

    @dictionary_entry.word_or_phrase = irish_text
    @dictionary_entry.translation = translate_to_english(irish_text)
    @dictionary_entry.save!
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

  def translate_to_english(irish_text)
    client = OpenAI::Client.new(
      access_token: Rails.application.credentials.dig(:openai, :openai_key),
      organization_id: Rails.application.credentials.dig(:openai, :openai_org)
    )

    response = client.chat(parameters: {
      model: 'gpt-4o',
      messages: [
        { role: "system", content: "You are an Irish (Gaeilge) to English translator. Provide only the direct translation, no additional commentary." },
        { role: "user", content: "Translate this Irish text to English: #{irish_text}" }
      ],
      temperature: 0.3,
    })

    response.dig('choices', 0, 'message', 'content')
  rescue => e
    Rails.logger.error("Translation failed: #{e.message}")
    nil
  end
end

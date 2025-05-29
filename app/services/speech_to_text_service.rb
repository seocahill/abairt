class SpeechToTextService
  def initialize(audio_file)
    @audio_file = audio_file
    @temp_path = "/tmp/speech_to_text_#{SecureRandom.hex(8)}.wav"
  end

  def transcribe
    prepare_audio_file
    transcript = transcribe_audio
    return { transcript: nil, translation: nil, language: nil } unless transcript.present?

    # Determine if the transcript is Irish or English
    language_info = detect_language_and_translate(transcript)

    {
      transcript: transcript,
      translation: language_info[:translation],
      language: language_info[:language]
    }
  ensure
    cleanup_temp_files
  end

  private

  def prepare_audio_file
    # Convert uploaded audio to proper format for the ASR API
    command = "ffmpeg -i \"#{@audio_file.path}\" -f wav -acodec pcm_s16le -ac 1 -ar 16000 \"#{@temp_path}\""
    system(command)
  end

  def transcribe_audio
    audio_blob = `cat "#{@temp_path}" | base64`
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

  def detect_language_and_translate(text)
    client = OpenAI::Client.new(
      access_token: Rails.application.credentials.dig(:openai, :openai_key),
      organization_id: Rails.application.credentials.dig(:openai, :openai_org)
    )

    response = client.chat(parameters: {
      model: 'gpt-4o',
      messages: [
        { role: "system", content: "You are a language detector and translator. If the text is in Irish (Gaeilge), respond with a JSON object with keys 'language' set to 'ga', and 'translation' containing the English translation. If the text is in English, respond with a JSON object with keys 'language' set to 'en', and 'translation' set to null." },
        { role: "user", content: "Analyze this text and determine language: #{text}" }
      ],
      response_format: { type: "json_object" },
      temperature: 0.3,
    })

    begin
      result = JSON.parse(response.dig('choices', 0, 'message', 'content'))
      return { language: result['language'], translation: result['translation'] }
    rescue => e
      Rails.logger.error("Language detection failed: #{e.message}")
      # Default to assuming Irish if we can't determine
      return { language: 'ga', translation: nil }
    end
  end

  def cleanup_temp_files
    File.delete(@temp_path) if File.exist?(@temp_path)
  end
end

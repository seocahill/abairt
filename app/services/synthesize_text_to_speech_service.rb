# frozen_string_literal: true

# Uses the Abair API to synthesize text to speech. When a voice_user with a
# cloned voice is supplied, the Abair output is additionally passed through
# ElevenLabs Speech-to-Speech so the audio is rendered in that speaker's
# voice while preserving Abair's Irish-language phonemes/prosody.

class SynthesizeTextToSpeechService
  ABAIR_SAMPLE_RATE = 22_050

  def initialize(entry, voice_user: nil, voice_changer: nil)
    @entry = entry
    @voice_user = voice_user
    @voice_changer = voice_changer
  end

  def process
    decoded_data = fetch_abair_audio

    if cloned_voice_requested?
      decoded_data = apply_voice_changer(decoded_data)
      attach_to_entry(decoded_data, extension: ".mp3", content_type: "audio/mpeg")
    else
      attach_to_entry(decoded_data, extension: ".wav", content_type: "audio/wav")
    end

    Base64.strict_encode64(decoded_data)
  end

  private

  def fetch_abair_audio
    uri = URI.parse("https://api.abair.ie/v3/synthesis")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Post.new(uri.path)
    request.body = {
      synthinput: {text: @entry.word_or_phrase, ssml: "string"},
      voiceparams: {languageCode: "ga-IE", name: "ga_UL_anb_piper", ssmlGender: "UNSPECIFIED"},
      audioconfig: {
        audioEncoding: "LINEAR16",
        speakingRate: 1,
        pitch: 1,
        volumeGainDb: 1,
        htsParams: "string",
        sampleRateHertz: ABAIR_SAMPLE_RATE,
        effectsProfileId: []
      },
      outputType: "JSON"
    }.to_json
    request["Content-Type"] = "application/json"
    response = http.request(request)
    Base64.decode64(JSON.parse(response.body)["audioContent"])
  end

  def cloned_voice_requested?
    @voice_user&.cloned_voice?
  end

  def apply_voice_changer(wav_bytes)
    Tempfile.create(["abair_source", ".wav"], binmode: true) do |source|
      source.write(wav_bytes)
      source.flush
      changer = @voice_changer || VoiceCloning::VoiceChangerService.new(voice_id: @voice_user.cloned_voice_id)
      changer.call(source_path: source.path)
    end
  end

  def attach_to_entry(bytes, extension:, content_type:)
    return unless @entry.persisted?

    Tempfile.create(["temp_audio", extension], binmode: true) do |temp_file|
      temp_file.write(bytes)
      temp_file.rewind
      @entry.media.attach(io: temp_file, filename: "chat#{extension}", content_type: content_type)
    end
  end
end

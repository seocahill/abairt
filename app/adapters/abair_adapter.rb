# frozen_string_literal: true

# Unified adapter for Abair.ie services
# Provides Text-to-Speech (TTS) and Automatic Speech Recognition (ASR)
# for the Irish language with dialect support
class AbairAdapter
  TTS_ENDPOINT = "https://api.abair.ie/v3/synthesis"
  ASR_ENDPOINT = "https://phoneticsrv3.lcs.tcd.ie/asr_api/recognise"

  # Available TTS voices by dialect
  # Ulster (ga_UL) is default - best quality and similar to Mayo/North Connacht
  VOICES = {
    ulster: {
      female: "ga_UL_anb_piper",
      male: "ga_UL_piper"
    },
    connacht: {
      female: "ga_CO_snc_piper",
      male: "ga_CO_piper"
    },
    munster: {
      female: "ga_MU_nnc_piper",
      male: "ga_MU_piper"
    }
  }.freeze

  DEFAULT_DIALECT = :ulster
  DEFAULT_GENDER = :female

  class Error < StandardError; end
  class RateLimitError < Error; end
  class ServiceUnavailableError < Error; end

  def initialize(dialect: DEFAULT_DIALECT, gender: DEFAULT_GENDER)
    @dialect = dialect.to_sym
    @gender = gender.to_sym
    validate_options!
  end

  # Text-to-Speech: Convert Irish text to audio
  # Returns base64-encoded WAV audio
  def synthesize(text)
    raise ArgumentError, "Text cannot be blank" if text.blank?

    response = tts_request(text)
    handle_response(response, "TTS")

    JSON.parse(response.body)["audioContent"]
  end

  # Text-to-Speech: Convert and save to file
  # Returns the file path
  def synthesize_to_file(text, output_path: nil)
    audio_content = synthesize(text)
    decoded = Base64.decode64(audio_content)

    output_path ||= generate_temp_path("tts", ".wav")
    File.binwrite(output_path, decoded)
    output_path
  end

  # Automatic Speech Recognition: Convert audio to Irish text
  # Accepts file path or raw audio data
  def transcribe(audio_input)
    audio_blob = prepare_audio(audio_input)
    response = asr_request(audio_blob)
    handle_response(response, "ASR")

    JSON.parse(response.body).dig("transcriptions", 0, "utterance")
  end

  # Get the current voice name
  def voice_name
    VOICES.dig(@dialect, @gender) || VOICES[:ulster][:female]
  end

  # List available voices
  def self.available_voices
    VOICES
  end

  private

  def validate_options!
    unless VOICES.key?(@dialect)
      raise ArgumentError, "Invalid dialect: #{@dialect}. Valid options: #{VOICES.keys.join(", ")}"
    end

    unless VOICES[@dialect].key?(@gender)
      raise ArgumentError, "Invalid gender: #{@gender}. Valid options: female, male"
    end
  end

  def tts_request(text)
    uri = URI.parse(TTS_ENDPOINT)
    http = build_http_client(uri)

    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/json"
    request.body = tts_payload(text).to_json

    http.request(request)
  end

  def tts_payload(text)
    {
      synthinput: { text: text, ssml: "string" },
      voiceparams: {
        languageCode: "ga-IE",
        name: voice_name,
        ssmlGender: "UNSPECIFIED"
      },
      audioconfig: {
        audioEncoding: "LINEAR16",
        speakingRate: 1,
        pitch: 1,
        volumeGainDb: 1,
        htsParams: "string",
        sampleRateHertz: 0,
        effectsProfileId: []
      },
      outputType: "JSON"
    }
  end

  def asr_request(audio_blob)
    uri = URI.parse(ASR_ENDPOINT)
    http = build_http_client(uri)
    http.read_timeout = 30
    http.open_timeout = 30

    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/json"
    request.body = {
      recogniseBlob: audio_blob,
      developer: true,
      method: "online2bin"
    }.to_json

    http.request(request)
  end

  def prepare_audio(audio_input)
    if audio_input.is_a?(String) && File.exist?(audio_input)
      # Convert file to required format and base64 encode
      `ffmpeg -i "#{audio_input}" -f wav -acodec pcm_s16le -ac 1 -ar 16000 - 2>/dev/null | base64`.strip
    elsif audio_input.is_a?(String)
      # Assume already base64 encoded
      audio_input
    else
      raise ArgumentError, "Invalid audio input: expected file path or base64 string"
    end
  end

  def build_http_client(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    # Note: SSL verification disabled for abair.ie compatibility
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http
  end

  def handle_response(response, service_name)
    case response.code
    when "200"
      Rails.logger.info("#{service_name} request successful")
    when "429"
      raise RateLimitError, "#{service_name} rate limited - try again later"
    when "503"
      raise ServiceUnavailableError, "#{service_name} service unavailable"
    else
      raise Error, "#{service_name} request failed with status #{response.code}: #{response.body}"
    end
  end

  def generate_temp_path(prefix, extension)
    File.join(Dir.tmpdir, "#{prefix}_#{SecureRandom.hex(8)}#{extension}")
  end
end

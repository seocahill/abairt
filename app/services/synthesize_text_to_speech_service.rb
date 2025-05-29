# frozen_string_literal: true
# Uses the Abair API to synthesize text to speech

class SynthesizeTextToSpeechService
  def initialize(entry)
    @entry = entry
  end

  def process
    uri = URI.parse('https://api.abair.ie/v3/synthesis')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    # Disable SSL verification for this specific request
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Post.new(uri.path)
    request.body = {
      synthinput: { text: @entry.word_or_phrase, ssml: 'string' },
      voiceparams: { languageCode: 'ga-IE', name: 'ga_UL_anb_piper', ssmlGender: 'UNSPECIFIED' },
      audioconfig: {
        audioEncoding: 'LINEAR16',
        speakingRate: 1,
        pitch: 1,
        volumeGainDb: 1,
        htsParams: 'string',
        sampleRateHertz: 0,
        effectsProfileId: []
      },
      outputType: 'JSON'
    }.to_json
    request['Content-Type'] = 'application/json'
    response = http.request(request)
    api_response = JSON.parse(response.body)
    decoded_data = Base64.decode64(api_response['audioContent'])

    if @entry.persisted?
      # Create a temporary file and attach to ActiveStorage within its block
      Tempfile.create(['temp_audio', '.wav']) do |temp_file|
        temp_file.binmode
        temp_file.write(decoded_data)
        temp_file.rewind
        @entry.media.attach(io: temp_file, filename: 'chat.wav', content_type: 'audio/wav')
      end
    end

    api_response['audioContent']
  end
end

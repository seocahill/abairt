# frozen_string_literal: true

class ServiceMonitoringService
  def initialize
    @tts_url = 'https://api.abair.ie/v3/synthesis'
    @asr_url = 'https://phoneticsrv3.lcs.tcd.ie/asr_api/recognise'
    @pyannote_url = 'https://api.pyannote.ai/v1/test'
  end

  def monitor_all_services
    {
      tts: monitor_tts_service,
      asr: monitor_asr_service,
      pyannote: monitor_pyannote_service
    }
  end

  def monitor_tts_service
    start_time = Time.current
    
    begin
      # Create a minimal TTS request with a simple Irish word
      uri = URI.parse(@tts_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.read_timeout = 30
      http.open_timeout = 10
      
      request = Net::HTTP::Post.new(uri.path)
      request.body = {
        synthinput: { text: 'dia', ssml: 'string' },
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
      response_time = (Time.current - start_time) * 1000 # Convert to milliseconds
      
      if response.code.to_i.between?(200, 299)
        ServiceStatus.create!(
          service_name: 'tts',
          status: 'up',
          response_time: response_time
        )
        { status: 'up', response_time: response_time, error: nil }
      else
        ServiceStatus.create!(
          service_name: 'tts',
          status: 'down',
          response_time: response_time,
          error_message: "HTTP #{response.code}: #{response.body}"
        )
        { status: 'down', response_time: response_time, error: "HTTP #{response.code}" }
      end
    rescue => e
      response_time = (Time.current - start_time) * 1000
      ServiceStatus.create!(
        service_name: 'tts',
        status: 'down',
        response_time: response_time,
        error_message: e.message
      )
      { status: 'down', response_time: response_time, error: e.message }
    end
  end

  def monitor_asr_service
    start_time = Time.current
    
    begin
      # Create a minimal ASR request with a small audio blob
      # We'll use a very short base64-encoded audio sample
      file_path = DictionaryEntry.with_attached_media.last.media.url
      audio_blob = `ffmpeg -i "#{file_path}" -f wav -acodec pcm_s16le -ac 1 -ar 16000 - | base64`
      
      uri = URI.parse(@asr_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30
      http.open_timeout = 10
      
      request = Net::HTTP::Post.new(uri.path)
      request.body = {
        recogniseBlob: audio_blob,
        developer: true,
        method: 'online2bin'
      }.to_json
      request['Content-Type'] = 'application/json'
      
      response = http.request(request)
      response_time = (Time.current - start_time) * 1000 # Convert to milliseconds
      
      if response.code.to_i.between?(200, 299)
        ServiceStatus.create!(
          service_name: 'asr',
          status: 'up',
          response_time: response_time
        )
        { status: 'up', response_time: response_time, error: nil }
      else
        ServiceStatus.create!(
          service_name: 'asr',
          status: 'down',
          response_time: response_time,
          error_message: "HTTP #{response.code}: #{response.body}"
        )
        { status: 'down', response_time: response_time, error: "HTTP #{response.code}" }
      end
    rescue => e
      response_time = (Time.current - start_time) * 1000
      ServiceStatus.create!(
        service_name: 'asr',
        status: 'down',
        response_time: response_time,
        error_message: e.message
      )
      { status: 'down', response_time: response_time, error: e.message }
    end
  end

  def monitor_pyannote_service
    start_time = Time.current
    
    begin
      # Get API key from credentials (same as diarization service)
      api_key = Rails.env.test? ? "test_key" : Rails.application.credentials.dig(:pyannote, :api_key)
      
      return { status: 'down', response_time: 0, error: 'No API key configured' } unless api_key.present?
      
      uri = URI.parse(@pyannote_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30
      http.open_timeout = 10
      
      request = Net::HTTP::Get.new(uri.path)
      request['Authorization'] = "Bearer #{api_key}"
      request['Content-Type'] = 'application/json'
      
      response = http.request(request)
      response_time = (Time.current - start_time) * 1000 # Convert to milliseconds
      
      if response.code.to_i.between?(200, 299)
        ServiceStatus.create!(
          service_name: 'pyannote',
          status: 'up',
          response_time: response_time
        )
        { status: 'up', response_time: response_time, error: nil }
      else
        ServiceStatus.create!(
          service_name: 'pyannote',
          status: 'down',
          response_time: response_time,
          error_message: "HTTP #{response.code}: #{response.body}"
        )
        { status: 'down', response_time: response_time, error: "HTTP #{response.code}" }
      end
    rescue => e
      response_time = (Time.current - start_time) * 1000
      ServiceStatus.create!(
        service_name: 'pyannote',
        status: 'down',
        response_time: response_time,
        error_message: e.message
      )
      { status: 'down', response_time: response_time, error: e.message }
    end
  end
end 
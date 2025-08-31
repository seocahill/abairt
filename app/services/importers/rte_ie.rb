require 'uri'

module Importers
  class RteIe
    def self.import(url, title: nil)
      new(url).import(title: title)
    end
    
    def self.import_to_record(voice_recording, url, title: nil)
      new(url).import_to_record(voice_recording, title: title)
    end

    def initialize(url)
      @url = url
    end

    def import(title: nil)
      response = fetch_with_retry(@url)
      return nil unless response && response.success?

      doc = Nokogiri::HTML(response.body)
      extracted_title, description, audio_url = extract_audio_info(doc)
      
      return nil unless audio_url

      # Use custom title if provided, otherwise use extracted title
      final_title = title.present? ? title : extracted_title

      voice_recording = VoiceRecording.create!(
        title: final_title,
        owner: User.first
      )

      download_and_attach_audio(voice_recording, audio_url)

      Rails.logger.info "Voice recording '#{voice_recording.title}' imported successfully with ID: #{voice_recording.id}"
      voice_recording
    end
    
    def import_to_record(voice_recording, title: nil)
      response = fetch_with_retry(@url)
      return false unless response && response.success?

      doc = Nokogiri::HTML(response.body)
      extracted_title, description, audio_url = extract_audio_info(doc)
      
      return false unless audio_url

      # Use custom title if provided, otherwise use extracted title
      final_title = title.present? ? title : extracted_title

      # Update the existing record
      voice_recording.update!(title: final_title)
      download_and_attach_audio(voice_recording, audio_url)

      Rails.logger.info "Voice recording '#{voice_recording.title}' imported successfully with ID: #{voice_recording.id}"
      true
    end

    private

    def extract_audio_info(doc)
      # Extract the clips data from JavaScript
      script_content = doc.css('script').map(&:inner_text).join(' ')
      
      # Look for the clips array in the JavaScript
      clips_match = script_content.match(/clips\s*=\s*(\[.*?\]);/m)
      return [nil, nil, nil] unless clips_match

      begin
        clips_data = JSON.parse(clips_match[1])
        
        # Find the specific clip that matches our URL's clip ID
        clip_id = extract_clip_id_from_url(@url)
        target_clip = clips_data.find { |clip| clip['clip_id'] == clip_id }
        
        # Fall back to first clip if we can't find the specific one
        target_clip ||= clips_data.first
        return [nil, nil, nil] unless target_clip

        # Use the clip's specific title and check for podcast_url first
        title = "RTÉ Raidió na Gaeltachta - #{target_clip['title'] || 'Unknown'}"
        description = "#{target_clip['description'] || 'Original source: ' + @url}"
        
        # Try multiple approaches to get audio URL
        audio_url = if target_clip['podcast_url']&.present?
                      # Direct podcast URL is available
                      target_clip['podcast_url']
                    else
                      # Try to get streaming URL from RTÉ API
                      Rails.logger.info "No direct podcast URL found, trying RTÉ API..."
                      api_url = get_streaming_url_from_api(clip_id)
                      
                      if api_url
                        api_url
                      elsif target_clip['url_stem']
                        # Fall back to HLS URL construction
                        construct_hls_url(target_clip['url_stem'])
                      else
                        nil
                      end
                    end

        # Check if this is a full episode without podcast_url
        is_full_episode = !target_clip['ispodcast'] && target_clip['isshow']
        
        if audio_url
          source_type = if target_clip['podcast_url']
                          'direct podcast URL'
                        elsif api_url
                          'RTÉ streaming API'
                        else
                          'constructed HLS stream'
                        end
          Rails.logger.info "Found clip: #{title} (#{target_clip['duration_time']}) - using #{source_type}"
        else
          Rails.logger.warn "No audio URL found for clip: #{title}"
        end
        
        [title, description, audio_url]
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse clips JSON: #{e.message}"
        [nil, nil, nil]
      end
    end

    def get_streaming_url_from_api(clip_id)
      api_url = "https://www.rte.ie/rteavgen/getplaylist/?format=json&id=#{clip_id}"
      
      begin
        response = fetch_with_retry(api_url)
        return nil unless response && response.success?
        
        data = JSON.parse(response.body)
        show = data['shows']&.first
        return nil unless show
        
        media_group = show['media:group']&.first
        return nil unless media_group
        
        # Prefer HLS streaming URL
        if media_group['hls_server'] && media_group['hls_url']
          hls_url = "#{media_group['hls_server']}#{media_group['hls_url']}"
          Rails.logger.info "Found HLS streaming URL: #{hls_url}"
          return hls_url
        end
        
        # Fall back to direct RTMP URL if available
        if media_group['url']
          Rails.logger.info "Found RTMP URL: #{media_group['url']}"
          return media_group['url']
        end
        
        nil
      rescue JSON::ParserError, StandardError => e
        Rails.logger.error "Failed to get streaming URL from API: #{e.message}"
        nil
      end
    end

    def construct_hls_url(url_stem)
      # Construct HLS manifest URL from url_stem
      # Pattern: https://cdn.rasset.ie/hls-vod{url_stem}/manifest.m3u8
      clean_stem = url_stem.sub(/^\//, '')
      "https://cdn.rasset.ie/hls-vod/#{clean_stem}/manifest.m3u8"
    end

    def download_and_attach_audio(voice_recording, audio_url)
      # Create a temporary file to store the downloaded audio
      temp_file = Tempfile.new(['rte_audio', '.mp3'])
      
      begin
        # Add a small delay to avoid rapid requests
        sleep(rand(0.5..2.0))
        
        # Build ffmpeg command with random user agent
        cmd = [
          'ffmpeg',
          '-user_agent', get_random_headers['User-Agent'],
          '-referer', 'https://www.rte.ie/',
          '-headers', 'Accept-Language: en-US,en;q=0.9,ga;q=0.8',
          '-i', audio_url,
          '-c:a', 'mp3',           # Ensure MP3 format
          '-b:a', '128k',          # Set bitrate for consistency
          '-y',                    # Overwrite output file
          temp_file.path
        ]
        
        system(*cmd)

        # Check if the download was successful
        if File.size(temp_file.path) > 0
          voice_recording.media.attach(
            io: File.open(temp_file.path),
            filename: "rte_#{extract_clip_id_from_url(@url)}.mp3",
            content_type: 'audio/mpeg'
          )
        else
          Rails.logger.error "Failed to download audio from #{audio_url}"
        end
      rescue => e
        Rails.logger.error "Error downloading audio: #{e.message}"
      ensure
        temp_file.close
        temp_file.unlink
      end
    end

    def extract_clip_id_from_url(url)
      # Extract the numeric ID from URLs like https://www.rte.ie/radio/rnag/clips/22540164/
      match = url.match(/clips\/(\d+)/)
      match ? match[1] : SecureRandom.hex(8)
    end

    def fetch_with_retry(url, max_retries: 3)
      retries = 0
      
      begin
        # Random delay to avoid being detected as a bot
        sleep(rand(1.0..3.0))
        
        headers = get_random_headers
        
        Rails.logger.debug "Fetching #{url} with headers: #{headers}"
        
        # Add proxy support if configured
        options = {
          headers: headers,
          timeout: 30,
          follow_redirects: true,
          verify: false  # In case of SSL issues on server
        }
        
        # Add proxy if PROXY_URL environment variable is set
        if ENV['PROXY_URL'].present?
          proxy_uri = URI.parse(ENV['PROXY_URL'])
          options[:http_proxyaddr] = proxy_uri.host
          options[:http_proxyport] = proxy_uri.port
          options[:http_proxyuser] = proxy_uri.user if proxy_uri.user
          options[:http_proxypass] = proxy_uri.password if proxy_uri.password
          Rails.logger.debug "Using proxy: #{proxy_uri.host}:#{proxy_uri.port}"
        end
        
        response = HTTParty.get(url, options)
        
        if response.success?
          return response
        elsif response.code == 429 || response.code == 503  # Rate limited or service unavailable
          raise "Rate limited or service unavailable"
        else
          Rails.logger.warn "HTTP request failed with code #{response.code} for #{url}"
          return nil
        end
        
      rescue => e
        retries += 1
        Rails.logger.warn "Fetch attempt #{retries} failed: #{e.message}"
        
        if retries < max_retries
          # Exponential backoff with jitter
          delay = (2 ** retries) + rand(1.0..5.0)
          Rails.logger.info "Retrying in #{delay.round(2)} seconds..."
          sleep(delay)
          retry
        else
          Rails.logger.error "Failed to fetch #{url} after #{max_retries} retries"
          return nil
        end
      end
    end

    def get_random_headers
      user_agents = [
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15',
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
      ]
      
      {
        'User-Agent' => user_agents.sample,
        'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
        'Accept-Language' => 'en-US,en;q=0.9,ga;q=0.8',
        'Accept-Encoding' => 'gzip, deflate, br',
        'DNT' => '1',
        'Connection' => 'keep-alive',
        'Upgrade-Insecure-Requests' => '1',
        'Sec-Fetch-Dest' => 'document',
        'Sec-Fetch-Mode' => 'navigate',
        'Sec-Fetch-Site' => 'none',
        'Sec-Fetch-User' => '?1',
        'Cache-Control' => 'max-age=0',
        'Referer' => 'https://www.google.com/'
      }
    end
  end
end
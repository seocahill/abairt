require 'json'

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
      response = HTTParty.get(@url)
      return nil unless response.success?

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
      response = HTTParty.get(@url)
      return false unless response.success?

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
        
        # Prefer direct podcast_url if available, otherwise construct HLS URL
        audio_url = if target_clip['podcast_url']&.present?
                      target_clip['podcast_url']
                    elsif target_clip['url_stem']
                      construct_hls_url(target_clip['url_stem'])
                    else
                      nil
                    end

        Rails.logger.info "Found clip: #{title} (#{target_clip['duration_time']}) - using #{audio_url ? 'podcast URL' : 'HLS stream'}"
        [title, description, audio_url]
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse clips JSON: #{e.message}"
        [nil, nil, nil]
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
        # Build ffmpeg command
        cmd = [
          'ffmpeg',
          '-user_agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          '-referer', 'https://www.rte.ie/',
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
  end
end
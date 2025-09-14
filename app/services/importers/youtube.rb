# All required libraries are auto-loaded by Rails
require 'open3'

module Importers
  class Youtube
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
      Rails.logger.info "[YT-IMPORT] Starting import process for URL: #{@url}"

      unless valid_youtube_url?
        Rails.logger.error "[YT-IMPORT] Invalid YouTube URL: #{@url}"
        return nil
      end

      Rails.logger.info "[YT-IMPORT] URL validation passed"
      Rails.logger.info "[YT-IMPORT] Environment: #{Rails.env}"
      Rails.logger.info "[YT-IMPORT] yt-dlp available: #{yt_dlp_available?}"

      video_info = extract_video_info
      unless video_info
        Rails.logger.error "[YT-IMPORT] Failed to extract video info, aborting import"
        return nil
      end

      Rails.logger.info "[YT-IMPORT] Video info extracted successfully"
      Rails.logger.info "[YT-IMPORT] Video title: #{video_info[:title]}"
      Rails.logger.info "[YT-IMPORT] Video duration: #{video_info[:duration]} seconds"

      final_title = title.presence || video_info[:title]
      Rails.logger.info "[YT-IMPORT] Final title: #{final_title}"

      Rails.logger.info "[YT-IMPORT] Creating voice recording..."
      voice_recording = create_voice_recording(final_title, video_info)
      Rails.logger.info "[YT-IMPORT] Voice recording created with ID: #{voice_recording.id}"

      Rails.logger.info "[YT-IMPORT] Starting download and attach process..."
      if download_and_attach_audio(voice_recording)
        Rails.logger.info "[YT-IMPORT] Import completed successfully!"
        return voice_recording
      end

      Rails.logger.error "[YT-IMPORT] Download failed, destroying voice recording"
      voice_recording.destroy
      nil
    rescue StandardError => e
      Rails.logger.error "[YT-IMPORT] Import failed with exception: #{e.message}"
      Rails.logger.error "[YT-IMPORT] Exception backtrace: #{e.backtrace.first(10).join(', ')}"
      voice_recording&.destroy
      nil
    end
    
    def import_to_record(voice_recording, title: nil)
      return false unless valid_youtube_url?
      
      Rails.logger.info "Importing YouTube audio to existing recording: #{@url}"
      
      video_info = extract_video_info
      return false unless video_info
      
      final_title = title.presence || video_info[:title]
      update_voice_recording(voice_recording, final_title, video_info)
      
      download_and_attach_audio(voice_recording).tap do |success|
        if success
          Rails.logger.info "Voice recording '#{voice_recording.title}' updated successfully"
        else
          Rails.logger.error "Failed to download audio for YouTube video: #{@url}"
        end
      end
    rescue StandardError => e
      Rails.logger.error "Failed to import to existing recording: #{e.message}"
      false
    end

    private

    def create_voice_recording(title, video_info)
      VoiceRecording.create!(
        title: title,
        description: video_info[:description],
        owner: User.first
      )
    end

    def update_voice_recording(voice_recording, title, video_info)
      voice_recording.update!(
        title: title,
        description: video_info[:description]
      )
    end

    def build_info_command
      cmd = [
        'yt-dlp',
        '--dump-json',
        '--no-download',
        '--user-agent', get_random_user_agent,
        '--referer', 'https://www.google.com/',
        '--sleep-interval', '1',
        '--max-sleep-interval', '3',
        '--socket-timeout', '30',
        '--retries', '5',
        '--fragment-retries', '5'
      ]

      if production_proxy_available?
        cmd += ['--proxy', proxy_url]
        cmd += ['--no-check-certificates']  # Skip SSL verification through proxy
      end

      cmd << @url
      cmd
    end

    def build_download_command(output_template)
      cmd = [
        'yt-dlp',
        '--format', 'best[ext=mp4]/best',
        '--output', output_template,
        '--no-playlist',
        '--user-agent', get_random_user_agent,
        '--referer', 'https://www.google.com/',
        '--sleep-interval', '1',
        '--max-sleep-interval', '3',
        '--socket-timeout', '30',
        '--retries', '5',
        '--fragment-retries', '5',
        '--abort-on-unavailable-fragment'
      ]

      if production_proxy_available?
        cmd += ['--proxy', proxy_url]
        cmd += ['--no-check-certificates']  # Skip SSL verification through proxy
      end

      cmd << @url
      cmd
    end

    def parse_video_info(result)
      data = JSON.parse(result)
      
      {
        title: "YouTube - #{data['title'] || 'Unknown'}",
        description: truncate_description(data['description']),
        duration: data['duration'],
        uploader: data['uploader'],
        upload_date: data['upload_date']
      }
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse yt-dlp JSON output: #{e.message}"
      nil
    end

    def download_successful?(success, file_path)
      success && File.exist?(file_path) && File.size(file_path) > 0
    end

    def attach_media_file(voice_recording, file_path)
      voice_recording.media.attach(
        io: File.open(file_path),
        filename: "youtube_#{extract_video_id}.mp4",
        content_type: 'video/mp4'
      )
      
      Rails.logger.info "Successfully downloaded and attached YouTube video"
      true
    end

    def cleanup_temp_directory(temp_dir)
      return unless temp_dir && Dir.exist?(temp_dir)
      
      FileUtils.remove_entry_secure(temp_dir)
    rescue StandardError => e
      Rails.logger.debug "Error cleaning up temp files: #{e.message}"
    end

    def production_proxy_available?
      Rails.env.production? && Rails.application.credentials.proxy_host.present?
    end

    def proxy_url
      return unless production_proxy_available?

      user = CGI.escape(Rails.application.credentials.proxy_user)
      pass = CGI.escape(Rails.application.credentials.proxy_pass)
      host = Rails.application.credentials.proxy_host
      port = Rails.application.credentials.proxy_port || 10001

      "http://#{user}:#{pass}@#{host}:#{port}"
    end

    def valid_youtube_url?
      # Check if URL is a valid YouTube URL
      youtube_regex = /(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})/
      @url.match?(youtube_regex)
    end

    def extract_video_info
      return unless yt_dlp_available?

      cmd = build_info_command
      Rails.logger.info "[YT-IMPORT] Building info command for URL: #{@url}"
      Rails.logger.info "[YT-IMPORT] Command: #{cmd.join(' ')}"
      Rails.logger.info "[YT-IMPORT] Using proxy: #{production_proxy_available?}"
      Rails.logger.info "[YT-IMPORT] Proxy URL: #{proxy_url}" if production_proxy_available?

      Rails.logger.info "[YT-IMPORT] Executing yt-dlp info command..."
      result, stderr, status = Open3.capture3(*cmd)

      Rails.logger.info "[YT-IMPORT] Command completed with exit status: #{status.exitstatus}"
      Rails.logger.info "[YT-IMPORT] Result size: #{result.length} characters" if result
      Rails.logger.info "[YT-IMPORT] Stderr size: #{stderr.length} characters" if stderr.present?

      if status.success? && result.present?
        Rails.logger.info "[YT-IMPORT] Successfully extracted video info, parsing JSON..."
        return parse_video_info(result)
      end

      Rails.logger.error "[YT-IMPORT] yt-dlp failed to extract video info for: #{@url}"
      Rails.logger.error "[YT-IMPORT] Exit status: #{status.exitstatus}"
      Rails.logger.error "[YT-IMPORT] yt-dlp stderr: #{stderr}" if stderr.present?
      nil
    rescue StandardError => e
      Rails.logger.error "[YT-IMPORT] Error extracting video info: #{e.message}"
      Rails.logger.error "[YT-IMPORT] Backtrace: #{e.backtrace.first(5).join(', ')}"
      nil
    end

    def download_and_attach_audio(voice_recording)
      return false unless yt_dlp_available?

      temp_dir = Dir.mktmpdir
      output_template = File.join(temp_dir, "audio.%(ext)s")

      cmd = build_download_command(output_template)
      Rails.logger.info "[YT-IMPORT] Building download command for URL: #{@url}"
      Rails.logger.info "[YT-IMPORT] Download command: #{cmd.join(' ')}"
      Rails.logger.info "[YT-IMPORT] Temp directory: #{temp_dir}"
      Rails.logger.info "[YT-IMPORT] Output template: #{output_template}"

      Rails.logger.info "[YT-IMPORT] Executing yt-dlp download command..."
      success = system(*cmd)
      actual_file_path = File.join(temp_dir, "audio.mp4")

      Rails.logger.info "[YT-IMPORT] Download command completed with success: #{success}"
      Rails.logger.info "[YT-IMPORT] Expected file path: #{actual_file_path}"
      Rails.logger.info "[YT-IMPORT] File exists: #{File.exist?(actual_file_path)}"
      Rails.logger.info "[YT-IMPORT] File size: #{File.exist?(actual_file_path) ? File.size(actual_file_path) : 'N/A'} bytes"

      if download_successful?(success, actual_file_path)
        Rails.logger.info "[YT-IMPORT] Download successful, attaching media file..."
        return attach_media_file(voice_recording, actual_file_path)
      end

      Rails.logger.error "[YT-IMPORT] Failed to download video from YouTube: #{@url}"
      Rails.logger.error "[YT-IMPORT] System command success: #{success}"
      Rails.logger.error "[YT-IMPORT] File exists check: #{File.exist?(actual_file_path)}"
      false
    rescue StandardError => e
      Rails.logger.error "[YT-IMPORT] Error downloading YouTube video: #{e.message}"
      Rails.logger.error "[YT-IMPORT] Backtrace: #{e.backtrace.first(5).join(', ')}"
      false
    ensure
      Rails.logger.info "[YT-IMPORT] Cleaning up temp directory: #{temp_dir}"
      cleanup_temp_directory(temp_dir)
    end

    def extract_video_id
      # Extract YouTube video ID from URL
      youtube_regex = /(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})/
      match = @url.match(youtube_regex)
      match ? match[1] : SecureRandom.hex(8)
    end

    def truncate_description(description)
      return "Imported from YouTube: #{@url}" if description.blank?
      
      # Limit description length and add source
      truncated = description.length > 500 ? "#{description[0..497]}..." : description
      "#{truncated}\n\nOriginal source: #{@url}"
    end

    def yt_dlp_available?
      @yt_dlp_available ||= system('which yt-dlp > /dev/null 2>&1')
      
      unless @yt_dlp_available
        Rails.logger.error "yt-dlp is not installed. Please install it with: pip install yt-dlp"
      end
      
      @yt_dlp_available
    end

    def get_random_user_agent
      user_agents = [
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15',
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
      ]
      
      user_agents.sample
    end
  end
end
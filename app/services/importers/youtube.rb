require 'json'
require 'tempfile'

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
      return nil unless valid_youtube_url?
      
      Rails.logger.info "Importing YouTube video: #{@url}"
      
      # Extract video info first
      video_info = extract_video_info
      return nil unless video_info
      
      # Use custom title if provided, otherwise use video title
      final_title = title.present? ? title : video_info[:title]

      voice_recording = VoiceRecording.create!(
        title: final_title,
        description: video_info[:description],
        owner: User.first
      )

      # Download and attach audio
      if download_and_attach_audio(voice_recording)
        Rails.logger.info "Voice recording '#{voice_recording.title}' imported successfully with ID: #{voice_recording.id}"
        voice_recording
      else
        voice_recording.destroy
        nil
      end
    end
    
    def import_to_record(voice_recording, title: nil)
      return false unless valid_youtube_url?
      
      Rails.logger.info "Importing YouTube audio to existing recording: #{@url}"
      
      # Extract video info
      video_info = extract_video_info
      return false unless video_info
      
      # Use custom title if provided, otherwise use video title
      final_title = title.present? ? title : video_info[:title]

      # Update the existing record
      voice_recording.update!(
        title: final_title,
        description: video_info[:description]
      )
      
      success = download_and_attach_audio(voice_recording)
      
      if success
        Rails.logger.info "Voice recording '#{voice_recording.title}' updated successfully"
        true
      else
        Rails.logger.error "Failed to download audio for YouTube video: #{@url}"
        false
      end
    end

    private

    def valid_youtube_url?
      # Check if URL is a valid YouTube URL
      youtube_regex = /(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})/
      @url.match?(youtube_regex)
    end

    def extract_video_info
      return nil unless yt_dlp_available?
      
      # Use yt-dlp to get video metadata
      cmd = [
        'yt-dlp',
        '--dump-json',
        '--no-download',
        @url
      ]
      
      Rails.logger.debug "Running: #{cmd.join(' ')}"
      
      result = `#{cmd.join(' ')} 2>/dev/null`
      
      if $?.success? && result.present?
        begin
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
      else
        Rails.logger.error "yt-dlp failed to extract video info for: #{@url}"
        nil
      end
    end

    def download_and_attach_audio(voice_recording)
      return false unless yt_dlp_available?
      
      # Create a unique temporary directory
      temp_dir = Dir.mktmpdir
      output_template = File.join(temp_dir, "audio.%(ext)s")
      
      begin
        # Use yt-dlp to download video in MP4 format
        cmd = [
          'yt-dlp',
          '--format', 'best[ext=mp4]/best',
          '--output', output_template,
          '--no-playlist',
          '--user-agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          @url
        ]
        
        Rails.logger.debug "Running: #{cmd.join(' ')}"
        success = system(*cmd)

        # The final file should be audio.mp4
        actual_file_path = File.join(temp_dir, "audio.mp4")
        
        if success && File.exist?(actual_file_path) && File.size(actual_file_path) > 0
          voice_recording.media.attach(
            io: File.open(actual_file_path),
            filename: "youtube_#{extract_video_id}.mp4",
            content_type: 'video/mp4'
          )
          
          Rails.logger.info "Successfully downloaded and attached YouTube video"
          true
        else
          Rails.logger.error "Failed to download video from YouTube: #{@url}"
          false
        end
      rescue => e
        Rails.logger.error "Error downloading YouTube video: #{e.message}"
        false
      ensure
        # Clean up temp directory and all files
        begin
          FileUtils.remove_entry_secure(temp_dir) if temp_dir && Dir.exist?(temp_dir)
        rescue => cleanup_error
          Rails.logger.debug "Error cleaning up temp files: #{cleanup_error.message}"
        end
      end
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
  end
end
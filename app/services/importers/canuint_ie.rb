
require 'open-uri'

module Importers
  class CanuintIe
    def self.import(url)
      new(url).import
    end

    def initialize(url)
      @url = url
    end

    def import
      # Fetch HTML from URL
      html = URI.open(@url).read
      doc = Nokogiri::HTML(html)

      # Extract title from header
      title = "Taisce Chanúintí na Gaeilge #{@url.split('/').last}"
      description = "Original Transcript: #{@url}"

      # Extract media URL
      audio_element = doc.at_css('audio')
      media_url = audio_element ? audio_element['src'] : nil

      # Ensure media URL has domain if it's relative
      if media_url && !media_url.start_with?('http')
        media_url = "https://www.canuint.ie#{media_url.start_with?('/') ? '' : '/'}#{media_url}"
      end

      # Create voice recording
      voice_recording = VoiceRecording.create!(
        title: title,
        owner: User.first
      )

      # Attach media if URL exists
      if media_url
        temp_file = URI.open(media_url)
        # Attach the file to the voice recording
        voice_recording.media.attach(
          io: temp_file,
          filename: File.basename(media_url),
          content_type: 'audio/mpeg'
        )
      end

      # Process transcript data
      para_elements = doc.css('.transcript .para')

      # Track speakers and their segments
      speaker_segments = {}

      para_elements.each do |para_element|
        # Extract speaker info
        speaker_element = para_element.at_css('.speaker')
        next unless speaker_element

        speaker_name = speaker_element.at_css('.icon.fas.fa-user-circle').parent.text.strip.gsub(/\s+/, ' ')
        hometown = para_element.at_css('.hometown')&.text&.strip

        # Initialize speaker if not already tracked
        speaker_segments[speaker_name] ||= {
          segments: [],
          hometown: hometown
        }

        # Extract segments
        segment_elements = para_element.css('.segment')

        segment_elements.each do |segment_element|
          start_time = segment_element['data-start'].to_f
          end_time = segment_element['data-end'].to_f
          text = segment_element.at_css('.text')&.text

          # Get standardized text if available
          stext_element = segment_element.at_css('.stext span a')
          standardized_text = stext_element&.text

          speaker_segments[speaker_name][:segments] << {
            start: start_time,
            end: end_time,
            text: text,
            standardized_text: standardized_text
          }
        end
      end

      # Create dictionary entries for each speaker
      speaker_segments.each do |speaker_name, data|
        # Skip if no segments
        next if data[:segments].empty?

        # Create temporary user for the speaker
        temp_user = User.find_or_create_by(email: "#{speaker_name.parameterize}@temporary.abairt") do |user|
          user.name = speaker_name
          user.role = :temporary
          user.address = data[:hometown]
        end

        # Group segments into sentences based on punctuation
        current_sentence = {
          start: data[:segments].first[:start],
          end: nil,
          text: "",
          standardized_text: ""
        }
        sentences = []

        data[:segments].each do |segment|
          # Update the current sentence
          if current_sentence[:text].empty?
            current_sentence[:start] = segment[:start]
            current_sentence[:text] = segment[:text].to_s
            current_sentence[:standardized_text] = segment[:standardized_text].to_s
          else
            current_sentence[:text] += " " + segment[:text].to_s

            if segment[:standardized_text].present?
              current_sentence[:standardized_text] += " " + segment[:standardized_text].to_s
            end
          end

          current_sentence[:end] = segment[:end]

          # Check if this segment ends with sentence-ending punctuation
          # But exclude ellipses (...) which indicate pauses, not sentence endings
          if segment[:text] =~ /[!?]$/ || (segment[:text] =~ /\.$/ && segment[:text] !~ /\.\.\.$/)
            # Add to sentences array
            sentences << current_sentence

            # Start a new sentence
            current_sentence = {
              start: nil,
              end: nil,
              text: "",
              standardized_text: ""
            }
          end
        end

        # Add the last sentence if it's not empty
        if current_sentence[:text].present?
          sentences << current_sentence
        end

        # Process each sentence as a dictionary entry
        sentences.each do |sentence|
          next if sentence[:text].blank?

          # Create dictionary entry
          entry = DictionaryEntry.create!(
            word_or_phrase: sentence[:text],
            standard_irish: sentence[:standardized_text].presence,
            speaker: temp_user,
            owner: voice_recording.owner,
            voice_recording: voice_recording,
            region_start: sentence[:start],
            region_end: sentence[:end],
            region_id: SecureRandom.hex(8)
          )

          # Create snippet, translate to english, and apply tags in bg job
          entry.post_process
        end
      end

      Rails.logger.info "Voice recording '#{voice_recording.title}' imported successfully with ID: #{voice_recording.id}"
      return voice_recording
    end
  end
end

# frozen_string_literal: true

module Fotheidil
  # Parses transcript data from Fotheidil video pages
  # Handles pagination and extracts speaker-segmented transcripts
  class ParserService
    attr_reader :browser_service

    def initialize(browser_service = nil)
      @browser_service = browser_service || Fotheidil::BrowserService.new
      @owns_browser = browser_service.nil?
      ensure_authenticated if @browser_service
    end

    # Main public method: Parse segments from a Fotheidil video by ID
    # Returns array of segment hashes with keys: start, end, text, speaker
    def parse_segments(video_id)
      html = get_page_source(video_id)
      segments = parse_html(html)
      Rails.logger.info "Parsed #{segments.length} segments for video #{video_id}"
      segments
    ensure
      # Only cleanup if we created the browser ourselves
      cleanup if @owns_browser
    end

    # Parse HTML content and extract segments
    # Returns array of segment hashes with keys: start, end, text, speaker
    def parse_html(html_content)
      doc = Nokogiri::HTML(html_content)
      scripts = doc.css("script")
      text = scripts.detect { |s| s.text.include? "endTimeSeconds" }.text
      start_idx = text.index('data')
      end_idx = text.index('originalData')
      substring = text[start_idx..end_idx]
      start_idx = substring.index('[')
      end_idx = substring.index(']')
      data = substring[start_idx..end_idx]
      json = data.gsub(/\\"/, '"').gsub(/\\\\/, '\\') 
      JSON.parse(json)
    end

    private

    def get_page_source(video_id)
       # Navigate to the video page
       url = "https://fotheidil.abair.ie/videos/#{video_id}"
       @browser_service.driver.navigate.to url
 
       # Wait for page to load
       wait = Selenium::WebDriver::Wait.new(timeout: 10)
       wait.until { @browser_service.driver.find_element(css: "div.py-5.border-b.border-gray-300.bg-white.relative") }
 
       # Parse segments from current page
       html = @browser_service.driver.page_source
    end

    def cleanup
      return if Rails.env.test?
      
      @browser_service&.cleanup
    end

    def ensure_authenticated
      return if Rails.env.test?

      if @browser_service.driver.nil?
        @browser_service.authenticate
      end
    end
  end
end

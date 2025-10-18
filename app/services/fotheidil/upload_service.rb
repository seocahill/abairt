# frozen_string_literal: true

module Fotheidil
  # Handles file upload to Fotheidil platform
  # Uses browser automation to upload audio/video files
  class UploadService
    UPLOAD_URL = "https://fotheidil.abair.ie/upload"
    VIDEOS_URL = "https://fotheidil.abair.ie/videos"
    MAX_REDIRECT_WAIT = 20
    REDIRECT_CHECK_INTERVAL = 2

    def initialize(browser_service)
      @browser_service = browser_service
    end

    def upload_file(file_path)
      return nil unless driver
      return nil unless validate_file(file_path)

      Rails.logger.info "Uploading file to Fotheidil: #{file_path}"

      navigate_and_select_file(file_path)
      click_upload_button
      wait_for_redirect
    rescue => e
      Rails.logger.error "Upload error: #{e.message}"
      nil
    end

    private

    def driver
      @browser_service.instance_variable_get(:@driver)
    end

    def validate_file(file_path)
      return true if File.exist?(file_path)

      Rails.logger.error "File does not exist: #{file_path}"
      false
    end

    def navigate_and_select_file(file_path)
      driver.navigate.to(UPLOAD_URL)
      sleep(2)

      file_input = driver.find_element(:css, 'input[type="file"]')
      file_input.send_keys(file_path)
      Rails.logger.info "File selected: #{file_path}"

      Rails.logger.info "Waiting for Upload button to appear..."
      sleep(3)
    end

    def click_upload_button
      upload_button = find_upload_button

      if upload_button
        Rails.logger.info "Found Upload button, clicking..."
        upload_button.click
        Rails.logger.info "Clicked Upload button"
      else
        Rails.logger.error "Upload button not found after file selection"
        log_page_debug_info
        raise "Upload button not found"
      end
    end

    def find_upload_button
      buttons = driver.find_elements(:tag_name, "button")
      Rails.logger.info "Found #{buttons.length} buttons on page"

      log_button_details(buttons)

      buttons.find do |btn|
        btn.displayed? && btn.text.strip.downcase == "upload"
      rescue
        false
      end
    end

    def log_button_details(buttons)
      buttons.each_with_index do |btn, i|
        Rails.logger.debug { "  Button #{i}: text='#{btn.text.strip}', displayed=#{btn.displayed?}" }
      rescue
        Rails.logger.debug { "  Button #{i}: (error accessing)" }
      end
    end

    def log_page_debug_info
      page_source = driver.page_source
      Rails.logger.debug { "Page source snippet: #{page_source[0..500]}" }
    end

    def wait_for_redirect
      Rails.logger.info "Waiting for upload to complete and redirect..."

      current_url = monitor_redirect

      Rails.logger.info "Final URL: #{current_url}"

      parse_redirect_result(current_url)
    end

    def monitor_redirect
      current_url = nil

      (1..MAX_REDIRECT_WAIT).each do |i|
        sleep(REDIRECT_CHECK_INTERVAL)
        current_url = driver.current_url

        if current_url != UPLOAD_URL
          Rails.logger.info "Redirected after #{i * REDIRECT_CHECK_INTERVAL} seconds to: #{current_url}"
          break
        end

        Rails.logger.debug { "Still on upload page, waiting... (#{i}/#{MAX_REDIRECT_WAIT})" } if (i % 3).zero?
      end

      current_url
    end

    def parse_redirect_result(current_url)
      case current_url
      when VIDEOS_URL
        handle_videos_list_redirect
      when %r{/videos/[^/]+$}
        Rails.logger.info "Upload complete - redirected to video: #{current_url}"
        current_url
      when UPLOAD_URL
        Rails.logger.warn "Upload may have failed - still on upload page"
        nil
      else
        Rails.logger.info "Upload redirected to unexpected URL: #{current_url}"
        current_url
      end
    end

    def handle_videos_list_redirect
      Rails.logger.info "Redirected to videos list, looking for uploading video..."
      sleep(2)

      video_links = driver.find_elements(:css, 'a[href^="/videos/"]')
      return extract_first_video_url(video_links) if video_links.any?

      Rails.logger.warn "No video links found on videos page"
      nil
    rescue => e
      Rails.logger.error "Error finding video link: #{e.message}"
      nil
    end

    def extract_first_video_url(video_links)
      first_video = video_links.first
      href = first_video.attribute("href")
      full_url = href.start_with?("http") ? href : "https://fotheidil.abair.ie#{href}"
      Rails.logger.info "Found uploaded video: #{full_url}"
      full_url
    end
  end
end

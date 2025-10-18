# frozen_string_literal: true

# End-to-end test for Fotheidil integration
#
# Prerequisites:
# 1. Run: EDITOR=nano bin/rails credentials:edit
# 2. Add the following:
#    fotheidil:
#      email: your-email@example.com
#      password: your-password
#      supabase_anon_key: eyJhbGci...  # From WebSocket URL
#      refresh_token: xxxxx...  # From login cookie
#
# Usage:
#   bin/rails runner test/services/fotheidil_integration_test.rb /path/to/audio.mp3

class FotheidilIntegrationTest
  def self.run(file_path = nil)
    puts "=" * 80
    puts "FOTHEIDIL INTEGRATION TEST"
    puts "=" * 80
    puts

    # Step 1: Verify credentials are configured
    puts "Step 1: Checking Rails credentials..."
    creds = Rails.application.credentials.fotheidil

    unless creds
      puts "❌ No fotheidil credentials found!"
      puts "\nRun: EDITOR=nano bin/rails credentials:edit"
      puts "And add:"
      puts "fotheidil:"
      puts "  email: your-email@example.com"
      puts "  password: your-password"
      puts "  supabase_anon_key: eyJhbGci...  # From WebSocket URL"
      puts "  refresh_token: xxxxx...  # From login cookie"
      return false
    end

    required_keys = [:email, :password, :supabase_anon_key, :refresh_token]
    missing = required_keys.reject { |k| creds[k].present? }

    if missing.any?
      puts "❌ Missing credentials: #{missing.join(', ')}"
      puts "\nRun: EDITOR=nano bin/rails credentials:edit"
      puts "And ensure all required keys are present"
      return false
    end

    puts "✅ All credentials configured"
    puts "  Email: #{creds[:email]}"
    puts "  Refresh token: #{creds[:refresh_token][0..10]}..."
    puts "  Anon key: #{creds[:supabase_anon_key][0..20]}..."
    puts

    # Step 2: Test authentication
    puts "Step 2: Testing authentication..."
    service = FotheidilAuthenticationService.new

    if service.authenticate
      puts "✅ Authentication successful!"
      puts "  Access token: #{service.access_token[0..30]}..."
    else
      puts "❌ Authentication failed"
      puts "\nCheck your refresh_token and supabase_anon_key"
      return false
    end
    puts

    # Step 3: Test Supabase query
    puts "Step 3: Testing Supabase access..."
    begin
      require 'httparty'
      require 'zlib'
      require 'stringio'

      response = HTTParty.get(
        "https://pdntukcptgktuzpynlsv.supabase.co/rest/v1/transcriptions?limit=1",
        {
          headers: {
            'apikey' => creds[:supabase_anon_key],
            'Authorization' => "Bearer #{service.access_token}",
            'Accept' => 'application/json'
          },
          format: :plain
        }
      )

      if response.success?
        gz = Zlib::GzipReader.new(StringIO.new(response.body))
        decompressed = gz.read.force_encoding('UTF-8')
        gz.close

        data = JSON.parse(decompressed)
        puts "✅ Supabase query successful!"
        puts "  Found #{data.length} transcription(s) in database"
      else
        puts "❌ Supabase query failed: #{response.code}"
        return false
      end
    rescue => e
      puts "❌ Supabase query error: #{e.message}"
      return false
    end
    puts

    # Step 4: Test upload (if file provided)
    if file_path && File.exist?(file_path)
      puts "Step 4: Testing file upload..."
      puts "  File: #{file_path}"
      puts "  Size: #{File.size(file_path) / 1024}KB"
      puts

      integration_service = FotheidilIntegrationService.new

      if !integration_service.authenticate
        puts "❌ Re-authentication failed"
        return false
      end

      puts "Uploading and processing (this may take several minutes)..."
      result = integration_service.upload_and_process(file_path, timeout: 300)

      if result
        puts "✅ Upload and processing successful!"
        puts "\nResult:"
        puts JSON.pretty_generate(result)
        puts
        puts "Segments extracted: #{result[:diarization]&.length || 0}"
      else
        puts "❌ Upload or processing failed"
        puts "Check logs for details"
        return false
      end
    else
      puts "Step 4: File upload test skipped (no file provided)"
      puts "  To test upload, run:"
      puts "  bin/rails runner test/services/fotheidil_integration_test.rb /path/to/audio.mp3"
    end
    puts

    puts "=" * 80
    puts "✅ ALL TESTS PASSED!"
    puts "=" * 80
    true
  end
end

# Run if called directly
if __FILE__ == $0
  file_path = ARGV[0]
  FotheidilIntegrationTest.run(file_path)
end

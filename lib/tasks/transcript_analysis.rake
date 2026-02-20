# frozen_string_literal: true

namespace :analysis do
  desc "Analyze all voice recordings with transcripts to extract location and speaker metadata"
  task all: :environment do
    recordings = VoiceRecording
      .joins(:dictionary_entries)
      .where(metadata_analysis: nil)
      .distinct

    total = recordings.count
    puts "Found #{total} voice recordings to analyze"

    recordings.find_each.with_index do |recording, index|
      print "\rAnalyzing #{index + 1}/#{total}: #{recording.title.to_s.truncate(40)}..."

      result = TranscriptAnalysisService.new(recording).analyze

      if result[:skipped]
        puts " skipped (#{result[:reason]})"
      else
        puts " done (#{result[:locations].size} locations, #{result[:speakers].size} speakers)"
      end

      # Rate limit to avoid API throttling
      sleep 1
    rescue => e
      puts " ERROR: #{e.message}"
      Rails.logger.error("Analysis failed for VoiceRecording##{recording.id}: #{e.message}")
    end

    puts "\nAnalysis complete!"
  end

  desc "Analyze a single voice recording by ID"
  task :one, [:id] => :environment do |_t, args|
    recording = VoiceRecording.find(args[:id])
    puts "Analyzing: #{recording.title}"

    result = TranscriptAnalysisService.new(recording).analyze
    puts JSON.pretty_generate(result[:raw_analysis]) if result[:raw_analysis]
    puts "\nLocations found: #{result[:locations].map { |l| l[:location].name }.join(', ')}"
    puts "Speakers found: #{result[:speakers].map { |s| s[:name] || 'unnamed' }.join(', ')}"
    puts "Dialect region: #{result[:dialect_region]}"
  end

  desc "Re-analyze all voice recordings (force refresh)"
  task reanalyze: :environment do
    recordings = VoiceRecording.joins(:dictionary_entries).distinct
    total = recordings.count
    puts "Re-analyzing #{total} voice recordings"

    recordings.find_each.with_index do |recording, index|
      print "\rAnalyzing #{index + 1}/#{total}..."

      TranscriptAnalysisService.new(recording).analyze
      sleep 1
    rescue => e
      Rails.logger.error("Analysis failed for VoiceRecording##{recording.id}: #{e.message}")
    end

    puts "\nRe-analysis complete!"
  end

  desc "Generate statistics report on analyzed recordings"
  task stats: :environment do
    puts "\n=== Transcript Analysis Statistics ===\n\n"

    # Overall counts
    total = VoiceRecording.count
    analyzed = VoiceRecording.where.not(metadata_analysis: nil).count
    with_location = VoiceRecording.where.not(location_id: nil).count

    puts "Voice Recordings:"
    puts "  Total: #{total}"
    puts "  Analyzed: #{analyzed} (#{(analyzed.to_f / total * 100).round(1)}%)"
    puts "  With location: #{with_location}"
    puts ""

    # Locations
    puts "Locations:"
    Location.group(:dialect_region).count.each do |region, count|
      puts "  #{region}: #{count}"
    end
    puts ""

    # Dialect distribution from analysis
    puts "Dialect Distribution (from analysis):"
    dialect_counts = VoiceRecording
      .where.not(metadata_analysis: nil)
      .pluck(:metadata_analysis)
      .map { |m| m&.dig("dialect_region") }
      .compact
      .tally
      .sort_by { |_, v| -v }

    dialect_counts.each do |region, count|
      puts "  #{region}: #{count}"
    end
    puts ""

    # Speaker gender distribution
    puts "Speaker Gender Distribution (from analysis):"
    gender_counts = { "male" => 0, "female" => 0, "unknown" => 0 }

    VoiceRecording.where.not(metadata_analysis: nil).find_each do |vr|
      speakers = vr.metadata_analysis&.dig("speakers") || []
      speakers.each do |s|
        gender = s["gender"] || "unknown"
        gender_counts[gender] = (gender_counts[gender] || 0) + 1
      end
    end

    gender_counts.each do |gender, count|
      puts "  #{gender}: #{count}"
    end
  end

  desc "Export analysis data to CSV"
  task export_csv: :environment do
    require "csv"

    filename = "transcript_analysis_#{Date.current}.csv"
    path = Rails.root.join("tmp", filename)

    CSV.open(path, "w") do |csv|
      csv << %w[id title dialect_region locations speakers topics analyzed_at]

      VoiceRecording.where.not(metadata_analysis: nil).find_each do |vr|
        analysis = vr.metadata_analysis
        csv << [
          vr.id,
          vr.title,
          analysis["dialect_region"],
          analysis["locations"]&.map { |l| l["name"] }&.join("; "),
          analysis["speakers"]&.map { |s| s["name"] }&.compact&.join("; "),
          analysis["topics"]&.join("; "),
          analysis["analyzed_at"]
        ]
      end
    end

    puts "Exported to #{path}"
  end

  desc "Seed initial Mayo locations with coordinates"
  task seed_locations: :environment do
    locations_data = [
      # Erris
      { name: "Béal an Mhuirthead", irish_name: "Béal an Mhuirthead", english_name: "Belmullet", dialect_region: "erris", lat: 54.2258, lng: -9.9906, type: "parish" },
      { name: "Gleann na Muaidhe", irish_name: "Gleann na Muaidhe", english_name: "Glenamoy", dialect_region: "erris", lat: 54.2500, lng: -9.7500, type: "townland" },
      { name: "Ceathrú Thaidhg", irish_name: "Ceathrú Thaidhg", english_name: "Carrowteige", dialect_region: "erris", lat: 54.3100, lng: -9.8500, type: "townland" },
      { name: "Barr na Trá", irish_name: "Barr na Trá", english_name: "Barnatra", dialect_region: "erris", lat: 54.1833, lng: -9.7333, type: "townland" },
      { name: "Gaoth Sáile", irish_name: "Gaoth Sáile", english_name: "Geesala", dialect_region: "erris", lat: 54.1167, lng: -9.7833, type: "townland" },
      { name: "Dumha Thuama", irish_name: "Dumha Thuama", english_name: "Doohoma", dialect_region: "erris", lat: 54.0500, lng: -9.8667, type: "townland" },
      { name: "Iorras", irish_name: "Iorras", english_name: "Erris", dialect_region: "erris", lat: 54.15, lng: -9.85, type: "region" },

      # Achill
      { name: "Acaill", irish_name: "Acaill", english_name: "Achill", dialect_region: "achill", lat: 53.9667, lng: -10.0500, type: "region" },
      { name: "Dúgh Aill", irish_name: "Dúgh Aill", english_name: "Dooagh", dialect_region: "achill", lat: 53.9833, lng: -10.1167, type: "townland" },
      { name: "Dumha Éige", irish_name: "Dumha Éige", english_name: "Dooega", dialect_region: "achill", lat: 53.9167, lng: -10.0167, type: "townland" },
      { name: "Bun na hAbhna", irish_name: "Bun na hAbhna", english_name: "Bunacurry", dialect_region: "achill", lat: 53.9333, lng: -9.9667, type: "townland" },
      { name: "Gob an Choire", irish_name: "Gob an Choire", english_name: "Achill Sound", dialect_region: "achill", lat: 53.9000, lng: -9.9333, type: "townland" },

      # Tourmakeady
      { name: "Tuar Mhic Éadaigh", irish_name: "Tuar Mhic Éadaigh", english_name: "Tourmakeady", dialect_region: "tourmakeady", lat: 53.6200, lng: -9.4500, type: "parish" },
      { name: "Fionnaithe", irish_name: "Fionnaithe", english_name: "Finny", dialect_region: "tourmakeady", lat: 53.6500, lng: -9.5000, type: "townland" },
      { name: "Partaí", irish_name: "Partaí", english_name: "Partry", dialect_region: "tourmakeady", lat: 53.6833, lng: -9.4667, type: "townland" },
      { name: "Gleann Caisil", irish_name: "Gleann Caisil", english_name: "Glencastle", dialect_region: "tourmakeady", lat: 53.6000, lng: -9.5333, type: "townland" },

      # East Mayo
      { name: "Caisleán an Bharraigh", irish_name: "Caisleán an Bharraigh", english_name: "Castlebar", dialect_region: "east_mayo", lat: 53.8000, lng: -9.3000, type: "parish" },
      { name: "Baile an Róba", irish_name: "Baile an Róba", english_name: "Ballinrobe", dialect_region: "east_mayo", lat: 53.6333, lng: -9.2333, type: "parish" },
      { name: "Clár Chlainne Mhuiris", irish_name: "Clár Chlainne Mhuiris", english_name: "Claremorris", dialect_region: "east_mayo", lat: 53.7167, lng: -8.9833, type: "parish" },
    ]

    locations_data.each do |data|
      location = Location.find_or_initialize_by(name: data[:name])
      location.assign_attributes(
        irish_name: data[:irish_name],
        dialect_region: data[:dialect_region],
        location_type: data[:type],
        latitude: data[:lat],
        longitude: data[:lng]
      )
      location.save!
      puts "Created/updated: #{location.name} (#{location.dialect_region})"
    end

    puts "\nSeeded #{locations_data.size} locations"
  end
end

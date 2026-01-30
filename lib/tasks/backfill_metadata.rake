# frozen_string_literal: true

namespace :voice_recordings do
  desc "Backfill AI metadata for voice recordings (themes, locations, speakers)"
  task backfill_metadata: :environment do
    recordings = VoiceRecording
      .where(metadata_extracted_at: nil)
      .joins(:dictionary_entries)
      .where.not(dictionary_entries: { translation: [nil, ""] })
      .distinct

    total = recordings.count
    puts "Found #{total} recordings to process"

    if total.zero?
      puts "Nothing to backfill!"
      exit
    end

    print "Queue all for background processing? (y/n): "
    response = $stdin.gets&.chomp&.downcase

    if response == "y"
      BackfillVoiceRecordingMetadataJob.perform_later
      puts "Queued BackfillVoiceRecordingMetadataJob"
    else
      puts "Processing synchronously..."
      recordings.find_each.with_index do |recording, index|
        print "\rProcessing #{index + 1}/#{total}: #{recording.title&.truncate(40)}"
        VoiceRecordingMetadataService.new(recording).process
      rescue => e
        puts "\nError processing VoiceRecording##{recording.id}: #{e.message}"
      end
      puts "\nDone!"
    end
  end

  desc "Show metadata extraction stats"
  task metadata_stats: :environment do
    total = VoiceRecording.count
    with_metadata = VoiceRecording.where.not(metadata_extracted_at: nil).count
    with_translations = VoiceRecording
      .joins(:dictionary_entries)
      .where.not(dictionary_entries: { translation: [nil, ""] })
      .distinct
      .count

    puts "Voice Recording Metadata Stats"
    puts "-" * 40
    puts "Total recordings:        #{total}"
    puts "With translations:       #{with_translations}"
    puts "With metadata extracted: #{with_metadata}"
    puts "Pending extraction:      #{with_translations - with_metadata}"
  end
end

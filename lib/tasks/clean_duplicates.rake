namespace :duplicates do
  desc "Clean duplicate dictionary entries, keeping first entry with ASR text (word_or_phrase)"
  task clean: :environment do
    puts "Starting duplicate cleanup..."

    total_deleted = 0
    voice_recordings_processed = 0

    # Find all voice recordings that have dictionary entries
    VoiceRecording.joins(:dictionary_entries).distinct.find_each do |vr|
      puts "Processing VoiceRecording #{vr.id}: #{vr.title}"
      voice_recordings_processed += 1

      # Find duplicate groups (same region_start and region_end)
      duplicate_groups = vr.dictionary_entries
                          .group(:region_start, :region_end)
                          .having('COUNT(*) > 1')
                          .count

      if duplicate_groups.empty?
        puts "  No duplicates found"
        next
      end

      puts "  Found #{duplicate_groups.size} duplicate groups"

      duplicate_groups.each do |(region_start, region_end), count|
        puts "    Processing region #{region_start}-#{region_end} (#{count} entries)"

        # Get all entries for this region, ordered by creation time
        entries = vr.dictionary_entries
                   .where(region_start: region_start, region_end: region_end)
                   .order(:created_at)

        # Find the first entry with word_or_phrase text, or fall back to first entry
        keeper = entries.find { |entry| entry.word_or_phrase.present? } || entries.first

        # Delete all others
        to_delete = entries.where.not(id: keeper.id)
        deleted_count = to_delete.count

        if deleted_count > 0
          puts "      Keeping entry #{keeper.id} (#{keeper.word_or_phrase.present? ? 'has ASR text' : 'no ASR text, keeping first'})"
          puts "      Deleting #{deleted_count} duplicate entries: #{to_delete.pluck(:id).join(', ')}"

          to_delete.destroy_all
          total_deleted += deleted_count
        end
      end

      # Update the counter cache
      vr.update_column(:dictionary_entries_count, vr.dictionary_entries.count)
    end

    puts "\nCleanup completed:"
    puts "  Voice recordings processed: #{voice_recordings_processed}"
    puts "  Total duplicate entries deleted: #{total_deleted}"
  end

  desc "Preview duplicate cleanup (dry run)"
  task preview: :environment do
    puts "Preview: Duplicate cleanup analysis"
    puts "=" * 50

    total_duplicates = 0
    voice_recordings_with_duplicates = 0

    VoiceRecording.joins(:dictionary_entries).distinct.find_each do |vr|
      duplicate_groups = vr.dictionary_entries
                          .group(:region_start, :region_end)
                          .having('COUNT(*) > 1')
                          .count

      next if duplicate_groups.empty?

      voice_recordings_with_duplicates += 1
      puts "\nVoiceRecording #{vr.id}: #{vr.title}"
      puts "  Segments count: #{vr.segments_count}"
      puts "  Total entries: #{vr.dictionary_entries.count}"
      puts "  Duplicate groups: #{duplicate_groups.size}"

      duplicate_groups.each do |(region_start, region_end), count|
        entries = vr.dictionary_entries
                   .where(region_start: region_start, region_end: region_end)
                   .order(:created_at)

        keeper = entries.find { |entry| entry.word_or_phrase.present? } || entries.first
        to_delete_count = count - 1
        total_duplicates += to_delete_count

        puts "    Region #{region_start}-#{region_end}: #{count} entries"
        puts "      Would keep: #{keeper.id} (#{keeper.word_or_phrase.present? ? 'has ASR' : 'first entry'})"
        puts "      Would delete: #{to_delete_count} entries"
      end
    end

    puts "\n" + "=" * 50
    puts "Summary:"
    puts "  Voice recordings with duplicates: #{voice_recordings_with_duplicates}"
    puts "  Total duplicate entries that would be deleted: #{total_duplicates}"
    puts "\nRun 'rake duplicates:clean' to perform the actual cleanup"
  end
end
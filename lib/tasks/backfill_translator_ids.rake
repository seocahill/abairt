namespace :backfill do
  desc "Backfill translator_id from PaperTrail versions"
  task translator_ids: :environment do
    puts "Starting translator_id backfill..."
    
    updated_count = 0
    total_count = 0
    
    DictionaryEntry.where(translator_id: nil).includes(:versions).find_each do |entry|
      total_count += 1
      
      # Use the existing translator method logic to determine the translator
      translator_user = User.find_by(id: entry.versions.last&.whodunnit)
      
      if translator_user
        entry.update_column(:translator_id, translator_user.id)
        updated_count += 1
        print "."
      else
        print "x"
      end
      
      # Progress indicator every 100 entries
      if total_count % 100 == 0
        puts " #{total_count} processed"
      end
    end
    
    puts "\nBackfill complete!"
    puts "Total entries processed: #{total_count}"
    puts "Entries updated: #{updated_count}"
    puts "Entries without translator: #{total_count - updated_count}"
  end
end
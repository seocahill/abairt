namespace :media_imports do
  desc "Populate MediaImport records from media.json file"
  task populate: :environment do
    media_file_path = Rails.root.join('lib', 'assets', 'media.json')
    
    unless File.exist?(media_file_path)
      puts "❌ media.json file not found at #{media_file_path}"
      exit 1
    end

    puts "📖 Reading media.json file..."
    media_data = JSON.parse(File.read(media_file_path))
    
    puts "📊 Found #{media_data.length} items in media.json"
    
    created_count = 0
    skipped_count = 0
    
    media_data.each do |item|
      # Check if this URL already exists
      if MediaImport.exists?(url: item['url'])
        puts "⏭️  Skipping existing item: #{item['title']}"
        skipped_count += 1
        next
      end
      
      # Create new MediaImport record
      MediaImport.create!(
        url: item['url'],
        title: item['title'],
        headline: item['headline'],
        description: item['description'],
        status: :pending
      )
      
      puts "✅ Created: #{item['title']}"
      created_count += 1
    end
    
    puts "\n🎉 Import complete!"
    puts "   Created: #{created_count} new records"
    puts "   Skipped: #{skipped_count} existing records"
    puts "   Total: #{MediaImport.count} records in database"
  end

  desc "Reset all MediaImport records to pending status"
  task reset: :environment do
    puts "🔄 Resetting all MediaImport records to pending status..."
    
    updated_count = MediaImport.update_all(
      status: :pending,
      error_message: nil,
      imported_at: nil,
      updated_at: Time.current
    )
    
    puts "✅ Reset #{updated_count} records to pending status"
  end

  desc "Show MediaImport statistics"
  task stats: :environment do
    total = MediaImport.count
    pending = MediaImport.pending.count
    imported = MediaImport.imported.count
    skipped = MediaImport.skipped.count
    
    puts "📊 MediaImport Statistics:"
    puts "   Total: #{total}"
    puts "   Pending: #{pending} (#{(pending.to_f / total * 100).round(1)}%)"
    puts "   Imported: #{imported} (#{(imported.to_f / total * 100).round(1)}%)"
    puts "   Skipped: #{skipped} (#{(skipped.to_f / total * 100).round(1)}%)"
  end

  desc "Clean up failed imports (reset error messages and set to pending)"
  task cleanup_failed: :environment do
    puts "🧹 Cleaning up failed imports..."
    
    failed_imports = MediaImport.where.not(error_message: nil)
    updated_count = failed_imports.update_all(
      status: :pending,
      error_message: nil,
      updated_at: Time.current
    )
    
    puts "✅ Cleaned up #{updated_count} failed imports"
  end

  desc "Process a batch of pending MediaImport items"
  task :process_batch, [:limit] => :environment do |t, args|
    limit = (args[:limit] || 10).to_i
    puts "🔄 Processing batch of #{limit} pending MediaImport items..."
    
    processed_count = 0
    MediaImport.pending.limit(limit).find_each do |media_import|
      begin
        media_import.process_now!
        processed_count += 1
        puts "✅ Processed: #{media_import.title}"
      rescue => e
        puts "❌ Failed: #{media_import.title} - #{e.message}"
      end
    end
    
    puts "🎉 Batch processing complete! Processed #{processed_count} items"
  end

  desc "Queue all pending MediaImport items for background processing"
  task queue_all: :environment do
    puts "📤 Queueing all pending MediaImport items for background processing..."
    
    queued_count = 0
    MediaImport.pending.find_each do |media_import|
      media_import.queue_for_processing!
      queued_count += 1
    end
    
    puts "✅ Queued #{queued_count} items for background processing"
  end

  desc "Process next single MediaImport item"
  task process_next: :environment do
    puts "🔄 Processing next MediaImport item..."
    
    media_import = MediaImport.pending.first
    if media_import
      begin
        media_import.process_now!
        puts "✅ Successfully processed: #{media_import.title}"
      rescue => e
        puts "❌ Failed to process: #{media_import.title} - #{e.message}"
      end
    else
      puts "ℹ️  No pending MediaImport items found"
    end
  end
end

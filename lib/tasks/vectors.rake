# frozen_string_literal: true

namespace :vectors do
  desc "Migrate vector embeddings from primary database to vectors database"
  task migrate_to_vectors_db: :environment do
    puts "Starting vector migration..."

    # Get count from primary database
    primary_count = ActiveRecord::Base.connection.execute(
      "SELECT COUNT(*) as count FROM vec_dictionary_entry_embeddings"
    ).first["count"]

    puts "Found #{primary_count} embeddings in primary database"

    if primary_count == 0
      puts "No embeddings to migrate."
      next
    end

    # Get database paths
    primary_db = ActiveRecord::Base.connection_db_config.database
    vectors_db = VectorsRecord.connection_db_config.database

    puts "Primary DB: #{primary_db}"
    puts "Vectors DB: #{vectors_db}"

    # Use ATTACH DATABASE to copy data between databases
    VectorsRecord.connection.execute("ATTACH DATABASE '#{primary_db}' AS primary_db")

    begin
      # Copy embeddings from primary to vectors database
      VectorsRecord.connection.execute(<<~SQL)
        INSERT INTO vec_dictionary_entry_embeddings (dictionary_entry_id, embedding)
        SELECT dictionary_entry_id, embedding
        FROM primary_db.vec_dictionary_entry_embeddings
      SQL

      # Verify migration
      vectors_count = VectorsRecord.connection.execute(
        "SELECT COUNT(*) as count FROM vec_dictionary_entry_embeddings"
      ).first["count"]

      puts "\n✅ Migration complete!"
      puts "   Primary database: #{primary_count} embeddings"
      puts "   Vectors database: #{vectors_count} embeddings"

      if vectors_count == primary_count
        puts "\n✅ All embeddings migrated successfully!"
      else
        puts "\n⚠️  Warning: Counts don't match. Primary: #{primary_count}, Vectors: #{vectors_count}"
      end
    ensure
      VectorsRecord.connection.execute("DETACH DATABASE primary_db")
    end
  end

  desc "Check vector database status"
  task status: :environment do
    primary_count = begin
      result = ActiveRecord::Base.connection.execute(
        "SELECT COUNT(*) as count FROM vec_dictionary_entry_embeddings"
      ).first
      result ? (result["count"] || result[0] || 0) : 0
    rescue => e
      $stderr.puts "Primary DB error: #{e.message}"
      0
    end

    vectors_count = begin
      result = VectorsRecord.connection.execute(
        "SELECT COUNT(*) as count FROM vec_dictionary_entry_embeddings"
      ).first
      result ? (result["count"] || result[0] || 0) : 0
    rescue => e
      $stderr.puts "Vectors DB error: #{e.message}"
      0
    end

    puts "\nVector Embeddings Status:"
    puts "  Primary database:  #{primary_count} embeddings"
    puts "  Vectors database:  #{vectors_count} embeddings"
  end
end

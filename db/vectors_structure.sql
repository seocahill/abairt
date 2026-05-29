CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE VIRTUAL TABLE vec_dictionary_entry_embeddings
      USING vec0(
        dictionary_entry_id INTEGER NOT NULL,
        embedding float[1536]
      );
CREATE TABLE IF NOT EXISTS "vec_dictionary_entry_embeddings_info" (key text primary key, value any);
CREATE TABLE IF NOT EXISTS "vec_dictionary_entry_embeddings_chunks"(chunk_id INTEGER PRIMARY KEY AUTOINCREMENT,size INTEGER NOT NULL,validity BLOB NOT NULL,rowids BLOB NOT NULL);
CREATE TABLE IF NOT EXISTS "vec_dictionary_entry_embeddings_rowids"(rowid INTEGER PRIMARY KEY AUTOINCREMENT,id,chunk_id INTEGER,chunk_offset INTEGER);
CREATE TABLE IF NOT EXISTS "vec_dictionary_entry_embeddings_vector_chunks00"(rowid PRIMARY KEY,vectors BLOB NOT NULL);
CREATE TABLE IF NOT EXISTS "vec_dictionary_entry_embeddings_metadatachunks00"(rowid PRIMARY KEY, data BLOB NOT NULL);
INSERT INTO "schema_migrations" (version) VALUES
('20260331221316');


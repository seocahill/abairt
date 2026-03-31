CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "active_storage_attachments" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "record_type" varchar NOT NULL, "record_id" integer NOT NULL, "blob_id" integer NOT NULL, "created_at" datetime NOT NULL, CONSTRAINT "fk_rails_c3b3935057"
FOREIGN KEY ("blob_id")
  REFERENCES "active_storage_blobs" ("id")
);
CREATE INDEX "index_active_storage_attachments_on_blob_id" ON "active_storage_attachments" ("blob_id");
CREATE UNIQUE INDEX "index_active_storage_attachments_uniqueness" ON "active_storage_attachments" ("record_type", "record_id", "name", "blob_id");
CREATE TABLE IF NOT EXISTS "active_storage_variant_records" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "blob_id" integer NOT NULL, "variation_digest" varchar NOT NULL, CONSTRAINT "fk_rails_993965df05"
FOREIGN KEY ("blob_id")
  REFERENCES "active_storage_blobs" ("id")
);
CREATE UNIQUE INDEX "index_active_storage_variant_records_uniqueness" ON "active_storage_variant_records" ("blob_id", "variation_digest");
CREATE TABLE IF NOT EXISTS "tags" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar, "created_at" datetime, "updated_at" datetime, "taggings_count" integer DEFAULT 0);
CREATE TABLE IF NOT EXISTS "taggings" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "tag_id" integer, "taggable_type" varchar, "taggable_id" integer, "tagger_type" varchar, "tagger_id" integer, "context" varchar(128), "created_at" datetime, "tenant" varchar(128), CONSTRAINT "fk_rails_9fcd2e236b"
FOREIGN KEY ("tag_id")
  REFERENCES "tags" ("id")
);
CREATE UNIQUE INDEX "index_tags_on_name" ON "tags" ("name");
CREATE UNIQUE INDEX "taggings_idx" ON "taggings" ("tag_id", "taggable_id", "taggable_type", "context", "tagger_id", "tagger_type");
CREATE INDEX "taggings_taggable_context_idx" ON "taggings" ("taggable_id", "taggable_type", "context");
CREATE INDEX "index_taggings_on_tag_id" ON "taggings" ("tag_id");
CREATE INDEX "index_taggings_on_taggable_id" ON "taggings" ("taggable_id");
CREATE INDEX "index_taggings_on_taggable_type" ON "taggings" ("taggable_type");
CREATE INDEX "index_taggings_on_tagger_id" ON "taggings" ("tagger_id");
CREATE INDEX "index_taggings_on_context" ON "taggings" ("context");
CREATE INDEX "index_taggings_on_tagger_id_and_tagger_type" ON "taggings" ("tagger_id", "tagger_type");
CREATE INDEX "taggings_idy" ON "taggings" ("taggable_id", "taggable_type", "tagger_id", "context");
CREATE INDEX "index_taggings_on_tenant" ON "taggings" ("tenant");
CREATE TABLE IF NOT EXISTS "word_lists" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar, "description" varchar, "starred" boolean, "user_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "script" text, CONSTRAINT "fk_rails_4aed2b283b"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_word_lists_on_user_id" ON "word_lists" ("user_id");
CREATE TABLE IF NOT EXISTS "word_list_dictionary_entries" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "dictionary_entry_id" integer NOT NULL, "word_list_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_d7de3d0dac"
FOREIGN KEY ("dictionary_entry_id")
  REFERENCES "dictionary_entries" ("id")
, CONSTRAINT "fk_rails_db6c34d026"
FOREIGN KEY ("word_list_id")
  REFERENCES "word_lists" ("id")
);
CREATE INDEX "index_word_list_dictionary_entries_on_dictionary_entry_id" ON "word_list_dictionary_entries" ("dictionary_entry_id");
CREATE INDEX "index_word_list_dictionary_entries_on_word_list_id" ON "word_list_dictionary_entries" ("word_list_id");
CREATE TABLE IF NOT EXISTS "user_lists" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "word_list_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_7b6eb4d716"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
, CONSTRAINT "fk_rails_01825ad5a3"
FOREIGN KEY ("word_list_id")
  REFERENCES "word_lists" ("id")
);
CREATE INDEX "index_user_lists_on_user_id" ON "user_lists" ("user_id");
CREATE INDEX "index_user_lists_on_word_list_id" ON "user_lists" ("word_list_id");
CREATE TABLE IF NOT EXISTS "active_storage_blobs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "key" varchar NOT NULL, "filename" varchar NOT NULL, "content_type" varchar, "metadata" text, "service_name" varchar NOT NULL, "byte_size" bigint NOT NULL, "checksum" varchar, "created_at" datetime NOT NULL);
CREATE UNIQUE INDEX "index_active_storage_blobs_on_key" ON "active_storage_blobs" ("key");
CREATE TABLE IF NOT EXISTS "voice_recordings" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "title" varchar, "description" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "peaks" json, "user_id" integer NOT NULL, "transcription" text, "transcription_en" text, "dictionary_entries_count" integer DEFAULT 0 NOT NULL, "duration_seconds" float DEFAULT 0.0 NOT NULL, "diarization_data" jsonb, "diarization_status" varchar, "import_status" varchar, "location_id" integer, "metadata_analysis" json, CONSTRAINT "fk_rails_91ca04707d"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_voice_recordings_on_user_id" ON "voice_recordings" ("user_id");
CREATE TABLE IF NOT EXISTS "versions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "item_type" varchar NOT NULL, "item_id" bigint NOT NULL, "event" varchar NOT NULL, "whodunnit" varchar, "object" json, "created_at" datetime(6));
CREATE INDEX "index_versions_on_item_type_and_item_id" ON "versions" ("item_type", "item_id");
CREATE TABLE IF NOT EXISTS "action_text_rich_texts" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "body" text, "record_type" varchar NOT NULL, "record_id" bigint NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_action_text_rich_texts_uniqueness" ON "action_text_rich_texts" ("record_type", "record_id", "name");
CREATE INDEX "index_voice_recordings_on_diarization_status" ON "voice_recordings" ("diarization_status");
CREATE TABLE IF NOT EXISTS "dictionary_entries" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "word_or_phrase" varchar, "translation" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "region_start" decimal, "region_end" decimal, "region_id" varchar, "voice_recording_id" integer, "speaker_id" integer, "user_id" integer NOT NULL, "quality" integer DEFAULT 0 NOT NULL, "standard_irish" varchar, "notes" text, "translator_id" integer, "status" integer DEFAULT 0 NOT NULL, "accuracy_status" integer DEFAULT 0 NOT NULL, CONSTRAINT "fk_rails_43cc55d212"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
, CONSTRAINT "fk_rails_c0a955f533"
FOREIGN KEY ("translator_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_dictionary_entries_on_voice_recording_id" ON "dictionary_entries" ("voice_recording_id");
CREATE INDEX "index_dictionary_entries_on_speaker_id" ON "dictionary_entries" ("speaker_id");
CREATE INDEX "index_dictionary_entries_on_user_id" ON "dictionary_entries" ("user_id");
CREATE INDEX "index_dictionary_entries_on_translator_id" ON "dictionary_entries" ("translator_id");
CREATE TABLE IF NOT EXISTS "service_statuses" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "service_name" varchar NOT NULL, "status" varchar NOT NULL, "response_time" decimal(10,3), "error_message" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE INDEX "index_service_statuses_on_service_name" ON "service_statuses" ("service_name");
CREATE INDEX "index_service_statuses_on_created_at" ON "service_statuses" ("created_at");
CREATE INDEX "index_service_statuses_on_service_name_and_created_at" ON "service_statuses" ("service_name", "created_at");
CREATE TABLE IF NOT EXISTS "emails" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "subject" varchar, "message" text, "sent_at" datetime(6), "sent_by_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_db2525f931"
FOREIGN KEY ("sent_by_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_emails_on_sent_by_id" ON "emails" ("sent_by_id");
CREATE TABLE IF NOT EXISTS "media_imports" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "url" varchar NOT NULL, "title" varchar NOT NULL, "headline" text, "description" text, "status" integer DEFAULT 0 NOT NULL, "error_message" text, "imported_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE INDEX "index_media_imports_on_status" ON "media_imports" ("status");
CREATE UNIQUE INDEX "index_media_imports_on_url" ON "media_imports" ("url");
CREATE TABLE IF NOT EXISTS "settings" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "key" varchar, "value" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_settings_on_key" ON "settings" ("key");
CREATE TABLE IF NOT EXISTS "users" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "email" varchar, "name" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "confirmed" boolean DEFAULT FALSE NOT NULL, "token" varchar, "master_id" bigint, "lat_lang" varchar, "role" integer DEFAULT 0 NOT NULL, "voice" integer DEFAULT 0 NOT NULL, "dialect" integer DEFAULT 0 NOT NULL, "login_token" varchar, "about" text, "address" varchar, "ability" integer DEFAULT 0 NOT NULL, "api_token" varchar, "location_id" integer);
CREATE INDEX "index_users_on_token" ON "users" ("token");
CREATE INDEX "index_users_on_master_id" ON "users" ("master_id");
CREATE UNIQUE INDEX "index_users_on_api_token" ON "users" ("api_token");
CREATE TABLE IF NOT EXISTS "locations" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "irish_name" varchar, "location_type" integer DEFAULT 0 NOT NULL, "dialect_region" integer DEFAULT 0 NOT NULL, "latitude" decimal(10,7), "longitude" decimal(10,7), "parent_id" integer, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE INDEX "index_locations_on_parent_id" ON "locations" ("parent_id");
CREATE INDEX "index_locations_on_name" ON "locations" ("name");
CREATE INDEX "index_locations_on_dialect_region" ON "locations" ("dialect_region");
CREATE INDEX "index_users_on_location_id" ON "users" ("location_id");
CREATE INDEX "index_voice_recordings_on_location_id" ON "voice_recordings" ("location_id");
CREATE TABLE IF NOT EXISTS "voice_recording_locations" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "voice_recording_id" integer NOT NULL, "location_id" integer NOT NULL, "confidence" varchar DEFAULT 'medium', "source" varchar, "context" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_5ad0e601a6"
FOREIGN KEY ("voice_recording_id")
  REFERENCES "voice_recordings" ("id")
, CONSTRAINT "fk_rails_9d6f9aa564"
FOREIGN KEY ("location_id")
  REFERENCES "locations" ("id")
);
CREATE INDEX "index_voice_recording_locations_on_voice_recording_id" ON "voice_recording_locations" ("voice_recording_id");
CREATE INDEX "index_voice_recording_locations_on_location_id" ON "voice_recording_locations" ("location_id");
CREATE UNIQUE INDEX "idx_vr_locations_unique" ON "voice_recording_locations" ("voice_recording_id", "location_id");
CREATE VIRTUAL TABLE fts_dictionary_entries USING fts5 (translation, word_or_phrase, content='dictionary_entries', content_rowid='id', tokenize='porter unicode61')
/* fts_dictionary_entries(translation,word_or_phrase) */;
CREATE TABLE IF NOT EXISTS 'fts_dictionary_entries_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'fts_dictionary_entries_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'fts_dictionary_entries_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'fts_dictionary_entries_config'(k PRIMARY KEY, v) WITHOUT ROWID;
CREATE VIRTUAL TABLE fts_tags USING fts5 (name, content='tags', content_rowid='id', tokenize='porter unicode61')
/* fts_tags(name) */;
CREATE TABLE IF NOT EXISTS 'fts_tags_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'fts_tags_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'fts_tags_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'fts_tags_config'(k PRIMARY KEY, v) WITHOUT ROWID;
CREATE VIRTUAL TABLE fts_users USING fts5 (name, content='users', content_rowid='id', tokenize='porter unicode61')
/* fts_users(name) */;
CREATE TABLE IF NOT EXISTS 'fts_users_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'fts_users_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'fts_users_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'fts_users_config'(k PRIMARY KEY, v) WITHOUT ROWID;
CREATE TRIGGER insert_search AFTER INSERT ON dictionary_entries BEGIN
        INSERT INTO fts_dictionary_entries(rowid, translation, word_or_phrase)
        VALUES (new.id, new.translation, new.word_or_phrase);
      END;
CREATE TRIGGER delete_search AFTER DELETE ON dictionary_entries BEGIN
        INSERT INTO fts_dictionary_entries(fts_dictionary_entries, rowid, translation, word_or_phrase)
        VALUES('delete', old.id, old.translation, old.word_or_phrase);
      END;
CREATE TRIGGER update_search AFTER UPDATE ON dictionary_entries BEGIN
        INSERT INTO fts_dictionary_entries(fts_dictionary_entries, rowid, translation, word_or_phrase)
        VALUES('delete', old.id, old.translation, old.word_or_phrase);
        INSERT INTO fts_dictionary_entries(rowid, translation, word_or_phrase)
        VALUES (new.id, new.translation, new.word_or_phrase);
      END;
CREATE TRIGGER insert_tags_search AFTER INSERT ON tags BEGIN
        INSERT INTO fts_tags(rowid, name) VALUES (new.id, new.name);
      END;
CREATE TRIGGER delete_tags_search AFTER DELETE ON tags BEGIN
        INSERT INTO fts_tags(fts_tags, rowid, name) VALUES('delete', old.id, old.name);
      END;
CREATE TRIGGER update_tags_search AFTER UPDATE ON tags BEGIN
        INSERT INTO fts_tags(fts_tags, rowid, name) VALUES('delete', old.id, old.name);
        INSERT INTO fts_tags(rowid, name) VALUES (new.id, new.name);
      END;
CREATE TRIGGER insert_users_search AFTER INSERT ON users BEGIN
        INSERT INTO fts_users(rowid, name) VALUES (new.id, new.name);
      END;
CREATE TRIGGER delete_users_search AFTER DELETE ON users BEGIN
        INSERT INTO fts_users(fts_users, rowid, name) VALUES('delete', old.id, old.name);
      END;
CREATE TRIGGER update_users_search AFTER UPDATE ON users BEGIN
        INSERT INTO fts_users(fts_users, rowid, name) VALUES('delete', old.id, old.name);
        INSERT INTO fts_users(rowid, name) VALUES (new.id, new.name);
      END;
INSERT INTO "schema_migrations" (version) VALUES
('20260331221515'),
('20260331213148'),
('20260322233134'),
('20260320000000'),
('20260218000002'),
('20260218000001'),
('20251226142218'),
('20251226142210'),
('20251226142159'),
('20251111235455'),
('20251004091850'),
('20250926144748'),
('20250914093447'),
('20250830155023'),
('20250705152641'),
('20250613220803'),
('20250317123416'),
('20250202125612'),
('20250116000000'),
('20240606222923'),
('20240606214028'),
('20240603152657'),
('20240217154311'),
('20240124220629'),
('20240110001142'),
('20231124073827'),
('20231124072402'),
('20231120132429'),
('20231117183654'),
('20231019201218'),
('20231019184955'),
('20231018101336'),
('20231018101326'),
('20231018101303'),
('20231018094753'),
('20231018094006'),
('20231018093109'),
('20230610165707'),
('20230610165706'),
('20230610165705'),
('20230607103341'),
('20230602173347'),
('20230521083532'),
('20230520230902'),
('20230520225609'),
('20230520225514'),
('20230513192136'),
('20230513191223'),
('20230513191222'),
('20230507214107'),
('20230507101133'),
('20230505221350'),
('20230505221343'),
('20230504215105'),
('20230504202847'),
('20230504194720'),
('20220806112054'),
('20211124121026'),
('20211124121018'),
('20211115211538'),
('20211115211537'),
('20211115211536'),
('20211115211535'),
('20211115211534'),
('20211115211533'),
('20211115211532'),
('20210430225908'),
('20210430214138'),
('20210405125825'),
('20210404211139'),
('20210330071423'),
('20210330061411'),
('20210329175108'),
('20210328154827'),
('20210221145044'),
('20210221115334'),
('20210210175509'),
('20210210153031');


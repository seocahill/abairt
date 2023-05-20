CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE sqlite_sequence(name,seq);
CREATE TABLE IF NOT EXISTS "active_storage_blobs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "key" varchar NOT NULL, "filename" varchar NOT NULL, "content_type" varchar, "metadata" text, "service_name" varchar NOT NULL, "byte_size" bigint NOT NULL, "checksum" varchar NOT NULL, "created_at" datetime NOT NULL);
CREATE UNIQUE INDEX "index_active_storage_blobs_on_key" ON "active_storage_blobs" ("key");
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
CREATE TABLE IF NOT EXISTS "users" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "email" varchar, "name" varchar, "password_digest" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "confirmed" boolean DEFAULT 0 NOT NULL, "token" varchar, "master_id" bigint, "grupa_id" bigint, "lat_lang" varchar, "role" integer DEFAULT 0 NOT NULL, "voice" integer DEFAULT 0 NOT NULL, "dialect" integer DEFAULT 0 NOT NULL);
CREATE TABLE IF NOT EXISTS "rangs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar, "user_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "url" varchar, "meeting_id" varchar, "time" datetime, "grupa_id" varchar, "start_time" datetime, "end_time" datetime, CONSTRAINT "fk_rails_0f519c8255"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_rangs_on_user_id" ON "rangs" ("user_id");
CREATE TABLE IF NOT EXISTS "rang_entries" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "rang_id" integer NOT NULL, "dictionary_entry_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_3dfa1b15d2"
FOREIGN KEY ("rang_id")
  REFERENCES "rangs" ("id")
, CONSTRAINT "fk_rails_6e0c965f93"
FOREIGN KEY ("dictionary_entry_id")
  REFERENCES "dictionary_entries" ("id")
);
CREATE INDEX "index_rang_entries_on_rang_id" ON "rang_entries" ("rang_id");
CREATE INDEX "index_rang_entries_on_dictionary_entry_id" ON "rang_entries" ("dictionary_entry_id");
CREATE INDEX "index_users_on_token" ON "users" ("token");
CREATE INDEX "index_users_on_master_id" ON "users" ("master_id");
CREATE VIRTUAL TABLE fts_dictionary_entries USING fts5(translation, word_or_phrase, content='dictionary_entries', content_rowid='id', tokenize='porter unicode61')
/* fts_dictionary_entries(translation,word_or_phrase) */;
CREATE TABLE IF NOT EXISTS 'fts_dictionary_entries_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'fts_dictionary_entries_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'fts_dictionary_entries_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'fts_dictionary_entries_config'(k PRIMARY KEY, v) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS "grupas" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "ainm" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "muinteoir_id" bigint, "lat_lang" varchar);
CREATE INDEX "index_rangs_on_grupa_id" ON "rangs" ("grupa_id");
CREATE INDEX "index_grupas_on_muinteoir_id" ON "grupas" ("muinteoir_id");
CREATE INDEX "index_users_on_grupa_id" ON "users" ("grupa_id");
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
CREATE VIRTUAL TABLE fts_tags USING fts5(name, content='tags', content_rowid='id', tokenize='porter unicode61')
/* fts_tags(name) */;
CREATE TABLE IF NOT EXISTS 'fts_tags_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'fts_tags_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'fts_tags_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'fts_tags_config'(k PRIMARY KEY, v) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS "voice_recordings" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "title" varchar, "description" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "conversations" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "voice_recording_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_7c15d62a0a"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
, CONSTRAINT "fk_rails_187b29de5c"
FOREIGN KEY ("voice_recording_id")
  REFERENCES "voice_recordings" ("id")
);
CREATE INDEX "index_conversations_on_user_id" ON "conversations" ("user_id");
CREATE INDEX "index_conversations_on_voice_recording_id" ON "conversations" ("voice_recording_id");
CREATE TABLE IF NOT EXISTS "seomras" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "rang_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_fd2aba50f7"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
, CONSTRAINT "fk_rails_303227eb17"
FOREIGN KEY ("rang_id")
  REFERENCES "rangs" ("id")
);
CREATE INDEX "index_seomras_on_user_id" ON "seomras" ("user_id");
CREATE INDEX "index_seomras_on_rang_id" ON "seomras" ("rang_id");
CREATE VIRTUAL TABLE fts_users USING fts5(name, content='users', content_rowid='id', tokenize='porter unicode61')
/* fts_users(name) */;
CREATE TABLE IF NOT EXISTS 'fts_users_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'fts_users_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'fts_users_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'fts_users_config'(k PRIMARY KEY, v) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS "dictionary_entries" ("id" integer NOT NULL PRIMARY KEY, "word_or_phrase" varchar DEFAULT NULL, "translation" varchar DEFAULT NULL, "notes" varchar DEFAULT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "recall_date" datetime DEFAULT NULL, "previous_inteval" integer DEFAULT 0 NOT NULL, "previous_easiness_factor" decimal DEFAULT 2.5 NOT NULL, "committed_to_memory" boolean DEFAULT 0 NOT NULL, "status" integer DEFAULT 0 NOT NULL, "region_start" decimal DEFAULT NULL, "region_end" decimal DEFAULT NULL, "region_id" varchar DEFAULT NULL, "voice_recording_id" integer DEFAULT NULL, "speaker_id" integer DEFAULT NULL);
CREATE INDEX "index_dictionary_entries_on_voice_recording_id" ON "dictionary_entries" ("voice_recording_id");
CREATE INDEX "index_dictionary_entries_on_speaker_id" ON "dictionary_entries" ("speaker_id");
CREATE TABLE IF NOT EXISTS "word_lists" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar, "description" varchar, "starred" boolean, "user_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_4aed2b283b"
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
INSERT INTO "schema_migrations" (version) VALUES
('20210210153031'),
('20210210175509'),
('20210221115334'),
('20210221145044'),
('20210221153422'),
('20210221153458'),
('20210328154827'),
('20210329172250'),
('20210329175108'),
('20210330061411'),
('20210330071423'),
('20210403122717'),
('20210404211139'),
('20210405125825'),
('20210411102011'),
('20210430214138'),
('20210430225908'),
('20211017103718'),
('20211017103800'),
('20211103171821'),
('20211104165849'),
('20211104180311'),
('20211115211532'),
('20211115211533'),
('20211115211534'),
('20211115211535'),
('20211115211536'),
('20211115211537'),
('20211115211538'),
('20211124121018'),
('20211124121026'),
('20220806112054'),
('20220813144613'),
('20230504194720'),
('20230504195104'),
('20230504202847'),
('20230504214031'),
('20230504215105'),
('20230505221343'),
('20230505221350'),
('20230507101133'),
('20230507214107'),
('20230513191222'),
('20230513191223'),
('20230513192136');



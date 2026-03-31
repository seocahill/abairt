# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_31_213148) do
  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.integer "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.string "name", null: false
    t.integer "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", precision: nil, null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.integer "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "dictionary_entries", force: :cascade do |t|
    t.integer "accuracy_status", default: 0, null: false
    t.datetime "created_at", null: false
    t.text "notes"
    t.integer "quality", default: 0, null: false
    t.decimal "region_end"
    t.string "region_id"
    t.decimal "region_start"
    t.integer "speaker_id"
    t.string "standard_irish"
    t.integer "status", default: 0, null: false
    t.string "translation"
    t.integer "translator_id"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "voice_recording_id"
    t.string "word_or_phrase"
    t.index ["speaker_id"], name: "index_dictionary_entries_on_speaker_id"
    t.index ["translator_id"], name: "index_dictionary_entries_on_translator_id"
    t.index ["user_id"], name: "index_dictionary_entries_on_user_id"
    t.index ["voice_recording_id"], name: "index_dictionary_entries_on_voice_recording_id"
  end

  create_table "emails", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "message"
    t.datetime "sent_at"
    t.integer "sent_by_id", null: false
    t.string "subject"
    t.datetime "updated_at", null: false
    t.index ["sent_by_id"], name: "index_emails_on_sent_by_id"
  end

  create_table "locations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "dialect_region", default: 0, null: false
    t.string "irish_name"
    t.decimal "latitude", precision: 10, scale: 7
    t.integer "location_type", default: 0, null: false
    t.decimal "longitude", precision: 10, scale: 7
    t.string "name", null: false
    t.integer "parent_id"
    t.datetime "updated_at", null: false
    t.index ["dialect_region"], name: "index_locations_on_dialect_region"
    t.index ["name"], name: "index_locations_on_name"
    t.index ["parent_id"], name: "index_locations_on_parent_id"
  end

  create_table "media_imports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.text "error_message"
    t.text "headline"
    t.datetime "imported_at"
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["status"], name: "index_media_imports_on_status"
    t.index ["url"], name: "index_media_imports_on_url", unique: true
  end

  create_table "service_statuses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.decimal "response_time", precision: 10, scale: 3
    t.string "service_name", null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_service_statuses_on_created_at"
    t.index ["service_name", "created_at"], name: "index_service_statuses_on_service_name_and_created_at"
    t.index ["service_name"], name: "index_service_statuses_on_service_name"
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key"
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  create_table "taggings", force: :cascade do |t|
    t.string "context", limit: 128
    t.datetime "created_at", precision: nil
    t.integer "tag_id"
    t.integer "taggable_id"
    t.string "taggable_type"
    t.integer "tagger_id"
    t.string "tagger_type"
    t.string "tenant", limit: 128
    t.index ["context"], name: "index_taggings_on_context"
    t.index ["tag_id", "taggable_id", "taggable_type", "context", "tagger_id", "tagger_type"], name: "taggings_idx", unique: true
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
    t.index ["taggable_id", "taggable_type", "context"], name: "taggings_taggable_context_idx"
    t.index ["taggable_id", "taggable_type", "tagger_id", "context"], name: "taggings_idy"
    t.index ["taggable_id"], name: "index_taggings_on_taggable_id"
    t.index ["taggable_type"], name: "index_taggings_on_taggable_type"
    t.index ["tagger_id", "tagger_type"], name: "index_taggings_on_tagger_id_and_tagger_type"
    t.index ["tagger_id"], name: "index_taggings_on_tagger_id"
    t.index ["tenant"], name: "index_taggings_on_tenant"
  end

  create_table "tags", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.string "name"
    t.integer "taggings_count", default: 0
    t.datetime "updated_at", precision: nil
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "user_lists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "word_list_id", null: false
    t.index ["user_id"], name: "index_user_lists_on_user_id"
    t.index ["word_list_id"], name: "index_user_lists_on_word_list_id"
  end

  create_table "users", force: :cascade do |t|
    t.integer "ability", default: 0, null: false
    t.text "about"
    t.string "address"
    t.string "api_token"
    t.boolean "confirmed", default: false, null: false
    t.datetime "created_at", null: false
    t.integer "dialect", default: 0, null: false
    t.string "email"
    t.string "lat_lang"
    t.integer "location_id"
    t.string "login_token"
    t.bigint "master_id"
    t.string "name"
    t.integer "role", default: 0, null: false
    t.string "token"
    t.datetime "updated_at", null: false
    t.integer "voice", default: 0, null: false
    t.index ["api_token"], name: "index_users_on_api_token", unique: true
    t.index ["location_id"], name: "index_users_on_location_id"
    t.index ["master_id"], name: "index_users_on_master_id"
    t.index ["token"], name: "index_users_on_token"
  end

# Could not dump table "vec_dictionary_entry_embeddings_vector_chunks00" because of following StandardError
#   Unknown type '' for column 'rowid'


  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.json "object"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  create_table "voice_recording_locations", force: :cascade do |t|
    t.string "confidence", default: "medium"
    t.text "context"
    t.datetime "created_at", null: false
    t.integer "location_id", null: false
    t.string "source"
    t.datetime "updated_at", null: false
    t.integer "voice_recording_id", null: false
    t.index ["location_id"], name: "index_voice_recording_locations_on_location_id"
    t.index ["voice_recording_id", "location_id"], name: "idx_vr_locations_unique", unique: true
    t.index ["voice_recording_id"], name: "index_voice_recording_locations_on_voice_recording_id"
  end

  create_table "voice_recordings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.json "diarization_data"
    t.string "diarization_status"
    t.integer "dictionary_entries_count", default: 0, null: false
    t.float "duration_seconds", default: 0.0, null: false
    t.string "import_status"
    t.integer "location_id"
    t.json "metadata_analysis"
    t.json "peaks"
    t.string "title"
    t.text "transcription"
    t.text "transcription_en"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["diarization_status"], name: "index_voice_recordings_on_diarization_status"
    t.index ["location_id"], name: "index_voice_recordings_on_location_id"
    t.index ["user_id"], name: "index_voice_recordings_on_user_id"
  end

  create_table "word_list_dictionary_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "dictionary_entry_id", null: false
    t.datetime "updated_at", null: false
    t.integer "word_list_id", null: false
    t.index ["dictionary_entry_id"], name: "index_word_list_dictionary_entries_on_dictionary_entry_id"
    t.index ["word_list_id"], name: "index_word_list_dictionary_entries_on_word_list_id"
  end

  create_table "word_lists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "name"
    t.text "script"
    t.boolean "starred"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_word_lists_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "dictionary_entries", "users"
  add_foreign_key "dictionary_entries", "users", column: "translator_id"
  add_foreign_key "emails", "users", column: "sent_by_id"
  add_foreign_key "taggings", "tags"
  add_foreign_key "user_lists", "users"
  add_foreign_key "user_lists", "word_lists"
  add_foreign_key "voice_recording_locations", "locations"
  add_foreign_key "voice_recording_locations", "voice_recordings"
  add_foreign_key "voice_recordings", "users"
  add_foreign_key "word_list_dictionary_entries", "dictionary_entries"
  add_foreign_key "word_list_dictionary_entries", "word_lists"
  add_foreign_key "word_lists", "users"

  # Virtual tables defined in this database.
  # Note that virtual tables may not work with other database engines. Be careful if changing database.
  create_virtual_table "fts_dictionary_entries", "fts5", ["translation", "word_or_phrase", "content='dictionary_entries'", "content_rowid='id'", "tokenize='porter unicode61'"]
  create_virtual_table "fts_tags", "fts5", ["name", "content='tags'", "content_rowid='id'", "tokenize='porter unicode61'"]
  create_virtual_table "fts_users", "fts5", ["name", "content='users'", "content_rowid='id'", "tokenize='porter unicode61'"]

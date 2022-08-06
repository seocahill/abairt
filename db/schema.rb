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

ActiveRecord::Schema.define(version: 2022_08_06_112054) do

  create_table "_litestream_lock", id: false, force: :cascade do |t|
    t.integer "id"
  end

  create_table "_litestream_seq", force: :cascade do |t|
    t.integer "seq"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.string "record_type", limit: 255, null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", limit: 255, null: false
    t.string "filename", limit: 255, null: false
    t.string "content_type", limit: 255
    t.text "metadata"
    t.string "service_name", limit: 255, null: false
    t.bigint "byte_size", null: false
    t.string "checksum", limit: 255, null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", limit: 255, null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "dictionary_entries", force: :cascade do |t|
    t.string "word_or_phrase", limit: 255
    t.string "translation", limit: 255
    t.string "notes", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "recall_date"
    t.integer "previous_inteval", default: 0, null: false
    t.decimal "previous_easiness_factor", default: "2.5", null: false
    t.boolean "committed_to_memory", default: false, null: false
    t.integer "status", default: 0, null: false
    t.decimal "region_start"
    t.decimal "region_end"
    t.string "region_id"
  end

# Could not dump table "fts_dictionary_entries" because of following StandardError
#   Unknown type '' for column 'translation'

# Could not dump table "fts_dictionary_entries_config" because of following StandardError
#   Unknown type '' for column 'k'

  create_table "fts_dictionary_entries_data", force: :cascade do |t|
    t.binary "block"
  end

  create_table "fts_dictionary_entries_docsize", force: :cascade do |t|
    t.binary "sz"
  end

# Could not dump table "fts_dictionary_entries_idx" because of following StandardError
#   Unknown type '' for column 'segid'

# Could not dump table "fts_tags" because of following StandardError
#   Unknown type '' for column 'name'

# Could not dump table "fts_tags_config" because of following StandardError
#   Unknown type '' for column 'k'

  create_table "fts_tags_data", force: :cascade do |t|
    t.binary "block"
  end

  create_table "fts_tags_docsize", force: :cascade do |t|
    t.binary "sz"
  end

# Could not dump table "fts_tags_idx" because of following StandardError
#   Unknown type '' for column 'segid'

  create_table "grupas", force: :cascade do |t|
    t.string "ainm"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "muinteoir_id"
    t.index ["muinteoir_id"], name: "index_grupas_on_muinteoir_id"
  end

  create_table "rang_entries", force: :cascade do |t|
    t.bigint "rang_id", null: false
    t.bigint "dictionary_entry_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dictionary_entry_id"], name: "index_rang_entries_on_dictionary_entry_id"
    t.index ["rang_id"], name: "index_rang_entries_on_rang_id"
  end

  create_table "rangs", force: :cascade do |t|
    t.string "name", limit: 255
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "url", limit: 255
    t.string "meeting_id", limit: 255
    t.datetime "time"
    t.string "grupa_id"
    t.datetime "start_time"
    t.datetime "end_time"
    t.index ["grupa_id"], name: "index_rangs_on_grupa_id"
    t.index ["user_id"], name: "index_rangs_on_user_id"
  end

  create_table "taggings", force: :cascade do |t|
    t.integer "tag_id"
    t.string "taggable_type"
    t.integer "taggable_id"
    t.string "tagger_type"
    t.integer "tagger_id"
    t.string "context", limit: 128
    t.datetime "created_at"
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
    t.string "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "taggings_count", default: 0
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", limit: 255
    t.string "name", limit: 255
    t.string "password_digest", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "confirmed", default: false, null: false
    t.string "token", limit: 255
    t.bigint "master_id"
    t.bigint "grupa_id"
    t.index ["grupa_id"], name: "index_users_on_grupa_id"
    t.index ["master_id"], name: "index_users_on_master_id"
    t.index ["token"], name: "index_users_on_token"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "rang_entries", "dictionary_entries"
  add_foreign_key "rang_entries", "rangs"
  add_foreign_key "rangs", "users"
  add_foreign_key "taggings", "tags"
end

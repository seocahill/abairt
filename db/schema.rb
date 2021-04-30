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

ActiveRecord::Schema.define(version: 2021_04_30_214138) do

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
  end

# Could not dump table "fts_idx" because of following StandardError
#   Unknown type '' for column 'translation'

# Could not dump table "fts_idx_config" because of following StandardError
#   Unknown type '' for column 'k'

  create_table "fts_idx_data", force: :cascade do |t|
    t.binary "block"
  end

  create_table "fts_idx_docsize", force: :cascade do |t|
    t.binary "sz"
  end

# Could not dump table "fts_idx_idx" because of following StandardError
#   Unknown type '' for column 'segid'

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
    t.index ["user_id"], name: "index_rangs_on_user_id"
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
    t.index ["master_id"], name: "index_users_on_master_id"
    t.index ["token"], name: "index_users_on_token"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "rang_entries", "dictionary_entries"
  add_foreign_key "rang_entries", "rangs"
  add_foreign_key "rangs", "users"
end

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

ActiveRecord::Schema[8.1].define(version: 2026_08_28_210000) do
  create_table "collections", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "hlc"
    t.bigint "index_position"
    t.string "name", null: false
    t.bigint "server_seq"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["server_seq"], name: "index_collections_on_server_seq"
    t.index ["user_id", "index_position"], name: "index_collections_on_user_id_and_index_position", unique: true, where: "deleted_at IS NULL AND index_position IS NOT NULL"
    t.index ["user_id"], name: "index_collections_on_user_id"
    t.check_constraint "deleted_at IS NOT NULL OR index_position IS NOT NULL", name: "collections_kept_index_position_present"
    t.check_constraint "index_position IS NULL OR index_position > 0", name: "collections_index_position_positive"
  end

  create_table "entries", id: :string, force: :cascade do |t|
    t.string "collection_id"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "hlc"
    t.string "kind", null: false
    t.string "migrated_from_id"
    t.date "occurs_on"
    t.string "page_kind", null: false
    t.date "page_on"
    t.string "parent_id"
    t.boolean "priority", default: false, null: false
    t.bigint "server_seq"
    t.string "state"
    t.json "tags", default: [], null: false
    t.text "text", null: false
    t.string "time_of_day"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["collection_id"], name: "index_entries_on_collection_id"
    t.index ["migrated_from_id"], name: "index_entries_on_migrated_from_id", unique: true
    t.index ["parent_id"], name: "index_entries_on_parent_id"
    t.index ["server_seq"], name: "index_entries_on_server_seq"
    t.index ["user_id", "occurs_on"], name: "index_entries_on_user_id_and_occurs_on"
    t.index ["user_id", "page_kind", "page_on"], name: "index_entries_on_user_id_and_page_kind_and_page_on"
    t.index ["user_id", "state"], name: "index_entries_on_user_id_and_state"
    t.index ["user_id"], name: "index_entries_on_user_id"
    t.check_constraint "page_kind IN ('daily', 'monthly_calendar', 'monthly_tasks', 'future', 'collection')", name: "entries_page_kind_allowed"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "collections", "users"
  add_foreign_key "entries", "collections"
  add_foreign_key "entries", "entries", column: "migrated_from_id"
  add_foreign_key "entries", "entries", column: "parent_id"
  add_foreign_key "entries", "users"
  add_foreign_key "sessions", "users"
end

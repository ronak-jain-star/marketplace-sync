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

ActiveRecord::Schema[8.0].define(version: 2026_05_28_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "channel_listings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "sku", null: false
    t.string "channel", null: false
    t.string "external_id"
    t.bigint "desired_version", default: 0, null: false
    t.bigint "applied_version", default: 0, null: false
    t.string "status", default: "pending", null: false
    t.text "last_error"
    t.datetime "last_synced_at"
    t.datetime "next_retry_at"
    t.integer "retry_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["channel", "status", "next_retry_at"], name: "index_channel_listings_on_channel_and_status_and_next_retry_at"
    t.index ["sku", "channel"], name: "index_channel_listings_on_sku_and_channel", unique: true
  end

  create_table "listing_events", force: :cascade do |t|
    t.string "sku", null: false
    t.string "channel", null: false
    t.bigint "version", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "published_at"
    t.index ["published_at"], name: "index_listing_events_on_published_at"
    t.index ["sku", "channel", "version"], name: "index_listing_events_on_sku_and_channel_and_version", unique: true
  end

  create_table "listings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "sku", null: false
    t.string "seller_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "brand"
    t.string "category"
    t.integer "price_cents", default: 0, null: false
    t.string "currency", default: "USD", null: false
    t.integer "inventory_qty", default: 0, null: false
    t.jsonb "attributes_data", default: {}, null: false
    t.bigint "version", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["seller_id", "updated_at"], name: "index_listings_on_seller_id_and_updated_at"
    t.index ["sku"], name: "index_listings_on_sku", unique: true
  end
end

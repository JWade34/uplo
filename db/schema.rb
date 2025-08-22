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

ActiveRecord::Schema[8.0].define(version: 2025_08_22_190037) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "analytics_summaries", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "total_posts"
    t.decimal "avg_engagement_rate", precision: 5, scale: 2
    t.bigint "best_performing_post_id"
    t.integer "followers_gained"
    t.date "period_start"
    t.date "period_end"
    t.string "tier_at_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["best_performing_post_id"], name: "index_analytics_summaries_on_best_performing_post_id"
    t.index ["user_id"], name: "index_analytics_summaries_on_user_id"
  end

  create_table "captions", force: :cascade do |t|
    t.bigint "photo_id", null: false
    t.text "content"
    t.string "style"
    t.datetime "generated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["photo_id"], name: "index_captions_on_photo_id"
  end

  create_table "early_access_signups", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "business_type"
    t.text "current_challenge"
    t.boolean "marketing_emails"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "photos", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title"
    t.text "description"
    t.string "filename"
    t.string "content_type"
    t.integer "file_size"
    t.boolean "processed", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "metadata"
    t.index ["processed"], name: "index_photos_on_processed"
    t.index ["user_id", "created_at"], name: "index_photos_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_photos_on_user_id"
  end

  create_table "post_performances", force: :cascade do |t|
    t.bigint "photo_id", null: false
    t.string "platform"
    t.integer "likes"
    t.integer "comments"
    t.integer "shares"
    t.integer "reach"
    t.decimal "engagement_rate", precision: 5, scale: 2
    t.datetime "posted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["photo_id"], name: "index_post_performances_on_photo_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "stripe_subscription_id", null: false
    t.string "stripe_customer_id", null: false
    t.string "status", default: "incomplete", null: false
    t.datetime "current_period_start"
    t.datetime "current_period_end"
    t.datetime "trial_end"
    t.decimal "amount", precision: 8, scale: 2
    t.string "interval", default: "month"
    t.string "plan_name", default: "pro"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["stripe_customer_id"], name: "index_subscriptions_on_stripe_customer_id"
    t.index ["stripe_subscription_id"], name: "index_subscriptions_on_stripe_subscription_id", unique: true
    t.index ["user_id", "status"], name: "index_subscriptions_on_user_id_and_status"
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "bio"
    t.string "fitness_focus"
    t.string "target_audience"
    t.string "tone_preference"
    t.string "business_type"
    t.boolean "onboarding_completed", default: false
    t.text "client_pain_points"
    t.text "unique_approach"
    t.string "brand_personality"
    t.text "sample_caption"
    t.string "call_to_action_preference"
    t.string "location"
    t.string "price_range"
    t.string "posting_frequency"
    t.text "favorite_hashtags"
    t.text "words_to_avoid"
    t.string "subscription_tier", default: "starter"
    t.string "subscription_status", default: "trial"
    t.datetime "subscription_started_at"
    t.datetime "trial_ends_at"
    t.integer "monthly_photo_limit", default: 8
    t.integer "monthly_caption_limit", default: 5
    t.integer "current_month_photos", default: 0
    t.integer "current_month_captions", default: 0
    t.datetime "last_usage_reset", default: -> { "CURRENT_TIMESTAMP" }
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "analytics_summaries", "photos", column: "best_performing_post_id"
  add_foreign_key "analytics_summaries", "users"
  add_foreign_key "captions", "photos"
  add_foreign_key "photos", "users"
  add_foreign_key "post_performances", "photos"
  add_foreign_key "sessions", "users"
  add_foreign_key "subscriptions", "users"
end

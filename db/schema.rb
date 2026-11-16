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

ActiveRecord::Schema[8.1].define(version: 2026_11_16_123732) do
  create_table "audit_events", force: :cascade do |t|
    t.bigint "actor_id"
    t.bigint "user_id"
    t.string "user_email"
    t.string "action", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.string "request_id"
    t.json "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.index ["action", "created_at"], name: "index_audit_events_on_action_and_created_at"
    t.index ["actor_id", "created_at"], name: "index_audit_events_on_actor_id_and_created_at"
    t.index ["user_id", "created_at"], name: "index_audit_events_on_user_id_and_created_at"
  end

  create_table "recovery_codes", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "code_digest", null: false
    t.datetime "used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "code_digest"], name: "index_recovery_codes_on_user_id_and_code_digest", unique: true
    t.index ["user_id"], name: "index_recovery_codes_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_active_at", null: false
    t.index ["last_active_at"], name: "index_sessions_on_last_active_at"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "verified_at"
    t.integer "failed_login_attempts", default: 0, null: false
    t.datetime "locked_until"
    t.string "otp_secret"
    t.datetime "otp_enabled_at"
    t.integer "otp_last_used_at"
    t.string "role", default: "member", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.check_constraint "role IN ('member', 'manager', 'admin')", name: "users_role_check"
  end

  add_foreign_key "recovery_codes", "users"
  add_foreign_key "sessions", "users"
end

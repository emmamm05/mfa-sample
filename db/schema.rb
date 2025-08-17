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

ActiveRecord::Schema[8.0].define(version: 2025_08_17_050000) do
  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "name"
    t.string "password_salt", null: false
    t.string "password_hash", null: false
    t.integer "password_iterations", default: 120000, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "totp_secret"
    t.datetime "totp_enabled_at"
    t.text "backup_codes_hashes"
    t.string "backup_codes_salt"
    t.datetime "backup_codes_generated_at"
    t.index ["backup_codes_generated_at"], name: "index_users_on_backup_codes_generated_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["totp_enabled_at"], name: "index_users_on_totp_enabled_at"
  end

  create_table "webauthn_credentials", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "external_id", null: false
    t.text "public_key", null: false
    t.integer "sign_count", default: 0, null: false
    t.string "nickname"
    t.string "transports"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_webauthn_credentials_on_external_id", unique: true
    t.index ["user_id"], name: "index_webauthn_credentials_on_user_id"
  end

  add_foreign_key "webauthn_credentials", "users"
end

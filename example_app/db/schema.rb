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

ActiveRecord::Schema[8.0].define(version: 0) do
  create_table "awards", force: :cascade do |t|
    t.string "name", null: false
    t.integer "tournament_event_id", null: false
    t.integer "recipient_id", null: false
    t.string "recipient_type", null: false
    t.string "award_type", default: "placement", null: false
    t.integer "position"
    t.text "description"
    t.datetime "awarded_at", precision: nil, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index [ "award_type" ], name: "index_awards_on_award_type"
    t.index [ "position" ], name: "index_awards_on_position"
    t.index [ "recipient_id", "recipient_type" ], name: "index_awards_on_recipient"
    t.index [ "tournament_event_id" ], name: "index_awards_on_tournament_event_id"
  end

  create_table "event_types", force: :cascade do |t|
    t.string "name", null: false
    t.string "abbreviation"
    t.string "category", null: false
    t.string "participant_type", null: false
    t.integer "max_participants_per_match", default: 2, null: false
    t.text "description"
    t.string "rules_url"
    t.boolean "active", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index [ "category" ], name: "index_event_types_on_category"
    t.index [ "name" ], name: "index_event_types_on_name", unique: true
    t.index [ "participant_type" ], name: "index_event_types_on_participant_type"
  end

  create_table "judges", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "tournament_id", null: false
    t.string "experience_level", default: "novice", null: false
    t.text "certifications"
    t.text "preferences"
    t.text "availability"
    t.boolean "active", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index [ "tournament_id" ], name: "index_judges_on_tournament_id"
    t.index [ "user_id", "tournament_id" ], name: "index_judges_unique", unique: true
    t.index [ "user_id" ], name: "index_judges_on_user_id"
  end

  create_table "leagues", force: :cascade do |t|
    t.string "name", null: false
    t.string "abbreviation"
    t.text "description"
    t.string "website"
    t.string "contact_email"
    t.boolean "active", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index [ "name" ], name: "index_leagues_on_name", unique: true
  end

  create_table "match_judges", force: :cascade do |t|
    t.integer "match_id", null: false
    t.integer "judge_id", null: false
    t.string "role", default: "judge", null: false
    t.string "status", default: "assigned", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index [ "judge_id" ], name: "index_match_judges_on_judge_id"
    t.index [ "match_id", "judge_id" ], name: "index_match_judges_unique", unique: true
    t.index [ "match_id" ], name: "index_match_judges_on_match_id"
  end

  create_table "match_participants", force: :cascade do |t|
    t.integer "match_id", null: false
    t.integer "participant_id", null: false
    t.string "participant_type", null: false
    t.string "position"
    t.integer "speaking_order"
    t.decimal "score"
    t.integer "rank"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index [ "match_id", "participant_id", "participant_type" ], name: "index_match_participants_unique", unique: true
    t.index [ "match_id" ], name: "index_match_participants_on_match_id"
    t.index [ "participant_id", "participant_type" ], name: "index_match_participants_on_participant"
  end

  create_table "matches", force: :cascade do |t|
    t.integer "round_id", null: false
    t.integer "room_id"
    t.integer "match_number", null: false
    t.datetime "start_time", precision: nil
    t.datetime "end_time", precision: nil
    t.string "status", default: "scheduled", null: false
    t.integer "winner_id"
    t.string "winner_type"
    t.text "notes"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index [ "room_id" ], name: "index_matches_on_room_id"
    t.index [ "round_id", "match_number" ], name: "index_matches_on_match_number", unique: true
    t.index [ "round_id" ], name: "index_matches_on_round_id"
    t.index [ "start_time" ], name: "index_matches_on_start_time"
  end

  create_table "registrations", force: :cascade do |t|
    t.integer "tournament_event_id", null: false
    t.integer "participant_id", null: false
    t.string "participant_type", null: false
    t.datetime "registration_date", precision: nil, null: false
    t.string "status", default: "registered", null: false
    t.boolean "fee_paid", null: false
    t.datetime "payment_date", precision: nil
    t.text "notes"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index [ "participant_id", "participant_type" ], name: "index_registrations_on_participant"
    t.index [ "status" ], name: "index_registrations_on_status"
    t.index [ "tournament_event_id", "participant_id", "participant_type" ], name: "index_registrations_unique", unique: true
    t.index [ "tournament_event_id" ], name: "index_registrations_on_tournament_event_id"
  end

  create_table "rooms", force: :cascade do |t|
    t.integer "tournament_id", null: false
    t.string "name", null: false
    t.string "room_type", default: "physical", null: false
    t.integer "capacity"
    t.string "location"
    t.string "virtual_link"
    t.text "equipment"
    t.text "notes"
    t.boolean "available", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index [ "room_type" ], name: "index_rooms_on_room_type"
    t.index [ "tournament_id" ], name: "index_rooms_on_tournament_id"
  end

  create_table "rounds", force: :cascade do |t|
    t.integer "tournament_event_id", null: false
    t.integer "round_number", null: false
    t.string "name", null: false
    t.string "round_type", default: "preliminary", null: false
    t.datetime "start_time", precision: nil
    t.datetime "end_time", precision: nil
    t.string "status", default: "scheduled", null: false
    t.text "notes"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index [ "start_time" ], name: "index_rounds_on_start_time"
    t.index [ "tournament_event_id", "round_number" ], name: "index_rounds_on_round_number", unique: true
    t.index [ "tournament_event_id" ], name: "index_rounds_on_tournament_event_id"
  end

  create_table "seasons", force: :cascade do |t|
    t.string "name", null: false
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.boolean "active", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index [ "active" ], name: "index_seasons_on_active"
  end

  create_table "team_memberships", force: :cascade do |t|
    t.integer "team_id", null: false
    t.integer "user_id", null: false
    t.string "role", default: "member", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index [ "team_id", "user_id" ], name: "index_team_memberships_unique", unique: true
    t.index [ "team_id" ], name: "index_team_memberships_on_team_id"
    t.index [ "user_id" ], name: "index_team_memberships_on_user_id"
  end

  create_table "teams", force: :cascade do |t|
    t.string "name", null: false
    t.integer "league_id", null: false
    t.integer "season_id", null: false
    t.string "school"
    t.boolean "active", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index [ "league_id" ], name: "index_teams_on_league_id"
    t.index [ "season_id" ], name: "index_teams_on_season_id"
  end

  create_table "tournament_events", force: :cascade do |t|
    t.integer "tournament_id", null: false
    t.integer "event_type_id", null: false
    t.integer "max_participants"
    t.decimal "entry_fee"
    t.datetime "registration_deadline", precision: nil
    t.string "status", default: "open", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index [ "event_type_id" ], name: "index_tournament_events_on_event_type_id"
    t.index [ "tournament_id", "event_type_id" ], name: "index_tournament_events_unique", unique: true
    t.index [ "tournament_id" ], name: "index_tournament_events_on_tournament_id"
  end

  create_table "tournaments", force: :cascade do |t|
    t.string "name", null: false
    t.integer "league_id", null: false
    t.integer "season_id", null: false
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.string "location"
    t.string "format", default: "in_person", null: false
    t.datetime "registration_deadline", precision: nil
    t.integer "max_participants"
    t.decimal "entry_fee"
    t.string "status", default: "upcoming", null: false
    t.text "description"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index [ "league_id" ], name: "index_tournaments_on_league_id"
    t.index [ "season_id" ], name: "index_tournaments_on_season_id"
    t.index [ "start_date" ], name: "index_tournaments_on_start_date"
    t.index [ "status" ], name: "index_tournaments_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "email", null: false
    t.string "phone"
    t.string "school"
    t.integer "graduation_year"
    t.integer "league_id"
    t.string "role", default: "participant", null: false
    t.boolean "active", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index [ "email" ], name: "index_users_on_email", unique: true
    t.index [ "league_id" ], name: "index_users_on_league_id"
    t.index [ "role" ], name: "index_users_on_role"
  end

  add_foreign_key "awards", "tournament_events", on_delete: :cascade
  add_foreign_key "judges", "tournaments", on_delete: :cascade
  add_foreign_key "judges", "users", on_delete: :cascade
  add_foreign_key "match_judges", "judges", on_delete: :cascade
  add_foreign_key "match_judges", "matches", on_delete: :cascade
  add_foreign_key "match_participants", "matches", on_delete: :cascade
  add_foreign_key "matches", "rooms", on_delete: :nullify
  add_foreign_key "matches", "rounds", on_delete: :cascade
  add_foreign_key "registrations", "tournament_events", on_delete: :cascade
  add_foreign_key "rooms", "tournaments", on_delete: :cascade
  add_foreign_key "rounds", "tournament_events", on_delete: :cascade
  add_foreign_key "team_memberships", "teams", on_delete: :cascade
  add_foreign_key "team_memberships", "users", on_delete: :cascade
  add_foreign_key "teams", "leagues", on_delete: :cascade
  add_foreign_key "teams", "seasons", on_delete: :cascade
  add_foreign_key "tournament_events", "event_types", on_delete: :cascade
  add_foreign_key "tournament_events", "tournaments", on_delete: :cascade
  add_foreign_key "tournaments", "leagues", on_delete: :cascade
  add_foreign_key "tournaments", "seasons", on_delete: :cascade
  add_foreign_key "users", "leagues", on_delete: :nullify
end

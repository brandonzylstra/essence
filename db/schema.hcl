# Auto-generated Atlas HCL schema from db/schema.yaml
# Edit the YAML file and re-run the converter to update this file

schema "main" {}

table "leagues" {
  schema = schema.main
column "id" {
    null = false
    type = integer
    auto_increment = true
  }
column "created_at" {
    null = false
    type = datetime
  }
column "updated_at" {
    null = false
    type = datetime
  }
column "name" {
    null = false
    type = varchar(255)
  }
column "abbreviation" {
    null = true
    type = varchar(10)
  }
column "description" {
    null = true
    type = text
  }
column "website" {
    null = true
    type = varchar(500)
  }
column "contact_email" {
    null = true
    type = varchar(255)
  }
column "active" {
    null = false
    type = boolean
    default = true
  }
primary_key {
  columns = [column.id]
}
}

table "seasons" {
  schema = schema.main
column "id" {
    null = false
    type = integer
    auto_increment = true
  }
column "created_at" {
    null = false
    type = datetime
  }
column "updated_at" {
    null = false
    type = datetime
  }
column "name" {
    null = false
    type = varchar(100)
  }
column "start_date" {
    null = false
    type = date
  }
column "end_date" {
    null = false
    type = date
  }
column "active" {
    null = false
    type = boolean
    default = false
  }
primary_key {
  columns = [column.id]
}
index "index_seasons_on_active" {
  columns = [column.active]
}
}

table "users" {
  schema = schema.main
column "id" {
    null = false
    type = integer
    auto_increment = true
  }
column "created_at" {
    null = false
    type = datetime
  }
column "updated_at" {
    null = false
    type = datetime
  }
column "first_name" {
    null = false
    type = varchar(100)
  }
column "last_name" {
    null = false
    type = varchar(100)
  }
column "email" {
    null = false
    type = varchar(255)
  }
column "phone" {
    null = true
    type = varchar(20)
  }
column "school" {
    null = true
    type = varchar(255)
  }
column "graduation_year" {
    null = true
    type = integer
  }
column "league_id" {
    null = true
    type = integer
  }
column "role" {
    null = false
    type = varchar(20)
    default = "participant"
  }
column "active" {
    null = false
    type = boolean
    default = true
  }
column "last_login_at" {
    null = false
    type = datetime
  }
primary_key {
  columns = [column.id]
}
foreign_key "fk_users_league_id" {
  columns = [column.league_id]
  ref_columns = [table.leagues.column.id]
    on_delete = CASCADE
  }
index "index_users_on_email" {
  columns = [column.email]
}
index "index_users_on_league_id" {
  columns = [column.league_id]
}
index "index_users_on_role" {
  columns = [column.role]
}
}

table "teams" {
  schema = schema.main
column "id" {
    null = false
    type = integer
    auto_increment = true
  }
column "created_at" {
    null = false
    type = datetime
  }
column "updated_at" {
    null = false
    type = datetime
  }
column "name" {
    null = false
    type = varchar(255)
  }
column "league_id" {
    null = true
    type = integer
  }
column "season_id" {
    null = true
    type = integer
  }
column "school" {
    null = true
    type = varchar(255)
  }
column "active" {
    null = false
    type = boolean
    default = true
  }
primary_key {
  columns = [column.id]
}
foreign_key "fk_teams_league_id" {
  columns = [column.league_id]
  ref_columns = [table.leagues.column.id]
    on_delete = CASCADE
  }
foreign_key "fk_teams_season_id" {
  columns = [column.season_id]
  ref_columns = [table.seasons.column.id]
    on_delete = CASCADE
  }
index "index_teams_on_league_id" {
  columns = [column.league_id]
}
index "index_teams_on_season_id" {
  columns = [column.season_id]
}
}

table "team_memberships" {
  schema = schema.main
column "id" {
    null = false
    type = integer
    auto_increment = true
  }
column "created_at" {
    null = false
    type = datetime
  }
column "updated_at" {
    null = false
    type = datetime
  }
column "team_id" {
    null = true
    type = integer
  }
column "user_id" {
    null = true
    type = integer
  }
column "role" {
    null = false
    type = varchar(50)
    default = "member"
  }
primary_key {
  columns = [column.id]
}
foreign_key "fk_team_memberships_team_id" {
  columns = [column.team_id]
  ref_columns = [table.teams.column.id]
    on_delete = CASCADE
  }
foreign_key "fk_team_memberships_user_id" {
  columns = [column.user_id]
  ref_columns = [table.users.column.id]
    on_delete = CASCADE
  }
index "index_team_memberships_on_team_id" {
  columns = [column.team_id]
}
index "index_team_memberships_on_user_id" {
  columns = [column.user_id]
}
index "index_team_memberships_on_team_id_and_user_id_unique" {
  columns = [column.team_id, column.user_id]
    unique = true
  }
}

table "event_types" {
  schema = schema.main
column "id" {
    null = false
    type = integer
    auto_increment = true
  }
column "created_at" {
    null = false
    type = datetime
  }
column "updated_at" {
    null = false
    type = datetime
  }
column "name" {
    null = false
    type = varchar(100)
  }
column "abbreviation" {
    null = true
    type = varchar(10)
  }
column "category" {
    null = false
    type = varchar(20)
  }
column "participant_type" {
    null = false
    type = varchar(20)
  }
column "max_participants_per_match" {
    null = false
    type = integer
    default = 2
  }
column "description" {
    null = true
    type = text
  }
column "rules_url" {
    null = true
    type = varchar(500)
  }
column "active" {
    null = false
    type = boolean
    default = true
  }
primary_key {
  columns = [column.id]
}
index "index_event_types_on_category" {
  columns = [column.category]
}
index "index_event_types_on_participant_type" {
  columns = [column.participant_type]
}
}

table "tournaments" {
  schema = schema.main
column "id" {
    null = false
    type = integer
    auto_increment = true
  }
column "created_at" {
    null = false
    type = datetime
  }
column "updated_at" {
    null = false
    type = datetime
  }
column "name" {
    null = false
    type = varchar(255)
  }
column "league_id" {
    null = true
    type = integer
  }
column "season_id" {
    null = true
    type = integer
  }
column "start_date" {
    null = false
    type = date
  }
column "end_date" {
    null = false
    type = date
  }
column "location" {
    null = true
    type = varchar(500)
  }
column "format" {
    null = false
    type = varchar(20)
    default = "in_person"
  }
column "registration_deadline_at" {
    null = false
    type = datetime
  }
column "max_participants" {
    null = true
    type = integer
  }
column "entry_fee" {
    null = true
    type = decimal(8,2)
  }
column "status" {
    null = false
    type = varchar(20)
    default = "upcoming"
  }
column "description" {
    null = true
    type = text
  }
primary_key {
  columns = [column.id]
}
foreign_key "fk_tournaments_league_id" {
  columns = [column.league_id]
  ref_columns = [table.leagues.column.id]
    on_delete = CASCADE
  }
foreign_key "fk_tournaments_season_id" {
  columns = [column.season_id]
  ref_columns = [table.seasons.column.id]
    on_delete = CASCADE
  }
index "index_tournaments_on_league_id" {
  columns = [column.league_id]
}
index "index_tournaments_on_season_id" {
  columns = [column.season_id]
}
index "index_tournaments_on_start_date" {
  columns = [column.start_date]
}
index "index_tournaments_on_status" {
  columns = [column.status]
}
}

table "tournament_events" {
  schema = schema.main
column "id" {
    null = false
    type = integer
    auto_increment = true
  }
column "created_at" {
    null = false
    type = datetime
  }
column "updated_at" {
    null = false
    type = datetime
  }
column "tournament_id" {
    null = true
    type = integer
  }
column "event_type_id" {
    null = true
    type = integer
  }
column "max_participants" {
    null = true
    type = integer
  }
column "entry_fee" {
    null = true
    type = decimal(8,2)
  }
column "registration_deadline_at" {
    null = false
    type = datetime
  }
column "status" {
    null = false
    type = varchar(20)
    default = "open"
  }
primary_key {
  columns = [column.id]
}
foreign_key "fk_tournament_events_tournament_id" {
  columns = [column.tournament_id]
  ref_columns = [table.tournaments.column.id]
    on_delete = CASCADE
  }
foreign_key "fk_tournament_events_event_type_id" {
  columns = [column.event_type_id]
  ref_columns = [table.event_types.column.id]
    on_delete = CASCADE
  }
index "index_tournament_events_on_tournament_id" {
  columns = [column.tournament_id]
}
index "index_tournament_events_on_event_type_id" {
  columns = [column.event_type_id]
}
index "index_tournament_events_on_tournament_id_and_event_type_id_unique" {
  columns = [column.tournament_id, column.event_type_id]
    unique = true
  }
}

table "rooms" {
  schema = schema.main
column "id" {
    null = false
    type = integer
    auto_increment = true
  }
column "created_at" {
    null = false
    type = datetime
  }
column "updated_at" {
    null = false
    type = datetime
  }
column "tournament_id" {
    null = true
    type = integer
  }
column "name" {
    null = false
    type = varchar(100)
  }
column "room_type" {
    null = false
    type = varchar(20)
    default = "physical"
  }
column "capacity" {
    null = true
    type = integer
  }
column "location" {
    null = true
    type = varchar(500)
  }
column "virtual_link" {
    null = true
    type = varchar(500)
  }
column "equipment" {
    null = true
    type = text
  }
column "notes" {
    null = true
    type = text
  }
column "available" {
    null = false
    type = boolean
    default = true
  }
primary_key {
  columns = [column.id]
}
foreign_key "fk_rooms_tournament_id" {
  columns = [column.tournament_id]
  ref_columns = [table.tournaments.column.id]
    on_delete = CASCADE
  }
index "index_rooms_on_tournament_id" {
  columns = [column.tournament_id]
}
index "index_rooms_on_room_type" {
  columns = [column.room_type]
}
}

table "rounds" {
  schema = schema.main
column "id" {
    null = false
    type = integer
    auto_increment = true
  }
column "created_at" {
    null = false
    type = datetime
  }
column "updated_at" {
    null = false
    type = datetime
  }
column "tournament_event_id" {
    null = true
    type = integer
  }
column "round_number" {
    null = false
    type = integer
  }
column "name" {
    null = false
    type = varchar(100)
  }
column "round_type" {
    null = false
    type = varchar(20)
    default = "preliminary"
  }
column "start_time" {
    null = true
    type = datetime
  }
column "end_time" {
    null = true
    type = datetime
  }
column "status" {
    null = false
    type = varchar(20)
    default = "scheduled"
  }
column "notes" {
    null = true
    type = text
  }
primary_key {
  columns = [column.id]
}
foreign_key "fk_rounds_tournament_event_id" {
  columns = [column.tournament_event_id]
  ref_columns = [table.tournament_events.column.id]
    on_delete = CASCADE
  }
index "index_rounds_on_tournament_event_id" {
  columns = [column.tournament_event_id]
}
index "index_rounds_on_tournament_event_id_and_round_number_unique" {
  columns = [column.tournament_event_id, column.round_number]
    unique = true
  }
index "index_rounds_on_start_time" {
  columns = [column.start_time]
}
}

table "matches" {
  schema = schema.main
column "id" {
    null = false
    type = integer
    auto_increment = true
  }
column "created_at" {
    null = false
    type = datetime
  }
column "updated_at" {
    null = false
    type = datetime
  }
column "round_id" {
    null = true
    type = integer
  }
column "room_id" {
    null = true
    type = integer
  }
column "match_number" {
    null = false
    type = integer
  }
column "start_time" {
    null = true
    type = datetime
  }
column "end_time" {
    null = true
    type = datetime
  }
column "status" {
    null = false
    type = varchar(20)
    default = "scheduled"
  }
column "winner_id" {
    null = true
    type = integer
  }
column "winner_type" {
    null = true
    type = varchar(20)
  }
column "notes" {
    null = true
    type = text
  }
primary_key {
  columns = [column.id]
}
foreign_key "fk_matches_round_id" {
  columns = [column.round_id]
  ref_columns = [table.rounds.column.id]
    on_delete = CASCADE
  }
foreign_key "fk_matches_room_id" {
  columns = [column.room_id]
  ref_columns = [table.rooms.column.id]
    on_delete = SET_NULL
  }
index "index_matches_on_round_id" {
  columns = [column.round_id]
}
index "index_matches_on_room_id" {
  columns = [column.room_id]
}
index "index_matches_on_round_id_and_match_number_unique" {
  columns = [column.round_id, column.match_number]
    unique = true
  }
index "index_matches_on_start_time" {
  columns = [column.start_time]
}
}

table "match_participants" {
  schema = schema.main
column "id" {
    null = false
    type = integer
    auto_increment = true
  }
column "created_at" {
    null = false
    type = datetime
  }
column "updated_at" {
    null = false
    type = datetime
  }
column "match_id" {
    null = true
    type = integer
  }
column "participant_id" {
    null = false
    type = integer
  }
column "participant_type" {
    null = false
    type = varchar(20)
  }
column "position" {
    null = true
    type = varchar(20)
  }
column "speaking_order" {
    null = true
    type = integer
  }
column "score" {
    null = true
    type = decimal(8,2)
  }
column "rank" {
    null = true
    type = integer
  }
primary_key {
  columns = [column.id]
}
foreign_key "fk_match_participants_match_id" {
  columns = [column.match_id]
  ref_columns = [table.matches.column.id]
    on_delete = CASCADE
  }
index "index_match_participants_on_match_id" {
  columns = [column.match_id]
}
index "index_match_participants_on_participant_id_and_participant_type" {
  columns = [column.participant_id, column.participant_type]
  }
index "index_match_participants_on_match_id_and_participant_id_and_participant_type_unique" {
  columns = [column.match_id, column.participant_id, column.participant_type]
    unique = true
  }
}

table "judges" {
  schema = schema.main
column "id" {
    null = false
    type = integer
    auto_increment = true
  }
column "created_at" {
    null = false
    type = datetime
  }
column "updated_at" {
    null = false
    type = datetime
  }
column "user_id" {
    null = true
    type = integer
  }
column "tournament_id" {
    null = true
    type = integer
  }
column "experience_level" {
    null = false
    type = varchar(20)
    default = "novice"
  }
column "certifications" {
    null = true
    type = text
  }
column "preferences" {
    null = true
    type = text
  }
column "availability" {
    null = true
    type = text
  }
column "active" {
    null = false
    type = boolean
    default = true
  }
primary_key {
  columns = [column.id]
}
foreign_key "fk_judges_user_id" {
  columns = [column.user_id]
  ref_columns = [table.users.column.id]
    on_delete = CASCADE
  }
foreign_key "fk_judges_tournament_id" {
  columns = [column.tournament_id]
  ref_columns = [table.tournaments.column.id]
    on_delete = CASCADE
  }
index "index_judges_on_user_id" {
  columns = [column.user_id]
}
index "index_judges_on_tournament_id" {
  columns = [column.tournament_id]
}
index "index_judges_on_user_id_and_tournament_id_unique" {
  columns = [column.user_id, column.tournament_id]
    unique = true
  }
}

table "match_judges" {
  schema = schema.main
column "id" {
    null = false
    type = integer
    auto_increment = true
  }
column "created_at" {
    null = false
    type = datetime
  }
column "updated_at" {
    null = false
    type = datetime
  }
column "match_id" {
    null = true
    type = integer
  }
column "judge_id" {
    null = true
    type = integer
  }
column "role" {
    null = false
    type = varchar(20)
    default = "judge"
  }
column "status" {
    null = false
    type = varchar(20)
    default = "assigned"
  }
primary_key {
  columns = [column.id]
}
foreign_key "fk_match_judges_match_id" {
  columns = [column.match_id]
  ref_columns = [table.matches.column.id]
    on_delete = CASCADE
  }
foreign_key "fk_match_judges_judge_id" {
  columns = [column.judge_id]
  ref_columns = [table.judges.column.id]
    on_delete = CASCADE
  }
index "index_match_judges_on_match_id" {
  columns = [column.match_id]
}
index "index_match_judges_on_judge_id" {
  columns = [column.judge_id]
}
index "index_match_judges_on_match_id_and_judge_id_unique" {
  columns = [column.match_id, column.judge_id]
    unique = true
  }
}

table "registrations" {
  schema = schema.main
column "id" {
    null = false
    type = integer
    auto_increment = true
  }
column "created_at" {
    null = false
    type = datetime
  }
column "updated_at" {
    null = false
    type = datetime
  }
column "tournament_event_id" {
    null = true
    type = integer
  }
column "participant_id" {
    null = false
    type = integer
  }
column "participant_type" {
    null = false
    type = varchar(20)
  }
column "registration_date" {
    null = false
    type = date
  }
column "status" {
    null = false
    type = varchar(20)
    default = "registered"
  }
column "fee_paid" {
    null = false
    type = boolean
    default = false
  }
column "payment_date_at" {
    null = false
    type = datetime
  }
column "notes" {
    null = true
    type = text
  }
primary_key {
  columns = [column.id]
}
foreign_key "fk_registrations_tournament_event_id" {
  columns = [column.tournament_event_id]
  ref_columns = [table.tournament_events.column.id]
    on_delete = CASCADE
  }
index "index_registrations_on_tournament_event_id" {
  columns = [column.tournament_event_id]
}
index "index_registrations_on_participant_id_and_participant_type" {
  columns = [column.participant_id, column.participant_type]
  }
index "index_registrations_on_tournament_event_id_and_participant_id_and_participant_type_unique" {
  columns = [column.tournament_event_id, column.participant_id, column.participant_type]
    unique = true
  }
index "index_registrations_on_status" {
  columns = [column.status]
}
}

table "awards" {
  schema = schema.main
column "id" {
    null = false
    type = integer
    auto_increment = true
  }
column "created_at" {
    null = false
    type = datetime
  }
column "updated_at" {
    null = false
    type = datetime
  }
column "name" {
    null = false
    type = varchar(255)
  }
column "tournament_event_id" {
    null = true
    type = integer
  }
column "recipient_id" {
    null = false
    type = integer
  }
column "recipient_type" {
    null = false
    type = varchar(20)
  }
column "award_type" {
    null = false
    type = varchar(50)
    default = "placement"
  }
column "position" {
    null = true
    type = integer
  }
column "description" {
    null = true
    type = text
  }
column "awarded_at" {
    null = false
    type = datetime
  }
primary_key {
  columns = [column.id]
}
foreign_key "fk_awards_tournament_event_id" {
  columns = [column.tournament_event_id]
  ref_columns = [table.tournament_events.column.id]
    on_delete = CASCADE
  }
index "index_awards_on_tournament_event_id" {
  columns = [column.tournament_event_id]
}
index "index_awards_on_recipient_id_and_recipient_type" {
  columns = [column.recipient_id, column.recipient_type]
  }
index "index_awards_on_award_type" {
  columns = [column.award_type]
}
index "index_awards_on_position" {
  columns = [column.position]
}
}

table "records" {
  schema = schema.main
column "id" {
    null = false
    type = integer
    auto_increment = true
  }
column "created_at" {
    null = false
    type = datetime
  }
column "updated_at" {
    null = false
    type = datetime
  }
column "user_id" {
    null = true
    type = integer
  }
column "record_type" {
    null = false
    type = varchar(100)
  }
column "value" {
    null = true
    type = text
  }
primary_key {
  columns = [column.id]
}
foreign_key "fk_records_user_id" {
  columns = [column.user_id]
  ref_columns = [table.users.column.id]
    on_delete = CASCADE
  }
index "index_records_on_user_id" {
  columns = [column.user_id]
}
index "index_records_on_record_type" {
  columns = [column.record_type]
}
}

# Atlas configuration file for Rails integration

# Data source for external schema - can load from Rails schema.rb
data "external_schema" "rails" {
  program = [
    "ruby", 
    "-e", 
    "require_relative 'config/environment'; puts ActiveRecord::Base.connection.structure_dump"
  ]
}

# Development environment using SQLite
env "dev" {
  src = "file://db/schema.hcl"
  url = "sqlite://storage/development.sqlite3"
  dev = "sqlite://file?mode=memory&_fk=1"
  migration {
    dir = "file://db/atlas_migrations"
  }
}

# Environment that uses current Rails database as source
env "rails" {
  src = data.external_schema.rails.url
  url = "sqlite://storage/development.sqlite3"
  dev = "sqlite://file?mode=memory&_fk=1"
  migration {
    dir = "file://db/atlas_migrations"
  }
}

# Production-like environment
env "prod" {
  src = "file://db/schema.hcl"
  url = env("DATABASE_URL")
  migration {
    dir = "file://db/atlas_migrations"
  }
}
# JAML Example Rails Application

This is a complete Rails application that demonstrates the capabilities of the **JAML** (JAML ActiveRecord Modeling Language) gem. The application manages speech and debate tournaments and showcases how JAML enables rapid database schema iteration.

## What This Demonstrates

This example application shows:

- **Real-world schema complexity** - 17 interconnected tables for tournament management
- **JAML pattern matching** - Automatic foreign keys, timestamps, and type inference
- **Default columns** - Every table gets `id`, `created_at`, `updated_at` automatically
- **Rails integration** - Seamless workflow with rake tasks
- **Schema evolution** - How to iterate quickly on database design

## Schema Overview

The application models a complete speech and debate tournament system:

### Core Entities
- **Leagues** - Organizations that run tournaments
- **Seasons** - Time periods for competition
- **Users** - Participants, judges, and organizers
- **Teams** - Groups of participants

### Tournament Structure
- **Tournaments** - Individual competition events
- **Event Types** - Speech, debate, and interpretation categories
- **Rooms** - Physical or virtual competition spaces
- **Rounds** - Stages of competition
- **Matches** - Individual competitions between participants

### Management
- **Registrations** - Participant sign-ups
- **Judges** - Competition officials
- **Awards** - Recognition and rankings

## Getting Started

### Prerequisites

- Ruby 3.0+
- Rails 8.0+
- Atlas CLI ([installation guide](https://atlasgo.io/getting-started))
- JAML gem (automatically loaded from parent directory)

### Setup

1. **Install dependencies:**
   ```shell
   cd example_app
   bundle install
   ```

2. **Initialize the database:**
   ```shell
   rails db:create
   ```

3. **Set up JAML:**
   ```shell
   rake jaml:init
   ```

## JAML Workflow Demonstration

### 1. View the Schema

The schema is defined in `db/schema.yaml` using JAML syntax:

```yaml
# Core entities with automatic defaults
users:
  columns:
    # id, created_at, updated_at added automatically
    email: string(255) not_null unique
    first_name: string(100) not_null
    last_name: string(100) not_null
    league_id: ~  # Automatically becomes: integer -> leagues.id CASCADE
    last_login_at: ~  # Automatically becomes: datetime not_null
```

### 2. Convert Schema

Convert the YAML to Atlas HCL format:

```shell
rake jaml:convert
```

This generates `db/schema.hcl` with proper foreign keys, constraints, and indexes.

### 3. Preview Changes

See what database changes would be applied:

```shell
rake jaml:preview
```

### 4. Apply to Database

Apply the schema to your database:

```shell
rake jaml:apply
```

### 5. Generate Rails Migration (Optional)

Create a Rails migration file:

```shell
rake jaml:generate["tournament system setup"]
```

## Key JAML Features Demonstrated

### Default Columns
Every table automatically gets:
- `id: primary_key` with auto-increment
- `created_at: datetime not_null`
- `updated_at: datetime not_null`

### Pattern Matching
- `league_id: ~` → `integer -> leagues.id on_delete=cascade not_null`
- `last_login_at: ~` → `datetime not_null`
- `bio: ~` → `string` (fallback)

### Automatic Foreign Keys
```yaml
teams:
  columns:
    league_id: ~     # References leagues.id
    season_id: ~     # References seasons.id
```

Generates proper foreign key constraints with cascading deletes.

### Smart Pluralization
- `user_id` references `users.id`
- `category_id` references `categories.id`
- `company_id` references `companies.id`

## Available Rake Tasks

JAML provides comprehensive rake tasks for schema management:

```shell
rake jaml:help                     # Show all available commands
rake jaml:template                 # Generate new schema template
rake jaml:convert                  # Convert YAML to HCL
rake jaml:preview                  # Preview changes
rake jaml:apply                    # Apply to database
rake jaml:generate[name]           # Generate Rails migration
rake jaml:deploy[name]             # Full workflow
```

## Seed Data

The application includes comprehensive seed data for testing:

```shell
rake jaml:seed    # Generate event type seed data
rails db:seed     # Load all seed data
```

This creates:
- Speech events (Persuasive, Informative, Original Oratory)
- Debate events (Team Policy, Lincoln Douglas)
- Interpretation events (Duo Interpretation)
- Apologetics events

## Schema Evolution Examples

### Adding a New Table

1. Edit `db/schema.yaml`:
   ```yaml
   sponsors:
     columns:
       name: string(255) not_null
       website: string(500)
       tournament_id: ~  # Automatic foreign key
   ```

2. Deploy changes:
   ```shell
   rake jaml:deploy["add sponsors"]
   ```

### Modifying Existing Tables

1. Update `db/schema.yaml`
2. Preview changes: `rake jaml:preview`
3. Apply changes: `rake jaml:apply`

## Performance

The example schema demonstrates JAML's performance with:
- **17 tables** processed in milliseconds
- **25+ foreign keys** automatically generated
- **Consistent formatting** across all tables
- **Clean diffs** for version control

## Files Structure

```
example_app/
├── app/                    # Rails application code
├── config/                 # Rails configuration
├── db/
│   ├── schema.yaml        # JAML schema definition
│   ├── schema.hcl         # Generated Atlas HCL
│   ├── schema.rb          # Rails schema (auto-generated)
│   └── seeds.rb           # Seed data
├── lib/                   # Original JAML code (legacy)
├── Gemfile                # Rails dependencies
└── atlas.hcl             # Atlas configuration
```

## Comparison: Before and After JAML

### Before (Traditional Rails)
```ruby
# db/migrate/001_create_users.rb
class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :first_name, limit: 100, null: false
      t.string :last_name, limit: 100, null: false
      t.string :email, limit: 255, null: false
      t.string :phone, limit: 20
      t.references :league, null: true, foreign_key: { on_delete: :nullify }
      t.timestamps null: false
    end

    add_index :users, :email, unique: true
    add_index :users, :league_id
  end
end
```

### After (JAML)
```yaml
users:
  columns:
    first_name: string(100) not_null
    last_name: string(100) not_null
    email: string(255) not_null unique
    phone: string(20)
    league_id: ~
  indexes:
    - email
    - league_id
```

**Result**: 10x less code, automatic consistency, better readability.

## Learning Resources

- [JAML Main Repository](../../README.md)
- [Atlas Documentation](https://atlasgo.io/guides)
- [Rails Guides](https://guides.rubyonrails.org/)

## Contributing

This example application is part of the JAML gem development. To contribute:

1. Make changes to the schema in `db/schema.yaml`
2. Test the JAML workflow
3. Submit pull requests to the main JAML repository

## License

This example application is part of the JAML gem and is available under the [MIT License](../LICENSE).

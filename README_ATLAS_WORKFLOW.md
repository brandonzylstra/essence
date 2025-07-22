# Atlas-Rails Integration Workflow

A powerful declarative schema management system for Rails that combines the simplicity of YAML with the robustness of Atlas for database schema evolution.

## Overview

This project demonstrates a complete solution for rapid database schema prototyping and management in Rails applications. Instead of writing traditional Rails migrations, you can:

1. **Define schemas in simple YAML** - Use an intuitive, readable format
2. **Convert to Atlas HCL** - Leverage Atlas's powerful schema management
3. **Generate Rails migrations** - Maintain compatibility with Rails workflows
4. **Apply changes instantly** - Skip the tedious migration writing process

## Why This Approach?

Traditional Rails migration workflow:
```bash
# Traditional way - lots of repetitive typing
rails generate migration CreateUsers first_name:string last_name:string email:string:uniq
rails generate migration CreateTeams name:string league:references season:references
rails generate migration AddIndexToUsers email
rails db:migrate
```

Atlas-Rails workflow:
```bash
# Our way - edit YAML, apply changes
vim schema.yml           # Edit your schema in simple YAML
rake atlas:yaml_to_hcl   # Convert to Atlas format
rake atlas:apply         # Apply all changes instantly
```

## Features

- **🎯 Declarative Schema Management** - Define what you want, not how to get there
- **🚀 Rapid Prototyping** - Make schema changes in seconds, not minutes
- **📝 Readable Schema Format** - YAML that any developer can understand
- **🔄 Rails Compatibility** - Automatically updates `schema.rb`
- **💪 Atlas Power** - Leverage Atlas's migration planning and safety checks
- **🌱 Integrated Seeding** - Define seed data alongside your schema
- **🔍 Preview Changes** - See exactly what will change before applying

## Quick Start

### 1. Define Your Schema in YAML

Edit `schema.yml`:

```yaml
tables:
  users:
    columns:
      id: primary_key
      first_name: string(100) not_null
      last_name: string(100) not_null
      email: string(255) not_null unique
      created_at: datetime not_null
      updated_at: datetime not_null
    indexes:
      - role

  teams:
    columns:
      id: primary_key
      name: string(255) not_null
      league_id: integer -> leagues.id on_delete=cascade not_null
      season_id: integer -> seasons.id on_delete=cascade not_null
      created_at: datetime not_null
      updated_at: datetime not_null
    indexes:
      - league_id
      - season_id
```

### 2. Convert and Apply

```bash
# Convert YAML to Atlas HCL
rake atlas:yaml_to_hcl

# Preview what will change
rake atlas:preview

# Apply changes to database
rake atlas:apply
```

### 3. Your Rails schema.rb is automatically updated!

## YAML Schema Format

### Column Types

```yaml
columns:
  # Basic types
  name: string(255) not_null
  age: integer
  active: boolean default=true not_null
  bio: text
  created_at: datetime not_null
  birth_date: date
  score: decimal(8,2)
  
  # Primary key
  id: primary_key
  
  # Foreign keys
  user_id: integer -> users.id on_delete=cascade not_null
  league_id: integer -> leagues.id on_delete=set_null
```

### Indexes

```yaml
indexes:
  # Single column index
  - email
  
  # Multi-column index
  - columns: [league_id, season_id]
  
  # Unique index
  - columns: [email]
    unique: true
    
  # Complex unique constraint
  - columns: [tournament_id, event_type_id]
    unique: true
```

### Complete Table Example

```yaml
tournaments:
  columns:
    id: primary_key
    name: string(255) not_null
    league_id: integer -> leagues.id on_delete=cascade not_null
    season_id: integer -> seasons.id on_delete=cascade not_null
    start_date: date not_null
    end_date: date not_null
    location: string(500)
    format: string(20) default='in_person' not_null
    status: string(20) default='upcoming' not_null
    max_participants: integer
    entry_fee: decimal(8,2)
    created_at: datetime not_null
    updated_at: datetime not_null
  indexes:
    - league_id
    - season_id
    - start_date
    - status
```

## Available Rake Tasks

```bash
# Core workflow
rake atlas:yaml_to_hcl               # Convert YAML to Atlas HCL
rake atlas:preview                   # Preview schema changes
rake atlas:apply                     # Apply schema to database
rake atlas:deploy[name]              # Full workflow: preview + generate + apply

# Development helpers
rake atlas:validate                  # Validate Atlas schema file
rake atlas:seed                      # Generate seed data
rake atlas:init                      # Initialize Atlas with current Rails schema
rake atlas:history                   # Show migration history
rake atlas:reset                     # Reset migrations (dev only)

# Rails migration generation (optional)
rake atlas:generate[migration_name]  # Generate Rails migration from diff
```

## Example Workflow

Let's say you want to add a new "awards" table:

### 1. Edit schema.yml

```yaml
awards:
  columns:
    id: primary_key
    name: string(255) not_null
    tournament_event_id: integer -> tournament_events.id on_delete=cascade not_null
    recipient_id: integer not_null
    recipient_type: string(20) not_null  # 'User' or 'Team'
    award_type: string(50) default='placement' not_null
    position: integer
    description: text
    awarded_at: datetime not_null
    created_at: datetime not_null
    updated_at: datetime not_null
  indexes:
    - tournament_event_id
    - columns: [recipient_id, recipient_type]
    - award_type
    - position
```

### 2. Preview and Apply

```bash
$ rake atlas:yaml_to_hcl
🔄 Converting schema.yml to schema.hcl...
✅ Conversion complete!

$ rake atlas:preview
🔍 Atlas migration plan:
Planning migration statements (5 in total):
  -- create "awards" table:
    -> CREATE TABLE `awards` (
         `id` integer NOT NULL PRIMARY KEY AUTOINCREMENT,
         `name` varchar NOT NULL,
         `tournament_event_id` integer NOT NULL,
         ...
       );
  -- create index "index_awards_on_tournament_event_id"...
  -- create index "index_awards_on_recipient"...

$ rake atlas:apply
🚀 Applying Atlas schema to database...
📄 Updating Rails schema.rb...
✅ Schema applied successfully!
```

### 3. Done!

Your database is updated, `schema.rb` is current, and you can immediately start using the new table in your Rails models.

## Speech & Debate Tournament Schema

This project includes a complete schema for managing speech and debate tournaments:

### Core Entities

- **Seasons** - Academic years (Dec/Jan - June)
- **Leagues** - Organizations that run tournaments  
- **Users** - Individual participants, judges, coaches
- **Teams** - For team events like Team Policy debate
- **Event Types** - Persuasive, Informative, Lincoln Douglas, etc.
- **Tournaments** - Specific competitions
- **Rooms** - Physical or virtual competition spaces
- **Rounds** - Competition phases within events
- **Matches** - Individual competitions between participants
- **Judges** - Officials who evaluate competitions
- **Awards** - Recognition given to participants

### Seed Data

The schema includes predefined event types:

- **Persuasive Speaking** (PERS) - Individual speech events
- **Informative Speaking** (INFO) - Educational presentations  
- **Original Oratory** (OO) - Original speeches
- **Duo Interpretation** (DUO) - Two-person dramatic performances
- **Team Policy Debate** (TP) - Team-based policy debates
- **Lincoln Douglas Debate** (LD) - Individual value debates
- **Apologetics** (APOL) - Christian apologetics questions

## Advanced Features

### Foreign Key Relationships

The system automatically handles complex foreign key relationships:

```yaml
# One-to-many with cascade delete
team_id: integer -> teams.id on_delete=cascade not_null

# One-to-many with set null
league_id: integer -> leagues.id on_delete=set_null

# Polymorphic associations (handled via indexes)
participant_id: integer not_null
participant_type: string(20) not_null  # 'User' or 'Team'
```

### Complex Indexes

```yaml
indexes:
  # Unique constraints across multiple columns
  - columns: [tournament_id, event_type_id]
    unique: true
    
  # Polymorphic indexes
  - columns: [participant_id, participant_type]
  
  # Performance indexes
  - start_time
  - status
```

### Enum-like Constraints

While not enforced at the database level, the schema documents expected values:

```yaml
format: string(20) default='in_person' not_null  # 'in_person', 'virtual', 'hybrid'
status: string(20) default='upcoming' not_null   # 'upcoming', 'active', 'completed'
```

## Benefits Over Traditional Migrations

### 1. **Speed** 
- Change schema in seconds, not minutes
- No migration file writing/editing
- Instant application of changes

### 2. **Clarity**
- Single source of truth for schema
- Readable YAML format
- No scattered migration files

### 3. **Safety**
- Atlas validates changes before applying
- Preview mode shows exactly what will change
- Automatic rollback support

### 4. **Flexibility**
- Easy to experiment with schema changes
- Quick iterations during development
- Simple to add/remove tables and columns

### 5. **Rails Compatibility**
- Automatically updates `schema.rb`
- Works with existing Rails tooling
- Can generate traditional migrations if needed

## Files Structure

```
data_modeler/
├── schema.yml                    # Your editable schema definition
├── schema.hcl                    # Auto-generated Atlas HCL
├── atlas.hcl                     # Atlas configuration
├── lib/
│   ├── atlas_rails_bridge.rb     # Main integration logic
│   ├── yaml_to_hcl_converter.rb  # YAML → HCL converter
│   └── tasks/atlas.rake           # Rake tasks
├── db/
│   ├── schema.rb                 # Standard Rails schema (auto-updated)
│   ├── seeds.rb                  # Generated seed data
│   └── atlas_migrations/         # Atlas migration history
└── README_ATLAS_WORKFLOW.md     # This file
```

## Tips and Best Practices

### 1. Always Preview First
```bash
rake atlas:preview  # See what will change
rake atlas:apply    # Apply changes
```

### 2. Use Descriptive Names
```yaml
# Good
index_users_on_email_and_active
fk_team_memberships_user

# Bad  
idx1
fk_tm_u
```

### 3. Be Explicit About Constraints
```yaml
email: string(255) not_null unique
user_id: integer -> users.id on_delete=cascade not_null
```

### 4. Group Related Tables
Organize your YAML file with related tables together for readability.

### 5. Use Comments
```yaml
# Tournament management tables
tournaments:
  columns:
    format: string(20) default='in_person' not_null  # 'in_person', 'virtual', 'hybrid'
```

## Troubleshooting

### YAML Syntax Errors
```bash
# If you get YAML parse errors, check:
- Consistent indentation (2 spaces)
- Proper array syntax with dashes
- Quoted strings with special characters
```

### Atlas Validation Errors
```bash
rake atlas:validate  # Check HCL syntax
```

### Schema Conflicts
```bash
rake atlas:reset     # Reset Atlas migrations (dev only)
rake atlas:init      # Re-initialize from current Rails schema
```

## Migration to Production

For production deployments, you have several options:

1. **Direct Atlas Apply** - Use Atlas directly in production
2. **Generated Migrations** - Generate Rails migrations for production deploy
3. **Hybrid Approach** - Use Atlas in development, migrations in production

The system is designed to be flexible and adapt to your deployment needs.

## Conclusion

This Atlas-Rails integration provides a modern, efficient way to manage database schemas in Rails applications. By combining the simplicity of YAML with the power of Atlas, you can iterate rapidly on schema designs while maintaining the safety and compatibility that Rails developers expect.

The included speech & debate tournament schema demonstrates a real-world, complex domain with multiple entity relationships, polymorphic associations, and detailed constraint management—all expressed in clean, readable YAML.

Whether you're prototyping a new application or managing an existing one, this workflow can significantly speed up your database schema development process.
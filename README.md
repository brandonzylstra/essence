# JAML - JAML ActiveRecord Modeling Language

[![Gem Version](https://badge.fury.io/rb/jaml.svg)](https://badge.fury.io/rb/jaml)
[![Ruby](https://github.com/brandonzylstra/jaml/workflows/Ruby/badge.svg)](https://github.com/brandonzylstra/jaml/actions)

**JAML** (JAML ActiveRecord Modeling Language) is a powerful tool for rapid database schema iteration in Rails applications. It provides a clean, YAML-based syntax with intelligent defaults and pattern matching that compiles to Atlas HCL format for seamless database migrations.

## 🚀 Why JAML?

- **10x faster schema iteration** - Write schemas in clean YAML instead of verbose Rails migrations or GUI tools
- **Smart defaults** - Automatic `id`, `created_at`, `updated_at` columns for every table
- **Pattern-based inference** - `league_id: ~` automatically becomes a foreign key to `leagues.id`
- **Version control friendly** - Text-based schemas that diff and merge cleanly
- **Rails integration** - Seamless workflow with rake tasks and Atlas backend
- **Template generation** - Quick project setup with sensible defaults

## 📦 Installation

Add this line to your application's Gemfile:

```ruby
gem 'jaml'
```

And then execute:

```bash
$ bundle install
```

Or install it globally:

```bash
$ gem install jaml
```

## 🏃‍♂️ Quick Start

### 1. Generate a Schema Template

```bash
# In Rails project
rake jaml:template

# Or using CLI
jaml template
```

This creates `db/schema.yaml` with intelligent defaults:

```yaml
# Enhanced JAML Schema with Default Columns and Pattern Matching
schema_name: main
rails_version: "8.0"

# Default columns applied to all tables
defaults:
  "*":
    columns:
      id: primary_key
      created_at: datetime not_null
      updated_at: datetime not_null

# Pattern-based column attribute inference
column_patterns:
  - pattern: "_id$"
    template: "integer -> {table}.id on_delete=cascade not_null"
  - pattern: "_at$"
    attributes: "datetime not_null"
  - pattern: ".*"
    attributes: "string"

# Table definitions
tables:
  users:
    columns:
      email: string(255) not_null unique
      first_name: string(100) not_null
      last_name: string(100) not_null
      league_id: ~  # Automatically becomes: integer -> leagues.id on_delete=cascade not_null
      last_login_at: ~  # Automatically becomes: datetime not_null
    indexes:
      - email
      - league_id

  leagues:
    columns:
      name: string(255) not_null unique
      description: text
      active: boolean default=true not_null
```

### 2. Convert to HCL Format

```bash
# In Rails project
rake jaml:convert

# Or using CLI
jaml convert
```

### 3. Apply to Database

```bash
rake jaml:preview  # See what would change
rake jaml:apply    # Apply changes to database
```

## ✨ Features

### Smart Default Columns

Every table automatically gets:
- `id: primary_key` with auto-increment
- `created_at: datetime not_null`
- `updated_at: datetime not_null`

Override defaults by specifying explicit columns.

### Pattern-Based Column Inference

Write `column_name: ~` and JAML automatically infers the type:

| Pattern | Example | Becomes |
|---------|---------|---------|
| `_id$` | `user_id: ~` | `integer -> users.id on_delete=cascade not_null` |
| `_at$` | `published_at: ~` | `datetime not_null` |
| `_on$` | `due_on: ~` | `date` |
| `.*` | `bio: ~` | `string` (fallback) |

### Automatic Foreign Keys

```yaml
tables:
  posts:
    columns:
      user_id: ~        # Automatically creates foreign key to users.id
      category_id: ~    # Automatically creates foreign key to categories.id
```

Generates proper HCL with foreign key constraints:

```hcl
foreign_key "fk_posts_user_id" {
  columns = [column.user_id]
  ref_columns = [table.users.column.id]
  on_delete = CASCADE
}
```

### Intelligent Pluralization

JAML automatically pluralizes table names for foreign key references:

- `user_id` → references `users.id`
- `category_id` → references `categories.id`
- `company_id` → references `companies.id`
- `leaf_id` → references `leaves.id`

## 🛠 Rails Integration

JAML provides comprehensive rake tasks for Rails workflow:

```bash
rake jaml:template                    # Generate schema.yaml template
rake jaml:convert                     # Convert YAML to HCL format
rake jaml:preview                     # Preview what would change
rake jaml:apply                       # Apply changes to database
rake jaml:generate[name]              # Generate Rails migration
rake jaml:deploy[name]                # Full workflow: preview + generate + apply
rake jaml:seed                        # Generate seed data
rake jaml:help                        # Show all available commands
```

### Full Workflow Example

```bash
# 1. Create schema template (one time)
rake jaml:template

# 2. Edit db/schema.yaml with your tables
# 3. Deploy changes
rake jaml:deploy["add user system"]
```

## 🎯 Advanced Usage

### Custom Column Patterns

Define your own pattern matching rules:

```yaml
column_patterns:
  - pattern: "^is_"
    attributes: "boolean default=false not_null"
  - pattern: "_email$"
    attributes: "string(255) unique"
  - pattern: "_count$"
    attributes: "integer default=0 not_null"
  - pattern: "_price$"
    attributes: "decimal(10,2)"
```

### Table-Specific Defaults

Override defaults for specific tables:

```yaml
defaults:
  "*":
    columns:
      id: primary_key
      created_at: datetime not_null
      updated_at: datetime not_null
  
  audit_logs:
    columns:
      id: primary_key
      created_at: datetime not_null
      # No updated_at for audit logs
```

### Complex Relationships

```yaml
tables:
  tournaments:
    columns:
      league_id: ~
      season_id: ~
      # Override foreign key behavior
      organizer_id: integer -> users.id on_delete=set_null
      
  matches:
    columns:
      tournament_id: ~
      # Polymorphic-style relationships
      winner_id: integer
      winner_type: string(20)  # 'User' or 'Team'
```

### Indexes and Constraints

```yaml
tables:
  users:
    columns:
      email: string(255) not_null
      username: string(50) not_null
    indexes:
      - email  # Simple index
      - columns: [username]
        unique: true  # Unique index
      - columns: [email, username]  # Composite index
```

## 💻 Command Line Interface

JAML provides a standalone CLI for non-Rails projects:

```bash
# Generate template
jaml template [file_path]

# Convert schema
jaml convert [yaml_file] [hcl_file]

# Show version
jaml version

# Show help
jaml help
```

### CLI Examples

```bash
# Generate template in current directory
jaml template schema.yaml

# Convert specific files
jaml convert my_schema.yaml output.hcl

# Use in CI/CD pipelines
jaml convert && atlas schema apply --env prod
```

## ⚙️ Configuration

### Rails Configuration

In `config/application.rb` or environment files:

```ruby
config.jaml.schema_file = 'db/schema.yaml'
config.jaml.hcl_file = 'db/schema.hcl'
config.jaml.atlas_env = 'dev'
```

### Atlas Integration

JAML works with [Atlas](https://atlasgo.io/) for database operations. Create `atlas.hcl`:

```hcl
env "dev" {
  src = "file://db/schema.hcl"
  dev = "sqlite://dev.db"
}

env "prod" {
  src = "file://db/schema.hcl"
  url = env("DATABASE_URL")
  migration {
    dir = "file://db/atlas_migrations"
  }
}
```

## 📚 Pattern Reference

### Built-in Patterns

| Pattern | Regex | Result | Example |
|---------|-------|--------|---------|
| Foreign Keys | `_id$` | `integer -> {table}.id on_delete=cascade not_null` | `user_id: ~` |
| Timestamps | `_at$` | `datetime not_null` | `published_at: ~` |
| Dates | `_on$` | `date` | `due_on: ~` |
| Booleans | `^is_` | `boolean default=false not_null` | `is_active: ~` |
| Counters | `_count$` | `integer default=0 not_null` | `view_count: ~` |
| Default | `.*` | `string` | `name: ~` |

### Custom Pattern Examples

```yaml
column_patterns:
  - pattern: "_url$"
    attributes: "string(500)"
  - pattern: "_slug$" 
    attributes: "string(255) unique"
  - pattern: "_status$"
    attributes: "string(20) default='pending' not_null"
  - pattern: "^has_"
    attributes: "boolean default=false not_null"
```

## 🔧 Development

After checking out the repo, run:

```bash
bin/setup      # Install dependencies
rake spec      # Run tests
bin/console    # Interactive prompt for experimentation
```

To install this gem onto your local machine:

```bash
bundle exec rake install
```

## 🤝 Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/brandonzylstra/jaml.

1. Fork the repository
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## 📝 License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## 🙏 Acknowledgments

- Built on top of [Atlas](https://atlasgo.io/) for robust database migrations
- Inspired by the need for rapid schema iteration in Rails development
- Thanks to the Rails community for creating an amazing framework

---

**JAML** - Because life's too short for verbose schema definitions! 🚀
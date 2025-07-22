# frozen_string_literal: true

require_relative '../atlas_rails_bridge'
require_relative '../yaml_to_hcl_converter'

namespace :atlas do
  desc "Preview Atlas schema changes"
  task :preview do
    bridge = AtlasRailsBridge.new
    bridge.preview_changes
  end

  desc "Generate Rails migration from Atlas schema diff"
  task :generate, [ :name ] do |_task, args|
    bridge = AtlasRailsBridge.new
    migration_name = args[:name] || "atlas_schema_update"
    bridge.generate_migration(migration_name)
  end

  desc "Apply Atlas schema and update Rails schema.rb"
  task :apply do
    bridge = AtlasRailsBridge.new
    bridge.apply_schema!
  end

  desc "Generate seed data for event types"
  task :seed do
    bridge = AtlasRailsBridge.new
    bridge.generate_seed_data
  end

  desc "Convert YAML schema to Atlas HCL format"
  task :yaml_to_hcl, [:yaml_file, :hcl_file] do |_task, args|
    converter = YamlToHclConverter.new(args[:yaml_file], args[:hcl_file])
    converter.convert!
  end

  desc "Full workflow: preview, generate migration, and apply"
  task :deploy, [ :name ] do |_task, args|
    bridge = AtlasRailsBridge.new
    migration_name = args[:name] || "atlas_schema_update"

    puts "🔍 Step 1: Previewing changes..."
    bridge.preview_changes

    puts "\n📝 Step 2: Generating Rails migration..."
    bridge.generate_migration(migration_name)

    print "\n🚀 Step 3: Apply changes? (y/N): "
    response = STDIN.gets.chomp.downcase

    if response == "y" || response == "yes"
      bridge.apply_schema!
    else
      puts "⏸️  Schema application skipped. Run 'rake atlas:apply' when ready."
    end
  end

  desc "Initialize Atlas with current Rails schema"
  task init: :environment do
    puts "🔧 Initializing Atlas with current Rails schema..."

    # Create atlas directory for migrations
    FileUtils.mkdir_p("db/atlas_migrations")

    # Export current Rails schema to Atlas HCL format
    system("atlas schema inspect --url 'sqlite://#{Rails.configuration.database_configuration[Rails.env]['database']}' --format '{{ hcl . }}' > db/current_schema.hcl")

    puts "✅ Atlas initialized!"
    puts "📄 Current schema exported to db/current_schema.hcl"
    puts "🔧 Edit db/schema.yaml to define your desired schema"
    puts "🚀 Run 'rake atlas:preview' to see what would change"
  end

  desc "Validate Atlas schema file"
  task :validate do
    puts "🔍 Validating Atlas schema..."
    result = system("atlas schema validate --env dev")
    if result
      puts "✅ Schema validation passed!"
    else
      puts "❌ Schema validation failed!"
      exit 1
    end
  end

  desc "Show Atlas migration history"
  task :history do
    puts "📋 Atlas migration history:"
    system("atlas migrate status --env dev")
  end

  desc "Reset Atlas migrations (DANGEROUS - for development only)"
  task :reset do
    print "⚠️  This will delete all Atlas migration history. Are you sure? (y/N): "
    response = STDIN.gets.chomp.downcase

    if response == "y" || response == "yes"
      FileUtils.rm_rf("db/atlas_migrations")
      FileUtils.mkdir_p("db/atlas_migrations")
      puts "🗑️  Atlas migrations reset!"
    else
      puts "✅ Reset cancelled"
    end
  end

  desc "Show all available Atlas commands"
  task :help do
    puts <<~HELP
      Atlas Rails Integration Tasks
      =============================

      rake atlas:preview                    # Preview what Atlas would change
      rake atlas:generate[name]             # Generate Rails migration from Atlas diff
      rake atlas:apply                      # Apply Atlas schema to database
      rake atlas:deploy[name]               # Full workflow: preview + generate + apply
      rake atlas:seed                       # Generate seed data for event types
      rake atlas:yaml_to_hcl[yaml,hcl]      # Convert YAML schema to Atlas HCL
      rake atlas:init                       # Initialize Atlas with current Rails schema
      rake atlas:validate                   # Validate Atlas schema file
      rake atlas:history                    # Show Atlas migration history
      rake atlas:reset                      # Reset Atlas migrations (development only)
      rake atlas:help                       # Show this help message

      Quick Start:
      -----------
      1. rake atlas:init                    # Set up Atlas
      2. Edit db/schema.yaml                # Define your schema in YAML
      3. rake atlas:yaml_to_hcl             # Convert to Atlas HCL
      4. rake atlas:preview                 # See what would change
      5. rake atlas:deploy[migration_name]  # Generate migration and apply

      Files:
      ------
      db/schema.yaml      # Your editable schema definition (YAML format)
      db/schema.hcl       # Auto-generated Atlas HCL schema
      atlas.hcl           # Atlas configuration
      db/atlas_migrations # Atlas migration files

      Examples:
      --------
      rake atlas:generate["add user tables"]
      rake atlas:deploy["tournament schema"]
      rake atlas:yaml_to_hcl[db/schema.yaml,db/schema.hcl]
    HELP
  end
end

# Default task shows help
task atlas: "atlas:help"

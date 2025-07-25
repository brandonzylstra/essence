# frozen_string_literal: true

require_relative '../atlas_rails_bridge'
require_relative '../yaml_to_hcl_converter'

namespace :jaml do
  desc "Preview schema changes"
  task :preview do
    bridge = AtlasRailsBridge.new
    bridge.preview_changes
  end

  desc "Generate Rails migration from schema diff"
  task :generate, [ :name ] do |_task, args|
    bridge = AtlasRailsBridge.new
    migration_name = args[:name] || "atlas_schema_update"
    bridge.generate_migration(migration_name)
  end

  desc "Apply schema and update Rails schema.rb"
  task :apply do
    bridge = AtlasRailsBridge.new
    bridge.apply_schema!
  end

  desc "Generate seed data"
  task :seed do
    bridge = AtlasRailsBridge.new
    bridge.generate_seed_data
  end

  desc "Convert YAML schema to HCL format"
  task :convert, [:yaml_file, :hcl_file] do |_task, args|
    converter = YamlToHclConverter.new(args[:yaml_file], args[:hcl_file])
    converter.convert!
  end

  desc "Generate a new schema.yaml template with defaults and patterns"
  task :template, [:file_path] do |_task, args|
    file_path = args[:file_path] || 'db/schema.yaml'
    YamlToHclConverter.generate_template(file_path)
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
    puts "🚀 Run 'rake jaml:preview' to see what would change"
  end

  desc "Validate schema file"
  task :validate do
    puts "🔍 Validating schema..."
    result = system("atlas schema validate --env dev")
    if result
      puts "✅ Schema validation passed!"
    else
      puts "❌ Schema validation failed!"
      exit 1
    end
  end

  desc "Show migration history"
  task :history do
    puts "📋 Migration history:"
    system("atlas migrate status --env dev")
  end

  desc "Reset migrations (DANGEROUS - for development only)"
  task :reset do
    print "⚠️  This will delete all Atlas migration history. Are you sure? (y/N): "
    response = STDIN.gets.chomp.downcase

    if response == "y" || response == "yes"
      FileUtils.rm_rf("db/atlas_migrations")
      FileUtils.mkdir_p("db/atlas_migrations")
      puts "🗑️  Migrations reset!"
    else
      puts "✅ Reset cancelled"
    end
  end

  desc "Show all available JAML commands"
  task :help do
    puts <<~HELP
      JAML (JAML ActiveRecord Modeling Language) Tasks
      ================================================

      rake jaml:preview                     # Preview what would change
      rake jaml:generate[name]              # Generate Rails migration from schema diff
      rake jaml:apply                       # Apply schema to database
      rake jaml:deploy[name]                # Full workflow: preview + generate + apply
      rake jaml:seed                        # Generate seed data
      rake jaml:convert[yaml,hcl]           # Convert YAML schema to HCL format
      rake jaml:template[file_path]         # Generate new schema.yaml template
      rake jaml:init                        # Initialize with current Rails schema
      rake jaml:validate                    # Validate schema file
      rake jaml:history                     # Show migration history
      rake jaml:reset                       # Reset migrations (development only)
      rake jaml:help                        # Show this help message

      Quick Start:
      -----------
      1. rake jaml:template                 # Generate schema.yaml template (new projects)
         OR rake jaml:init                  # Set up (existing projects)
      2. Edit db/schema.yaml                # Define your schema in YAML
      3. rake jaml:convert                  # Convert to HCL format
      4. rake jaml:preview                  # See what would change
      5. rake jaml:deploy[migration_name]   # Generate migration and apply

      Files:
      ------
      db/schema.yaml      # Your editable schema definition (YAML format)
      db/schema.hcl       # Auto-generated HCL schema
      atlas.hcl           # Atlas configuration
      db/atlas_migrations # Migration files

      Examples:
      --------
      rake jaml:template                    # Create schema.yaml with defaults
      rake jaml:template[custom/path.yaml]  # Create template at custom location
      rake jaml:generate["add user tables"]
      rake jaml:deploy["tournament schema"]
      rake jaml:convert[db/schema.yaml,db/schema.hcl]
    HELP
  end
end

# Default task shows help
task jaml: "jaml:help"

#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'time'

# Atlas Rails Bridge - Generate Rails migrations from Atlas schema changes
class AtlasRailsBridge
  RAILS_TYPE_MAPPING = {
    'integer' => 'integer',
    'varchar' => 'string',
    'text' => 'text',
    'boolean' => 'boolean',
    'datetime' => 'datetime',
    'date' => 'date',
    'decimal' => 'decimal',
    'binary' => 'binary',
    'bigint' => 'bigint',
    'float' => 'float',
    'time' => 'time'
  }.freeze

  def initialize(atlas_env: 'dev', rails_root: '.')
    @atlas_env = atlas_env
    @rails_root = rails_root
    @migrations_dir = File.join(@rails_root, 'db', 'migrate')
    @db_dir = File.join(@rails_root, 'db')
    FileUtils.mkdir_p(@migrations_dir)
    FileUtils.mkdir_p(@db_dir)
  end

  # Main method to generate migration from current schema to Atlas HCL target
  def generate_migration(migration_name = nil)
    migration_name ||= "atlas_schema_update"

    puts "🔄 Generating Atlas migration plan..."
    plan = get_atlas_migration_plan

    if plan.empty?
      puts "✅ No schema changes detected"
      return
    end

    puts "📝 Creating Rails migration..."
    create_rails_migration(migration_name, plan)
  end

  # Apply Atlas schema to database and sync Rails schema.rb
  def apply_schema!
    puts "🚀 Applying Atlas schema to database..."

    # Apply schema using Atlas
    result = system("atlas schema apply --env #{@atlas_env} --auto-approve")
    unless result
      puts "❌ Atlas schema apply failed"
      exit 1
    end

    # Update Rails schema.rb
    puts "📄 Updating Rails schema.rb..."
    system("cd #{@rails_root} && rails db:schema:dump")

    puts "✅ Schema applied successfully!"
  end

  # Preview what Atlas would change
  def preview_changes
    puts "🔍 Atlas migration plan:"
    system("atlas schema apply --env #{@atlas_env} --dry-run")
  end

  # Generate seed data from Atlas schema
  def generate_seed_data
    puts "🌱 Generating seed data for event types..."

    event_types = [
      {
        name: "Persuasive Speaking",
        abbreviation: "PERS",
        category: "speech",
        participant_type: "individual",
        max_participants_per_match: 8,
        description: "A speech designed to convince the audience of a particular viewpoint"
      },
      {
        name: "Informative Speaking",
        abbreviation: "INFO",
        category: "speech",
        participant_type: "individual",
        max_participants_per_match: 8,
        description: "A speech that educates the audience about a specific topic"
      },
      {
        name: "Original Oratory",
        abbreviation: "OO",
        category: "speech",
        participant_type: "individual",
        max_participants_per_match: 8,
        description: "An original speech on a topic of the speaker's choosing"
      },
      {
        name: "Duo Interpretation",
        abbreviation: "DUO",
        category: "interpretation",
        participant_type: "team",
        max_participants_per_match: 8,
        description: "A dramatic performance by two people"
      },
      {
        name: "Team Policy Debate",
        abbreviation: "TP",
        category: "debate",
        participant_type: "team",
        max_participants_per_match: 2,
        description: "A debate format with two-person teams arguing policy resolutions"
      },
      {
        name: "Lincoln Douglas Debate",
        abbreviation: "LD",
        category: "debate",
        participant_type: "individual",
        max_participants_per_match: 2,
        description: "A one-on-one debate format focusing on value and philosophical arguments"
      },
      {
        name: "Apologetics",
        abbreviation: "APOL",
        category: "speech",
        participant_type: "individual",
        max_participants_per_match: 8,
        description: "A defense of the Christian faith in response to questions"
      }
    ]

    seed_file = File.join(@db_dir, 'seeds.rb')

    seed_content = "# Event Types for Speech & Debate Tournaments\n\n"
    event_types.each do |event_type|
      seed_content += "EventType.find_or_create_by(name: '#{event_type[:name]}') do |event|\n"
      event_type.each do |key, value|
        next if key == :name
        if value.is_a?(String)
          seed_content += "  event.#{key} = '#{value}'\n"
        else
          seed_content += "  event.#{key} = #{value}\n"
        end
      end
      seed_content += "end\n\n"
    end

    File.write(seed_file, seed_content)
    puts "✅ Seed data written to #{seed_file}"
  end

  private

  def get_atlas_migration_plan
    # Get the SQL statements from Atlas dry run
    result = `atlas schema apply --env #{@atlas_env} --dry-run`

    if $?.exitstatus != 0
      puts "❌ Failed to get Atlas migration plan"
      return []
    end

    # Parse SQL statements from the dry-run output
    statements = []
    result.each_line do |line|
      # Look for lines that start with "    -> " which contain SQL
      if line.strip.start_with?('-> ') && line.include?('CREATE') || line.include?('ALTER') || line.include?('DROP')
        sql = line.strip.sub(/^-> /, '').strip
        statements << sql unless sql.empty?
      end
    end

    puts "Found #{statements.length} changes:"
    statements.each_with_index do |stmt, i|
      puts "  #{i + 1}. #{stmt}"
    end

    statements
  end

  def create_rails_migration(name, sql_statements)
    timestamp = Time.now.utc.strftime('%Y%m%d%H%M%S')
    filename = "#{timestamp}_#{name.downcase.gsub(/\s+/, '_')}.rb"
    filepath = File.join(@migrations_dir, filename)

    class_name = name.split(/\s+/).map(&:capitalize).join

    migration_content = generate_migration_content(class_name, sql_statements)

    File.write(filepath, migration_content)
    puts "✅ Created migration: #{filename}"
    puts "📂 Location: #{filepath}"

    # Show the migration content
    puts "\n📄 Migration content:"
    puts migration_content
  end

  def generate_migration_content(class_name, sql_statements)
    rails_version = get_rails_version

    content = <<~RUBY
      class #{class_name} < ActiveRecord::Migration[#{rails_version}]
        def up
    RUBY

    sql_statements.each do |stmt|
      rails_equivalent = convert_sql_to_rails(stmt)
      if rails_equivalent
        content += "    #{rails_equivalent}\n"
      else
        # Fallback to raw SQL for complex statements
        content += "    execute <<~SQL\n"
        content += "      #{stmt}\n"
        content += "    SQL\n"
      end
    end

    content += <<~RUBY
        end

        def down
          # Atlas handles rollbacks via schema state comparison
          # To rollback, revert your schema.hcl file and run atlas_rails_bridge again
          raise ActiveRecord::IrreversibleMigration
        end
      end
    RUBY

    content
  end

  def convert_sql_to_rails(sql_statement)
    sql = sql_statement.strip.upcase

    case sql
    when /^CREATE TABLE\s+["`]?(\w+)["`]?\s*\(/
      table_name = $1.downcase
      "create_table :#{table_name} do |t|"

    when /^DROP TABLE\s+["`]?(\w+)["`]?/
      table_name = $1.downcase
      "drop_table :#{table_name}"

    when /^ALTER TABLE\s+["`]?(\w+)["`]?\s+ADD COLUMN\s+["`]?(\w+)["`]?\s+(\w+)/
      table_name = $1.downcase
      column_name = $2.downcase
      column_type = convert_sql_type_to_rails($3.downcase)
      "add_column :#{table_name}, :#{column_name}, :#{column_type}"

    when /^ALTER TABLE\s+["`]?(\w+)["`]?\s+DROP COLUMN\s+["`]?(\w+)["`]?/
      table_name = $1.downcase
      column_name = $2.downcase
      "remove_column :#{table_name}, :#{column_name}"

    when /^CREATE INDEX\s+["`]?(\w+)["`]?\s+ON\s+["`]?(\w+)["`]?\s*\(\s*["`]?(\w+)["`]?\s*\)/
      index_name = $1
      table_name = $2.downcase
      column_name = $3.downcase
      "add_index :#{table_name}, :#{column_name}, name: '#{index_name}'"

    when /^CREATE UNIQUE INDEX\s+["`]?(\w+)["`]?\s+ON\s+["`]?(\w+)["`]?\s*\(\s*["`]?(\w+)["`]?\s*\)/
      index_name = $1
      table_name = $2.downcase
      column_name = $3.downcase
      "add_index :#{table_name}, :#{column_name}, name: '#{index_name}', unique: true"

    when /^DROP INDEX\s+["`]?(\w+)["`]?/
      index_name = $1
      "remove_index name: '#{index_name}'"

    else
      # Return nil for complex statements that need raw SQL
      nil
    end
  end

  def convert_sql_type_to_rails(sql_type)
    case sql_type.downcase
    when /varchar\((\d+)\)/
      "string, limit: #{$1}"
    when /decimal\((\d+),(\d+)\)/
      "decimal, precision: #{$1}, scale: #{$2}"
    when 'integer'
      'integer'
    when 'text'
      'text'
    when 'boolean'
      'boolean'
    when 'datetime'
      'datetime'
    when 'date'
      'date'
    when 'binary'
      'binary'
    when 'bigint'
      'bigint'
    else
      sql_type
    end
  end

  def get_rails_version
    "8.0" # Default for new Rails apps
  end
end

# CLI Interface
if __FILE__ == $0
  command = ARGV[0]

  bridge = AtlasRailsBridge.new

  case command
  when 'generate', 'g'
    migration_name = ARGV[1] || 'atlas_schema_update'
    bridge.generate_migration(migration_name)

  when 'apply'
    bridge.apply_schema!

  when 'preview', 'p'
    bridge.preview_changes

  when 'seed'
    bridge.generate_seed_data

  else
    puts <<~HELP
      Atlas Rails Bridge - Generate Rails migrations from Atlas HCL schema changes

      Usage:
        ruby lib/atlas_rails_bridge.rb <command> [options]

      Commands:
        generate [name]  Generate Rails migration from Atlas schema diff (alias: g)
        apply           Apply Atlas schema and update Rails schema.rb
        preview         Preview Atlas schema changes (alias: p)#{'  '}
        seed            Generate seed data for event types
      #{'  '}
      Examples:
        ruby lib/atlas_rails_bridge.rb generate "add tournament tables"
        ruby lib/atlas_rails_bridge.rb apply
        ruby lib/atlas_rails_bridge.rb preview
        ruby lib/atlas_rails_bridge.rb seed
    HELP
  end
end

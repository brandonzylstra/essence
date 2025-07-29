# frozen_string_literal: true

require "fileutils"
require "json"
require "time"

module Essence
  # Rails Bridge - Generate Rails migrations from schema changes
  class RailsBridge
    # Maps HCL/Atlas types to Rails migration types
    HCL_TO_RAILS_TYPE_MAPPING = {
      "integer" => "integer",
      "varchar" => "string",
      "text" => "text",
      "boolean" => "boolean",
      "datetime" => "datetime",
      "date" => "date",
      "decimal" => "decimal",
      "binary" => "binary",
      "bigint" => "bigint",
      "float" => "float",
      "time" => "time"
    }.freeze

    # Maps Rails migration types to HCL/Atlas types (for bidirectional support)
    RAILS_TO_HCL_TYPE_MAPPING = {
      "string" => "varchar",
      "text" => "text",
      "integer" => "integer",
      "bigint" => "bigint",
      "float" => "float",
      "decimal" => "decimal",
      "datetime" => "datetime",
      "timestamp" => "datetime", # Rails timestamp maps to datetime in HCL
      "time" => "time",
      "date" => "date",
      "binary" => "binary",
      "boolean" => "boolean"
    }.freeze

    def initialize(atlas_env: "dev", rails_root: ".")
      @atlas_env = atlas_env
      @rails_root = rails_root
      @migrations_dir = File.join(@rails_root, "db", "migrate")
      @db_dir = File.join(@rails_root, "db")

      begin
        FileUtils.mkdir_p(@migrations_dir)
        FileUtils.mkdir_p(@db_dir)
      rescue Errno::EACCES, Errno::EPERM => e
        puts "⚠️  Warning: Could not create directories (#{e.message})"
        # Continue initialization - directories will be created when needed
      end
    end

    # Main method to generate migration from current schema to HCL target
    def generate_migration(migration_name = nil)
      migration_name ||= "essence_schema_update"

      puts "🔄 Generating migration plan..."
      plan = get_atlas_migration_plan

      if plan.empty?
        puts "✅ No schema changes detected"
        return
      end

      puts "📝 Creating Rails migration..."
      create_rails_migration(migration_name, plan)
    end

    # Apply schema to database and sync Rails schema.rb
    def apply_schema!
      puts "🚀 Applying schema to database..."

      # Apply schema using Atlas
      result = system("atlas schema apply --env #{@atlas_env} --auto-approve")
      unless result
        puts "❌ Schema apply failed"
        raise StandardError, "Schema apply failed"
      end

      # Update Rails schema.rb
      puts "📄 Updating Rails schema.rb..."
      system("cd #{@rails_root} && rails db:schema:dump")

      puts "✅ Schema applied successfully!"
    end

    # Preview what would change
    def preview_changes
      puts "🔍 Migration plan:"
      system("atlas schema apply --env #{@atlas_env} --dry-run")
    end

    # Generate seed data from schema
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

      seed_file = File.join(@db_dir, "seeds.rb")

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

      begin
        File.write(seed_file, seed_content)
        puts "✅ Seed data written to #{seed_file}"
      rescue Errno::EACCES, Errno::EPERM => e
        puts "⚠️  Warning: Could not write seed file (#{e.message})"
        puts "💡 Check directory permissions for #{File.dirname(seed_file)}"
      rescue => e
        puts "⚠️  Warning: Failed to generate seed data (#{e.message})"
      end
    end

    ##################################################################################################

    private def get_atlas_migration_plan
      output, success = execute_atlas_command

      unless success
        puts "❌ Failed to get migration plan"
        return []
      end

      parse_atlas_output(output)
    end

    private def execute_atlas_command
      result = `atlas schema apply --env #{@atlas_env} --dry-run`
      [ result, $?.exitstatus == 0 ]
    end

    private def parse_atlas_output(output)
      # Parse SQL statements from the dry-run output
      statements = []
      output.each_line do |line|
        # Look for lines that start with "    -> " which contain SQL
        if line.strip.start_with?("-> ") && (line.include?("CREATE") || line.include?("ALTER") || line.include?("DROP"))
          sql = line.strip.sub(/^-> /, "").strip
          statements << sql unless sql.empty?
        end
      end

      puts "Found #{statements.length} changes:"
      statements.each_with_index do |stmt, i|
        puts "  #{i + 1}. #{stmt}"
      end

      statements
    end

    private def create_rails_migration(name, sql_statements)
      timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")

      # Generate filename with length limits (filesystem typically limits to 255 chars)
      filename_base = name.downcase.gsub(/[^a-z0-9_]+/, "_")
      max_filename_length = 240 - timestamp.length - 1 - 3  # Leave room for timestamp, underscore, and .rb

      if filename_base.length > max_filename_length
        # Truncate at word boundaries if possible
        truncated = filename_base[0, max_filename_length]
        last_underscore = truncated.rindex("_")
        if last_underscore && last_underscore > max_filename_length * 0.7
          filename_base = truncated[0, last_underscore]
        else
          filename_base = truncated
        end
        puts "⚠️  Warning: Migration filename truncated due to length limits"
      end

      filename = "#{timestamp}_#{filename_base}.rb"
      filepath = File.join(@migrations_dir, filename)

      class_name = format_class_name(name)

      migration_content = generate_migration_content(class_name, sql_statements)

      File.write(filepath, migration_content)
      puts "✅ Created migration: #{filename}"
      puts "📂 Location: #{filepath}"

      # Show the migration content
      puts "\n📄 Migration content:"
      puts migration_content
    end

    private def generate_migration_content(class_name, sql_statements)
      rails_version = get_rails_version

      formatted_class_name = format_class_name(class_name)
      content = <<~RUBY
        class #{formatted_class_name} < ActiveRecord::Migration[#{rails_version}]
          def up
      RUBY

      sql_statements.each do |stmt|
        rails_equivalent = convert_sql_to_rails(stmt)
        if rails_equivalent
          content += "      #{rails_equivalent}\n"
        else
          # Fallback to raw SQL for complex statements
          content += "      execute <<~SQL\n"
          content += "        #{stmt}\n"
          content += "      SQL\n"
        end
      end

      content += <<~RUBY
          end

          def down
            # Essence handles rollbacks via schema state comparison
            # To rollback, revert your schema.hcl file and run essence again
            raise ActiveRecord::IrreversibleMigration
          end
        end
      RUBY

      content
    end

    private def convert_sql_to_rails(sql_statement)
      sql = sql_statement.strip

      case sql
      when /^CREATE TABLE\s+["`]?(\w+)["`]?\s*\(/i
        table_name = $1.downcase
        "create_table :#{table_name} do |t|"

      when /^DROP TABLE\s+["`]?(\w+)["`]?/i
        table_name = $1.downcase
        "drop_table :#{table_name}"

      when /^ALTER TABLE\s+["`]?(\w+)["`]?\s+ADD COLUMN\s+["`]?(\w+)["`]?\s+(\w+(?:\(\d+(?:,\d+)?\))?)/i
        table_name = $1.downcase
        column_name = $2.downcase
        column_type = convert_sql_type_to_rails($3.downcase)
        "add_column :#{table_name}, :#{column_name}, :#{column_type}"

      when /^ALTER TABLE\s+["`]?(\w+)["`]?\s+DROP COLUMN\s+["`]?(\w+)["`]?/i
        table_name = $1.downcase
        column_name = $2.downcase
        "remove_column :#{table_name}, :#{column_name}"

      when /^CREATE INDEX\s+["`]?(\w+)["`]?\s+ON\s+["`]?(\w+)["`]?\s*\(\s*["`]?(\w+)["`]?\s*\)/i
        index_name = $1
        table_name = $2.downcase
        column_name = $3.downcase
        "add_index :#{table_name}, :#{column_name}, name: '#{index_name}'"

      when /^CREATE UNIQUE INDEX\s+["`]?(\w+)["`]?\s+ON\s+["`]?(\w+)["`]?\s*\(\s*["`]?(\w+)["`]?\s*\)/i
        index_name = $1
        table_name = $2.downcase
        column_name = $3.downcase
        "add_index :#{table_name}, :#{column_name}, name: '#{index_name}', unique: true"

      when /^DROP INDEX\s+["`]?(\w+)["`]?/i
        index_name = $1
        "remove_index name: '#{index_name}'"

      else
        # Return nil for complex statements that need raw SQL
        nil
      end
    end

    private def convert_sql_type_to_rails(sql_type)
      case sql_type.downcase
      when /varchar\((\d+)\)/
        "string, limit: #{$1}"
      when /decimal\((\d+),(\d+)\)/
        "decimal, precision: #{$1}, scale: #{$2}"
      when "integer"
        "integer"
      when "text"
        "text"
      when "boolean"
        "boolean"
      when "datetime"
        "datetime"
      when "date"
        "date"
      when "binary"
        "binary"
      when "bigint"
        "bigint"
      else
        sql_type
      end
    end

    private def get_rails_version
      "8.0" # Default for new Rails apps
    end

    private def format_class_name(name)
      # Convert migration name to proper Rails class name format
      # "add user tables" -> "AddUserTables"
      # "create_posts_table" -> "CreatePostsTable"

      # Clean and split the name into words
      cleaned_words = name.to_s
      .gsub(/[^a-zA-Z0-9_\s]/, "") # Remove special characters except underscores and spaces
      .split(/[\s_]+/)             # Split on spaces and underscores
      .reject(&:empty?)            # Remove empty strings
      .map(&:capitalize)           # Capitalize each word

      # If already in PascalCase format and short enough, return as-is
      if name.match?(/^[A-Z][a-zA-Z0-9]*$/) && name.length <= 80
        return name
      end

      # Intelligent truncation: try to keep complete words up to our limit
      class_name = ""
      cleaned_words.each do |word|
        # If adding this word would exceed our limit, stop
        if (class_name + word).length > 80
          break
        end
        class_name += word
      end

      # If we couldn't fit any complete words, take first 80 chars of first word
      if class_name.empty? && !cleaned_words.empty?
        class_name = cleaned_words.first[0, 80]
      end

      # Ensure we have something valid
      class_name.empty? ? "GeneratedMigration" : class_name
    end
  end
end

# CLI Interface
if __FILE__ == $0
  command = ARGV[0]

  bridge = Essence::RailsBridge.new

  case command
  when "generate", "g"
    migration_name = ARGV[1] || "essence_schema_update"
    bridge.generate_migration(migration_name)

  when "apply"
    bridge.apply_schema!

  when "preview", "p"
    bridge.preview_changes

  when "seed"
    bridge.generate_seed_data

  else
    puts <<~HELP
      Essence Rails Bridge - Generate Rails migrations from schema changes

      Usage:
        ruby lib/essence/rails_bridge.rb <command> [options]

      Commands:
        generate [name]  Generate Rails migration from schema diff (alias: g)
        apply           Apply schema and update Rails schema.rb
        preview         Preview schema changes (alias: p)#{'  '}
        seed            Generate seed data for event types
      #{'  '}
      Examples:
        ruby lib/essence/rails_bridge.rb generate "add tournament tables"
        ruby lib/essence/rails_bridge.rb apply
        ruby lib/essence/rails_bridge.rb preview
        ruby lib/essence/rails_bridge.rb seed
    HELP
  end
end

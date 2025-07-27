# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module Essence
  # Enhanced YAML to HCL Compiler
  # Compiles simplified YAML schema to HCL format with support for:
  # - Default columns for all tables
  # - Pattern-based column property inference
  # - Template generation for new schemas
  class Compiler
    # Supported ActiveRecord::Schema versions
    SUPPORTED_ACTIVERECORD_VERSIONS = ['8.0'].freeze

  def initialize(yaml_file = nil, hcl_file = nil)
    @yaml_file = yaml_file || find_schema_yaml_file
    @hcl_file = hcl_file || 'db/schema.hcl'
    @schema_data = nil
    @defaults = {}
    @column_patterns = {}
  end

  def compile!
    puts "🔄 Converting #{@yaml_file} to #{@hcl_file}..."

    load_yaml
    validate_rails_version
    parse_defaults_and_patterns
    generate_hcl

    puts "✅ Compilation completed successfully!"
    puts "📄 Atlas HCL schema written to #{@hcl_file}"
  end

    # Generate a new schema.yaml template with default patterns
    def self.generate_template(file_path = 'db/schema.yaml')
    template_content = <<~YAML
      # Enhanced Essence Schema with Default Columns and Pattern Matching
      # This file will be converted to HCL format automatically

      # Global settings
      schema_name: public

      # Default columns applied to all tables (unless overridden)
      defaults:
        "*":
          columns:
            id: primary_key
            created_at: datetime not_null
            updated_at: datetime not_null

      # Pattern-based column attribute inference - simplified syntax
      column_patterns:
        # Foreign key columns: _id suffix gets foreign key reference
        - "_id$": "integer -> {table}.id on_delete=cascade not_null"
        
        # Timestamp columns: _at suffix gets datetime not_null
        - "_at$": "datetime not_null"
        
        # Date columns: _on and _date suffixes get date type
        - "_on$": "date"
        - "_date$": "date"
        
        # Boolean columns: various prefixes get boolean with false default
        - "^is_": "boolean default=false not_null"
        - "^has_": "boolean default=false not_null"
        - "^can_": "boolean default=false not_null"
        - "_flag$": "boolean default=false not_null"
        
        # Text content columns: various suffixes get text type
        - "_content$": "text"
        - "_body$": "text"
        - "_text$": "text"
        - "_html$": "text"
        
        # Numeric columns: counters, scores, amounts, prices
        - "_count$": "integer default=0 not_null"
        - "_score$": "decimal(8,2)"
        - "_amount$": "decimal(10,2)"
        - "_price$": "decimal(10,2)"
        
        # String columns: emails, URLs, codes, slugs
        - "_email$": "string(255)"
        - "_url$": "string(500)"
        - "_code$": "string(50)"
        - "_slug$": "string(255) unique"
        - "_status$": "string(50)"
        - "_state$": "string(50)"
            
        # Default fallback: unmatched columns become strings
        - ".*": "string"

      # Table definitions
      tables:
        # Example table showing how defaults and patterns work
        users:
          columns:
            # id, created_at, updated_at automatically added from defaults
            email: string(255) not_null unique
            first_name: string(100) not_null
            last_name: string(100) not_null
            # league_id automatically becomes: integer -> leagues.id on_delete=cascade not_null
            league_id: ~  # ~ means "use pattern matching"
            # last_login_at automatically becomes: datetime not_null
            last_login_at: ~
            # Pattern matching examples:
            birth_date: ~           # Becomes: date
            is_active: ~            # Becomes: boolean default=false not_null
            has_premium: ~          # Becomes: boolean default=false not_null
            view_count: ~           # Becomes: integer default=0 not_null
            backup_email: ~         # Becomes: string(255)
            website_url: ~          # Becomes: string(500)
            user_slug: ~            # Becomes: string(255) unique
            account_status: ~       # Becomes: string(20) default='pending' not_null
            # bio will become: string (from default pattern)
            bio: ~
          indexes:
            - email
            - league_id
            - user_slug

        posts:
          columns:
            # id, created_at, updated_at automatically added from defaults
            title: string(255) not_null
            # More pattern matching examples:
            user_id: ~              # Becomes: integer -> users.id on_delete=cascade not_null
            published_at: ~         # Becomes: datetime not_null
            due_on: ~               # Becomes: date
            post_content: ~         # Becomes: text
            view_count: ~           # Becomes: integer default=0 not_null
            rating_score: ~         # Becomes: decimal(8,2)
            is_published: ~         # Becomes: boolean default=false not_null
            post_slug: ~            # Becomes: string(255) unique
            post_status: ~          # Becomes: string(20) default='pending' not_null
          indexes:
            - user_id
            - post_slug
            - is_published

        leagues:
          columns:
            # id, created_at, updated_at automatically added from defaults
            name: string(255) not_null unique
            abbreviation: string(10)
            description: text
            website_url: ~          # Becomes: string(500)
            contact_email: ~        # Becomes: string(255)
            is_active: ~            # Becomes: boolean default=false not_null

      # Seed data definitions (optional)
      seeds:
        # Add seed data here if needed
    YAML

    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(file_path, template_content)

    puts "✅ Schema template created at #{file_path}"
    puts "📝 Edit this file to define your database schema"
    puts "🔧 Run 'rake essence:compile' to compile to HCL format"
    end

  private

  def validate_rails_version
    rails_version = @schema_data['rails_version']
    return unless rails_version

    unless SUPPORTED_ACTIVERECORD_VERSIONS.include?(rails_version.to_s)
      supported_list = SUPPORTED_ACTIVERECORD_VERSIONS.map { |v| "ActiveRecord::Schema[#{v}]" }.join(', ')
      raise "Unsupported rails_version '#{rails_version}'. Currently supported versions: #{supported_list}. " \
            "Please remove rails_version from your schema.yaml or use a supported version."
    end
  end

  def find_schema_yaml_file
    # Prefer .yaml extension over .yml, and db/ directory over root
    candidates = [
      'db/schema.yaml',
      'db/schema.yml',
      'schema.yaml',
      'schema.yml'
    ]

    candidates.each do |file|
      return file if File.exist?(file)
    end

    # Default to preferred location/extension if none exist
    'db/schema.yaml'
  end

  def load_yaml
    unless File.exist?(@yaml_file)
      puts "❌ YAML file #{@yaml_file} not found!"
      puts "💡 Run 'rake essence:template' to create a new schema file"
      exit 1
    end

    @schema_data = YAML.load_file(@yaml_file)
    puts "📖 Loaded YAML schema with #{@schema_data['tables']&.keys&.length || 0} tables"
  end

  def parse_defaults_and_patterns
    # Parse default columns
    if @schema_data['defaults']
      @defaults = @schema_data['defaults']
      puts "🔧 Loaded default columns for #{@defaults.keys.length} patterns"
    end

    # Parse column patterns
    if @schema_data['column_patterns']
      # Pattern-based column property inference
      @column_patterns = @schema_data['column_patterns'].filter_map do |pattern_def|
        begin
          # Support both old and new syntax
          if pattern_def.is_a?(Hash) && pattern_def.key?('pattern')
            # Old verbose syntax: {pattern: "_id$", properties: "integer not_null"}
            {
              regex: Regexp.new(pattern_def['pattern']),
              template: pattern_def['template'],
              properties: pattern_def['properties'] || pattern_def['attributes'], # Support both for migration
              description: pattern_def['description']
            }
          elsif pattern_def.is_a?(Hash) && pattern_def.keys.length == 1
            # New simplified syntax: {"_id$": "integer not_null"}
            pattern, properties = pattern_def.first
            {
              regex: Regexp.new(pattern),
              template: nil,
              properties: properties,
              description: nil
            }
          else
            puts "⚠️  Skipping invalid pattern definition: #{pattern_def.inspect}"
            nil
          end
        rescue RegexpError => e
          pattern_key = pattern_def.is_a?(Hash) && pattern_def.key?('pattern') ? pattern_def['pattern'] : pattern_def.keys.first
          puts "⚠️  Skipping invalid regex pattern '#{pattern_key}': #{e.message}"
          nil
        end
      end
      puts "🎯 Loaded #{@column_patterns.length} column patterns"
    else
      # Set default patterns if none specified
      @column_patterns = default_column_patterns
      puts "🎯 Using default column patterns"
    end
  end

  def default_column_patterns
    [
      {
        regex: Regexp.new("_id$"),
        template: "integer -> {table}.id on_delete=cascade not_null",
        description: "Foreign key columns automatically reference the related table"
      },
      {
        regex: Regexp.new("_at$"),
        attributes: "datetime not_null",
        description: "Timestamp columns get datetime type with not_null constraint"
      },
      {
        regex: Regexp.new(".*"),
        attributes: "string",
        description: "Default type for columns that don't match other patterns"
      }
    ]
  end

  def generate_hcl
    hcl_content = generate_hcl_header
    hcl_content += generate_schema_block
    hcl_content += generate_table_blocks

    File.write(@hcl_file, hcl_content)
  end

  def generate_hcl_header
    <<~HCL
      # Auto-generated HCL schema from #{@yaml_file}
      # Edit the YAML file and re-run the converter to update this file

    HCL
  end

  def generate_schema_block
    schema_name = @schema_data['schema_name'] || 'public'
    <<~HCL
      schema "#{schema_name}" {}

    HCL
  end

  def generate_table_blocks
    return "" unless @schema_data['tables']

    hcl_content = ""

    @schema_data['tables'].each do |table_name, table_def|
      # Merge default columns with table-specific columns
      merged_columns = merge_default_columns(table_name, table_def)
      table_def_with_defaults = table_def.merge('columns' => merged_columns)

      hcl_content += generate_table_block(table_name, table_def_with_defaults)
      hcl_content += "\n"
    end

    hcl_content
  end

  def merge_default_columns(table_name, table_def)
    # Start with default columns for all tables (*)
    merged = {}

    # Apply defaults from "*" pattern
    if @defaults['*'] && @defaults['*']['columns']
      merged.merge!(@defaults['*']['columns'])
    end

    # Apply table-specific defaults if they exist
    if @defaults[table_name] && @defaults[table_name]['columns']
      merged.merge!(@defaults[table_name]['columns'])
    end

    # Apply explicit table columns (these override defaults)
    if table_def['columns']
      table_def['columns'].each do |column_name, column_def|
        if column_def.nil? || column_def == '~'
          # Use pattern matching for nil or ~ values
          merged[column_name] = infer_column_properties(column_name, table_name)
        else
          # Use explicit definition
          merged[column_name] = column_def
        end
      end
    end

    merged
  end

  def infer_column_properties(column_name, table_name)
    @column_patterns.each do |pattern|
      if column_name.match?(pattern[:regex])
        if pattern[:template]
          # Handle template with variable substitution
          return expand_template(pattern[:template], column_name, table_name)
        elsif pattern[:properties]
          # Check if properties contains template variables
          if pattern[:properties].include?('{table}')
            return expand_template(pattern[:properties], column_name, table_name)
          else
            # Use direct properties
            return pattern[:properties]
          end
        end
      end
    end

    # Fallback to string if no patterns match
    "string"
  end

  def expand_template(template, column_name, table_name)
    # Extract the table name from column name (e.g., "league_id" -> "leagues")
    if column_name.match(/^(.+)_id$/)
      referenced_table = pluralize($1)
      return template.gsub('{table}', referenced_table)
    end
    template
  end

  def pluralize(word)
    # Simple pluralization rules - could be enhanced with a proper library
    case word
    when /y$/
      word.sub(/y$/, 'ies')
    when /s$/, /sh$/, /ch$/, /x$/, /z$/
      word + 'es'
    when /f$/
      word.sub(/f$/, 'ves')
    when /fe$/
      word.sub(/fe$/, 'ves')
    else
      word + 's'
    end
  end

  def generate_table_block(table_name, table_def)
    schema_name = @schema_data['schema_name'] || 'public'

    hcl = <<~HCL
      table "#{table_name}" {
        schema = schema.#{schema_name}
    HCL

    # Generate columns
    if table_def['columns']
      table_def['columns'].each do |column_name, column_def|
        hcl += generate_column_block(column_name, column_def)
      end
    end

    # Generate primary key (if not already defined as primary_key type)
    primary_key_column = find_primary_key_column(table_def['columns'])
    if primary_key_column
      hcl += generate_primary_key_block(primary_key_column)
    end

    # Generate foreign keys
    foreign_keys = extract_foreign_keys(table_def['columns'])
    foreign_keys.each do |fk|
      hcl += generate_foreign_key_block(fk, table_name)
    end

    # Generate indexes
    if table_def['indexes']
      table_def['indexes'].each do |index_def|
        hcl += generate_index_block(index_def, table_name)
      end
    end

    hcl += "}\n"
    hcl
  end

  def generate_column_block(column_name, column_def)
    # Handle primary key columns specially but still generate them
    if column_def == 'primary_key'
      parsed = { type: 'integer', not_null: true, hcl_type: 'integer' }
    else
      parsed = parse_column_definition(column_def)
    end

    hcl = <<~HCL
      column "#{column_name}" {
    HCL

    # Add null constraint
    if parsed[:not_null]
      hcl += "    null = false\n"
    else
      hcl += "    null = true\n" unless parsed[:type] == 'primary_key'
    end

    # Add type
    hcl += "    type = #{parsed[:hcl_type]}\n"

    # Add auto_increment for primary keys
    if column_def == 'primary_key' || (parsed[:type] == 'integer' && column_name == 'id')
      hcl += "    auto_increment = true\n"
    end

    # Add default value
    if parsed[:default]
      hcl += "    default = #{parsed[:default]}\n"
    end

    hcl += "  }\n"
    hcl
  end

  def parse_column_definition(column_def)
    return { type: 'primary_key' } if column_def == 'primary_key'

    # Handle foreign key references
    if column_def.include?('->')
      parts = column_def.split('->')
      base_def = parts[0].strip
      reference = parts[1].strip

      parsed = parse_simple_column_def(base_def)
      parsed[:foreign_key] = parse_foreign_key_reference(reference)
      return parsed
    end

    parse_simple_column_def(column_def)
  end

  def parse_simple_column_def(def_str)
    result = {
      not_null: false,
      unique: false,
      default: nil
    }

    # Extract type and size
    if def_str.match(/^(\w+)(?:\(([^)]+)\))?/)
      base_type = $1
      size_info = $2

      result[:type] = base_type
      result[:hcl_type] = convert_type_to_hcl(base_type, size_info)
    end

    # Check for modifiers
    result[:not_null] = true if def_str.include?('not_null')
    result[:unique] = true if def_str.include?('unique')

    # Extract default value
    if def_str.match(/default=([^\s]+)/)
      default_val = $1
      result[:default] = format_default_value(default_val)
    end

    result
  end

  def convert_type_to_hcl(type, size_info)
    case type
    when 'string'
      size_info ? "varchar(#{size_info})" : "varchar"
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
    when 'decimal'
      size_info ? "decimal(#{size_info})" : "decimal"
    when 'binary'
      size_info ? "binary(#{size_info})" : "binary"
    else
      type
    end
  end

  def format_default_value(value)
    case value.downcase
    when 'true'
      'true'
    when 'false'
      'false'
    when /^\d+$/
      value
    when /^\d+\.\d+$/
      value
    else
      # Remove existing quotes if present, then add our own
      cleaned_value = value.to_s.gsub(/^['"]|['"]$/, '')
      "\"#{cleaned_value}\""
    end
  end

  def parse_foreign_key_reference(reference)
    # Format: "leagues.id on_delete=cascade"
    parts = reference.split(' ')
    table_column = parts[0] # "leagues.id"

    table, column = table_column.split('.')

    fk = {
      ref_table: table,
      ref_column: column
    }

    # Parse on_delete action
    parts.each do |part|
      if part.start_with?('on_delete=')
        action = part.split('=')[1]
        fk[:on_delete] = action.upcase.gsub('_', ' ')
      end
    end

    fk
  end

  def find_primary_key_column(columns)
    return nil unless columns

    columns.each do |column_name, column_def|
      return column_name if column_def == 'primary_key'
    end

    # Default to 'id' if no explicit primary key and id column exists
    return 'id' if columns&.key?('id')

    nil
  end

  def generate_primary_key_block(column_name)
    <<~HCL
      primary_key {
        columns = [column.#{column_name}]
      }
    HCL
  end

  def extract_foreign_keys(columns)
    return [] unless columns

    foreign_keys = []

    columns.each do |column_name, column_def|
      next if column_def == 'primary_key'

      parsed = parse_column_definition(column_def)
      if parsed[:foreign_key]
        fk = parsed[:foreign_key].merge(
          column: column_name,
          constraint_name: "fk_#{@current_table_name}_#{column_name}"
        )
        foreign_keys << fk
      end
    end

    foreign_keys
  end

  def generate_foreign_key_block(fk, table_name)
    constraint_name = "fk_#{table_name}_#{fk[:column]}"

    hcl = <<~HCL
      foreign_key "#{constraint_name}" {
        columns = [column.#{fk[:column]}]
        ref_columns = [table.#{fk[:ref_table]}.column.#{fk[:ref_column]}]
    HCL

    if fk[:on_delete]
      case fk[:on_delete].downcase
      when 'set null', 'set_null'
        hcl += "    on_delete = SET_NULL\n"
      when 'cascade'
        hcl += "    on_delete = CASCADE\n"
      when 'restrict'
        hcl += "    on_delete = RESTRICT\n"
      end
    end

    hcl += "  }\n"
    hcl
  end

  def generate_index_block(index_def, table_name)
    if index_def.is_a?(String)
      # Simple single-column index
      column_name = index_def
      index_name = "index_#{table_name}_on_#{column_name}"

      <<~HCL
      index "#{index_name}" {
        columns = [column.#{column_name}]
      }
      HCL

    elsif index_def.is_a?(Hash)
      # New hash format with columns and options
      columns = index_def['columns'] || []
      is_unique = index_def['unique'] || false

      if columns.is_a?(Array) && columns.length > 0
        column_names = columns.join('_and_')
        index_name = "index_#{table_name}_on_#{column_names}"
        index_name += '_unique' if is_unique

        hcl = <<~HCL
        index "#{index_name}" {
          columns = [#{columns.map { |col| "column.#{col}" }.join(', ')}]
        HCL

        hcl += "    unique = true\n" if is_unique
        hcl += "  }\n"
        hcl
      else
        ""
      end

    elsif index_def.is_a?(Array)
      # Multi-column index or index with options (legacy format)
      if index_def.length == 1 && index_def[0].is_a?(String)
        # Single column in array format
        column_name = index_def[0]
        index_name = "index_#{table_name}_on_#{column_name}"

        <<~HCL
        index "#{index_name}" {
          columns = [column.#{column_name}]
        }
        HCL
      else
        # Multi-column index
        columns = index_def.reject { |item| item.is_a?(String) && item == 'unique' }
        is_unique = index_def.include?('unique')

        column_names = columns.join('_and_')
        index_name = "index_#{table_name}_on_#{column_names}"
        index_name += '_unique' if is_unique

        hcl = <<~HCL
        index "#{index_name}" {
          columns = [#{columns.map { |col| "column.#{col}" }.join(', ')}]
        HCL

        hcl += "    unique = true\n" if is_unique
        hcl += "  }\n"
        hcl
      end
    end
  end
end

# CLI Interface
if __FILE__ == $0
  command = ARGV[0]
  
  case command
  when 'template', 't'
    file_path = ARGV[1] || 'db/schema.yaml'
    Essence::Compiler.generate_template(file_path)
  when 'compile', 'c'
    yaml_file = ARGV[1]
    hcl_file = ARGV[2]
    compiler = Essence::Compiler.new(yaml_file, hcl_file)
    compiler.compile!
  else
    yaml_file = ARGV[0]
    hcl_file = ARGV[1]
    compiler = Essence::Compiler.new(yaml_file, hcl_file)
    compiler.compile!
  end
end

end

#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'fileutils'

# YAML to Atlas HCL Converter
# Converts simplified YAML schema to Atlas HCL format
class YamlToHclConverter
  def initialize(yaml_file = nil, hcl_file = nil)
    @yaml_file = yaml_file || find_schema_yaml_file
    @hcl_file = hcl_file || 'db/schema.hcl'
    @schema_data = nil
  end

  def convert!
    puts "🔄 Converting #{@yaml_file} to #{@hcl_file}..."
    
    load_yaml
    generate_hcl
    
    puts "✅ Conversion complete!"
    puts "📄 Atlas HCL schema written to #{@hcl_file}"
  end

  private

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
      exit 1
    end

    @schema_data = YAML.load_file(@yaml_file)
    puts "📖 Loaded YAML schema with #{@schema_data['tables']&.keys&.length || 0} tables"
  end

  def generate_hcl
    hcl_content = generate_hcl_header
    hcl_content += generate_schema_block
    hcl_content += generate_table_blocks
    
    File.write(@hcl_file, hcl_content)
  end

  def generate_hcl_header
    <<~HCL
      # Auto-generated Atlas HCL schema from #{@yaml_file}
      # Edit the YAML file and re-run the converter to update this file
      
    HCL
  end

  def generate_schema_block
    schema_name = @schema_data['schema_name'] || 'main'
    <<~HCL
      schema "#{schema_name}" {}

    HCL
  end

  def generate_table_blocks
    return "" unless @schema_data['tables']

    hcl_content = ""
    
    @schema_data['tables'].each do |table_name, table_def|
      hcl_content += generate_table_block(table_name, table_def)
      hcl_content += "\n"
    end
    
    hcl_content
  end

  def generate_table_block(table_name, table_def)
    schema_name = @schema_data['schema_name'] || 'main'
    
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
    return "" if column_def == 'primary_key' # Handle primary keys separately

    parsed = parse_column_definition(column_def)
    
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
    if parsed[:type] == 'integer' && column_name == 'id'
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
      "'#{value}'"
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
    
    # Default to 'id' if no explicit primary key
    return 'id' if columns['id']
    
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
  yaml_file = ARGV[0]
  hcl_file = ARGV[1]
  
  converter = YamlToHclConverter.new(yaml_file, hcl_file)
  converter.convert!
end
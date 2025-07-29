# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'HCL Formatting and Indentation' do
  describe 'proper indentation' do
    context 'basic table structure' do
      it 'properly indents table blocks' do
        schema_content = <<~YAML
          schema_name: public
          tables:
            users:
              columns:
                id: primary_key
                email: string(255) not_null
        YAML

        create_test_yaml(schema_content)
        compiler = Essence::Compiler.new
        compiler.compile!
        hcl_content = read_generated_hcl

        # Table block should start at column 0
        expect(hcl_content).to match(/^table "users" \{$/)
        
        # Table content should be indented 2 spaces
        expect(hcl_content).to match(/^  schema = schema\.public$/)
        
        # Column blocks should be indented 2 spaces
        expect(hcl_content).to match(/^  column "id" \{$/)
        expect(hcl_content).to match(/^  column "email" \{$/)
        
        # Column content should be indented 4 spaces
        expect(hcl_content).to match(/^    null = false$/)
        expect(hcl_content).to match(/^    type = integer$/)
        expect(hcl_content).to match(/^    auto_increment = true$/)
        
        # Closing braces should align with their opening blocks
        expect(hcl_content).to match(/^  \}$/)  # Column closing brace at 2 spaces
        expect(hcl_content).to match(/^\}$/)    # Table closing brace at 0 spaces
      end
    end

    context 'nested blocks' do
      it 'properly indents foreign key blocks' do
        schema_content = <<~YAML
          schema_name: public
          column_patterns:
            - "_id$": "integer -> {table}.id on_delete=cascade not_null"
          tables:
            users:
              columns:
                id: primary_key
                name: string(100) not_null
            posts:
              columns:
                id: primary_key
                title: string(255) not_null
                user_id: ~
        YAML

        create_test_yaml(schema_content)
        compiler = Essence::Compiler.new
        compiler.compile!
        hcl_content = read_generated_hcl

        # Foreign key block should be indented 2 spaces
        expect(hcl_content).to match(/^  foreign_key "fk_posts_user_id" \{$/)
        
        # Foreign key content should be indented 4 spaces
        expect(hcl_content).to match(/^    columns = \[column\.user_id\]$/)
        expect(hcl_content).to match(/^    ref_columns = \[table\.users\.column\.id\]$/)
        expect(hcl_content).to match(/^    on_delete = CASCADE$/)
        
        # Foreign key closing brace should be at 2 spaces
        expect(hcl_content).to match(/^  \}$/)
      end

      it 'properly indents primary key blocks' do
        schema_content = <<~YAML
          schema_name: public
          tables:
            users:
              columns:
                id: primary_key
                email: string(255) not_null
        YAML

        create_test_yaml(schema_content)
        compiler = Essence::Compiler.new
        compiler.compile!
        hcl_content = read_generated_hcl

        # Primary key block should be indented 2 spaces
        expect(hcl_content).to match(/^  primary_key \{$/)
        
        # Primary key content should be indented 4 spaces
        expect(hcl_content).to match(/^    columns = \[column\.id\]$/)
        
        # Primary key closing brace should be at 2 spaces
        expect(hcl_content).to match(/^  \}$/)
      end

      it 'properly indents index blocks' do
        schema_content = <<~YAML
          schema_name: public
          tables:
            users:
              columns:
                id: primary_key
                email: string(255) not_null
                username: string(50) not_null
              indexes:
                - email
                - columns: [username]
                  unique: true
        YAML

        create_test_yaml(schema_content)
        compiler = Essence::Compiler.new
        compiler.compile!
        hcl_content = read_generated_hcl

        # Index blocks should be indented 2 spaces
        expect(hcl_content).to match(/^  index "index_users_on_email" \{$/)
        expect(hcl_content).to match(/^  index "index_users_on_username_unique" \{$/)
        
        # Index content should be indented 4 spaces
        expect(hcl_content).to match(/^    columns = \[column\.email\]$/)
        expect(hcl_content).to match(/^    columns = \[column\.username\]$/)
        expect(hcl_content).to match(/^    unique = true$/)
        
        # Index closing braces should be at 2 spaces
        lines = hcl_content.lines
        index_sections = lines.select { |line| line.strip.start_with?('index ') }
        
        index_sections.each do |index_line|
          index_start = lines.index(index_line)
          # Find the next closing brace after this index
          closing_brace_line = lines[index_start..-1].find { |line| line.match(/^  \}$/) }
          expect(closing_brace_line).not_to be_nil, "Index block should have properly indented closing brace"
        end
      end
    end

    context 'complex schemas with multiple nested blocks' do
      it 'maintains consistent indentation throughout' do
        schema_content = <<~YAML
          schema_name: public
          defaults:
            "*":
              columns:
                id: primary_key
                created_at: datetime not_null
                updated_at: datetime not_null
          column_patterns:
            - "_id$": "integer -> {table}.id on_delete=cascade not_null"
          tables:
            users:
              columns:
                email: string(255) not_null unique
                name: string(100) not_null
            posts:
              columns:
                title: string(255) not_null
                content: text
                user_id: ~
              indexes:
                - title
                - user_id
            comments:
              columns:
                content: text not_null
                post_id: ~
                user_id: ~
        YAML

        create_test_yaml(schema_content)
        compiler = Essence::Compiler.new
        compiler.compile!
        hcl_content = read_generated_hcl

        lines = hcl_content.lines.map(&:rstrip)

        # Check that no line has inconsistent indentation
        lines.each_with_index do |line, index|
          next if line.empty?

          # Count leading spaces
          leading_spaces = line.length - line.lstrip.length

          # Indentation should always be a multiple of 2
          expect(leading_spaces % 2).to eq(0), 
            "Line #{index + 1} has odd indentation (#{leading_spaces} spaces): '#{line}'"

          # Check specific indentation patterns
          case line.strip
          when /^(schema|table) ".+" \{/
            expect(leading_spaces).to eq(0), 
              "Schema/table declarations should not be indented: '#{line}'"
          when /^(column|primary_key|foreign_key|index) /
            expect(leading_spaces).to eq(2), 
              "Block declarations should be indented 2 spaces: '#{line}'"
          when /^schema = schema\./
            expect(leading_spaces).to eq(2), 
              "Table-level schema assignment should be indented 2 spaces: '#{line}'"
          when /^(columns|ref_columns|on_delete|null|type|auto_increment|default|unique) =/
            expect(leading_spaces).to eq(4), 
              "Property assignments should be indented 4 spaces: '#{line}'"
          when /^\}$/
            expect([0, 2]).to include(leading_spaces), 
              "Closing braces should be at 0 or 2 spaces: '#{line}'"
          end
        end
      end
    end

    context 'brace alignment' do
      it 'properly aligns opening and closing braces' do
        schema_content = <<~YAML
          schema_name: public
          tables:
            users:
              columns:
                id: primary_key
                email: string(255) not_null
                created_at: datetime not_null
        YAML

        create_test_yaml(schema_content)
        compiler = Essence::Compiler.new
        compiler.compile!
        hcl_content = read_generated_hcl

        lines = hcl_content.lines.map(&:rstrip)
        brace_stack = []

        lines.each_with_index do |line, index|
          next if line.empty?

          # Handle inline braces like "schema "public" {}" - these are self-contained
          if line.strip.end_with?('{}')
            # Skip lines with inline braces as they are self-contained
            next
          elsif line.include?('{')
            # Opening brace - record its indentation
            leading_spaces = line.length - line.lstrip.length
            brace_stack.push({ line: index + 1, indent: leading_spaces, content: line.strip })
          elsif line.strip == '}'
            # Closing brace - should match the most recent opening brace
            expect(brace_stack).not_to be_empty, 
              "Closing brace on line #{index + 1} has no matching opening brace"

            opening_brace = brace_stack.pop
            closing_spaces = line.length - line.lstrip.length

            expect(closing_spaces).to eq(opening_brace[:indent]), 
              "Closing brace on line #{index + 1} (#{closing_spaces} spaces) doesn't align with " \
              "opening brace on line #{opening_brace[:line]} (#{opening_brace[:indent]} spaces): '#{opening_brace[:content]}'"
          end
        end

        # All braces should be matched
        expect(brace_stack).to be_empty, 
          "Unmatched opening braces: #{brace_stack.map { |b| "line #{b[:line]}: #{b[:content]}" }.join(', ')}"
      end

      it 'prevents double-indented closing braces' do
        schema_content = <<~YAML
          schema_name: public
          tables:
            users:
              columns:
                id: primary_key
                email: string(255) not_null
            posts:
              columns:
                id: primary_key
                title: string(255) not_null
        YAML

        create_test_yaml(schema_content)
        compiler = Essence::Compiler.new
        compiler.compile!
        hcl_content = read_generated_hcl

        lines = hcl_content.lines

        # Look for the specific pattern that was mentioned in the issue:
        # two levels of curly braces closing where both are at the beginning of the line
        consecutive_closing_braces = []
        
        lines.each_with_index do |line, index|
          if line.strip == '}'
            # Check if the next non-empty line is also a closing brace
            next_lines = lines[index + 1..-1]
            next_non_empty = next_lines.find { |l| !l.strip.empty? }
            
            if next_non_empty&.strip == '}'
              consecutive_closing_braces << {
                first_line: index + 1,
                first_indent: line.length - line.lstrip.length,
                second_line: index + 1 + lines[index + 1..-1].index(next_non_empty) + 1,
                second_indent: next_non_empty.length - next_non_empty.lstrip.length
              }
            end
          end
        end

        # Check that consecutive closing braces have proper indentation
        consecutive_closing_braces.each do |pair|
          expect(pair[:first_indent]).to be > pair[:second_indent], 
            "Consecutive closing braces on lines #{pair[:first_line]} and #{pair[:second_line]} " \
            "have incorrect indentation: first=#{pair[:first_indent]}, second=#{pair[:second_indent]}. " \
            "Inner blocks should be indented more than outer blocks."
        end
      end
    end

    context 'whitespace consistency' do
      it 'uses consistent spacing around equals signs' do
        schema_content = <<~YAML
          schema_name: public
          tables:
            users:
              columns:
                id: primary_key
                email: string(255) not_null
                is_active: boolean default=true not_null
        YAML

        create_test_yaml(schema_content)
        compiler = Essence::Compiler.new
        compiler.compile!
        hcl_content = read_generated_hcl

        # All property assignments should have format: "property = value"
        assignment_lines = hcl_content.lines.select { |line| line.include?(' = ') }
        expect(assignment_lines).not_to be_empty

        assignment_lines.each do |line|
          # Should have exactly one space before and after equals
          expect(line).to match(/\S+ = \S/), 
            "Assignment should have single space around equals: '#{line.strip}'"
          expect(line).not_to match(/\S+=\S/), 
            "Assignment should not have no spaces around equals: '#{line.strip}'"
          expect(line).not_to match(/\S+  =  \S/), 
            "Assignment should not have multiple spaces around equals: '#{line.strip}'"
        end
      end

      it 'maintains consistent blank lines between sections' do
        schema_content = <<~YAML
          schema_name: public
          tables:
            users:
              columns:
                id: primary_key
                email: string(255) not_null
            posts:
              columns:
                id: primary_key
                title: string(255) not_null
        YAML

        create_test_yaml(schema_content)
        compiler = Essence::Compiler.new
        compiler.compile!
        hcl_content = read_generated_hcl

        lines = hcl_content.lines

        # Find table boundaries
        table_starts = lines.each_with_index.select { |line, _| line.match(/^table /) }.map(&:last)
        
        # There should be exactly one blank line between tables (if multiple tables)
        if table_starts.length > 1
          table_starts[1..-1].each do |table_start_index|
            # The line before the table should be blank
            expect(lines[table_start_index - 1].strip).to eq(''), 
              "There should be a blank line before table on line #{table_start_index + 1}"
          end
        end
      end
    end

    context 'edge cases' do
      it 'handles empty tables correctly' do
        schema_content = <<~YAML
          schema_name: public
          tables:
            empty_table:
              columns: {}
        YAML

        create_test_yaml(schema_content)
        compiler = Essence::Compiler.new
        compiler.compile!
        hcl_content = read_generated_hcl

        # Even empty tables should have proper structure
        expect(hcl_content).to match(/^table "empty_table" \{$/)
        expect(hcl_content).to match(/^  schema = schema\.public$/)
        expect(hcl_content).to match(/^\}$/)
      end

      it 'handles tables with only default columns' do
        schema_content = <<~YAML
          schema_name: public
          defaults:
            "*":
              columns:
                id: primary_key
                created_at: datetime not_null
          tables:
            simple_table:
              columns: {}
        YAML

        create_test_yaml(schema_content)
        compiler = Essence::Compiler.new
        compiler.compile!
        hcl_content = read_generated_hcl

        # Should still maintain proper indentation for default columns
        expect(hcl_content).to match(/^  column "id" \{$/)
        expect(hcl_content).to match(/^    type = integer$/)
        expect(hcl_content).to match(/^  \}$/)
        expect(hcl_content).to match(/^  column "created_at" \{$/)
        expect(hcl_content).to match(/^\}$/)
      end
    end
  end

  describe 'HCL syntax compliance' do
    it 'generates valid HCL syntax' do
      create_basic_schema
      compiler = Essence::Compiler.new
      compiler.compile!
      hcl_content = read_generated_hcl

      # Basic syntax checks
      expect(hcl_content).not_to match(/\{\s*\{/), "Should not have consecutive opening braces"
      
      # Check for problematic consecutive closing braces (same indentation level)
      lines = hcl_content.lines
      lines.each_with_index do |line, index|
        if line.strip == '}' && index < lines.length - 1
          next_line = lines[index + 1]
          if next_line&.strip == '}'
            current_indent = line.length - line.lstrip.length
            next_indent = next_line.length - next_line.lstrip.length
            expect(current_indent).not_to eq(next_indent), 
              "Consecutive closing braces should have different indentation levels (lines #{index + 1} and #{index + 2})"
          end
        end
      end
      
      # Check that string literals with spaces or special characters are properly quoted
      # Skip complex validation of all HCL types - focus on obvious cases
      string_values = hcl_content.scan(/= ([^,\]\}\s\n]+)/).flatten
      string_values.each do |value|
        # Only check that values containing spaces or starting with special chars are quoted
        if value.include?(' ') || value.match(/^[^a-zA-Z0-9_\[\.]/)
          expect(value).to match(/^".*"$/), "String value with spaces/special chars should be quoted: #{value}"
        end
      end

      # Check that all blocks are properly closed
      open_braces = hcl_content.scan(/\{/).length
      close_braces = hcl_content.scan(/\}/).length
      expect(open_braces).to eq(close_braces), "Mismatched braces: #{open_braces} open, #{close_braces} close"
    end

    it 'properly escapes special characters in names' do
      schema_content = <<~YAML
        schema_name: public
        tables:
          "user-profiles":
            columns:
              id: primary_key
              "user-name": string(100) not_null
        YAML

      create_test_yaml(schema_content)
      compiler = Essence::Compiler.new
      compiler.compile!
      hcl_content = read_generated_hcl

      # Names with special characters should be quoted
      expect(hcl_content).to include('table "user-profiles"')
      expect(hcl_content).to include('column "user-name"')
    end
  end
end
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JAML::Converter do
  describe '#convert!' do
    context 'with basic schema' do
      it 'converts YAML to HCL format' do
        create_basic_schema
        
        converter = described_class.new('db/schema.yaml', 'db/schema.hcl')
        converter.convert!
        
        hcl_content = read_generated_hcl
        
        expect(hcl_content).to include('schema "main" {}')
        expect(hcl_content).to include('table "users" {')
        expect(hcl_content).to include('table "leagues" {')
      end
    end

    context 'with default columns' do
      it 'applies default columns to all tables' do
        create_basic_schema
        
        converter = described_class.new
        converter.convert!
        
        hcl_content = read_generated_hcl
        
        # Check that default columns are present in both tables
        expect(hcl_content).to include('column "id" {')
        expect(hcl_content).to include('column "created_at" {')
        expect(hcl_content).to include('column "updated_at" {')
        expect(hcl_content).to include('auto_increment = true')
      end
    end

    context 'with pattern matching' do
      it 'applies foreign key patterns correctly' do
        create_basic_schema
        
        converter = described_class.new
        converter.convert!
        
        hcl_content = read_generated_hcl
        
        # Check foreign key generation
        expect(hcl_content).to include('foreign_key "fk_users_league_id"')
        expect(hcl_content).to include('columns = [column.league_id]')
        expect(hcl_content).to include('ref_columns = [table.leagues.column.id]')
        expect(hcl_content).to include('on_delete = CASCADE')
      end

      it 'applies timestamp patterns correctly' do
        schema_with_timestamps = <<~YAML
          schema_name: main
          defaults:
            "*":
              columns:
                id: primary_key
          column_patterns:
            - pattern: "_at$"
              attributes: "datetime not_null"
          tables:
            posts:
              columns:
                published_at: ~
                deleted_at: ~
        YAML
        
        create_test_yaml(schema_with_timestamps)
        
        converter = described_class.new
        converter.convert!
        
        hcl_content = read_generated_hcl
        
        # Check timestamp pattern application
        expect(hcl_content).to include('column "published_at"')
        expect(hcl_content).to include('type = datetime')
        expect(hcl_content).to include('null = false')
        expect(hcl_content).to include('column "deleted_at"')
      end
    end

    context 'with explicit column definitions' do
      it 'overrides patterns with explicit definitions' do
        schema_with_overrides = <<~YAML
          schema_name: main
          column_patterns:
            - pattern: "_id$"
              template: "integer -> {table}.id on_delete=cascade not_null"
          tables:
            posts:
              columns:
                id: primary_key
                user_id: bigint -> users.id on_delete=set_null
                category_id: ~
        YAML
        
        create_test_yaml(schema_with_overrides)
        
        converter = described_class.new
        converter.convert!
        
        hcl_content = read_generated_hcl
        
        # user_id should use explicit definition (bigint, SET_NULL)
        expect(hcl_content).to include('type = bigint')
        expect(hcl_content).to include('on_delete = SET_NULL')
        
        # category_id should use pattern (integer, CASCADE)
        expect(hcl_content).to include('ref_columns = [table.categories.column.id]')
        expect(hcl_content).to include('on_delete = CASCADE')
      end
    end

    context 'with indexes' do
      it 'generates simple indexes correctly' do
        schema_with_indexes = <<~YAML
          schema_name: main
          tables:
            users:
              columns:
                id: primary_key
                email: string(255) not_null
                username: string(50) not_null
              indexes:
                - email
                - username
        YAML
        
        create_test_yaml(schema_with_indexes)
        
        converter = described_class.new
        converter.convert!
        
        hcl_content = read_generated_hcl
        
        expect(hcl_content).to include('index "index_users_on_email"')
        expect(hcl_content).to include('columns = [column.email]')
        expect(hcl_content).to include('index "index_users_on_username"')
      end

      it 'generates unique indexes correctly' do
        schema_with_unique_indexes = <<~YAML
          schema_name: main
          tables:
            users:
              columns:
                id: primary_key
                email: string(255) not_null
              indexes:
                - columns: [email]
                  unique: true
        YAML
        
        create_test_yaml(schema_with_unique_indexes)
        
        converter = described_class.new
        converter.convert!
        
        hcl_content = read_generated_hcl
        
        expect(hcl_content).to include('index "index_users_on_email_unique"')
        expect(hcl_content).to include('unique = true')
      end
    end

    context 'with invalid input' do
      it 'raises an error for missing YAML file' do
        converter = described_class.new('nonexistent.yaml', 'output.hcl')
        
        expect { converter.convert! }.to raise_error(SystemExit)
      end

      it 'handles invalid YAML gracefully' do
        File.write('db/schema.yaml', 'invalid: yaml: [content')
        
        converter = described_class.new
        
        expect { converter.convert! }.to raise_error(Psych::SyntaxError)
      end
    end
  end

  describe '.generate_template' do
    it 'creates a valid schema template' do
      template_path = 'db/test_template.yaml'
      
      described_class.generate_template(template_path)
      
      expect(File.exist?(template_path)).to be true
      
      template_content = File.read(template_path)
      
      # Check for key sections
      expect(template_content).to include('schema_name: main')
      expect(template_content).to include('defaults:')
      expect(template_content).to include('"*":')
      expect(template_content).to include('column_patterns:')
      expect(template_content).to include('pattern: "_id$"')
      expect(template_content).to include('pattern: "_at$"')
      expect(template_content).to include('tables:')
      
      # Verify it's valid YAML
      parsed = YAML.load_file(template_path)
      expect(parsed['defaults']['*']['columns']['id']).to eq('primary_key')
      expect(parsed['column_patterns']).to be_an(Array)
      expect(parsed['column_patterns'].length).to eq(23)
    end

    it 'generates a convertible template' do
      template_path = 'db/generated_template.yaml'
      described_class.generate_template(template_path)
      
      # Convert the generated template
      converter = described_class.new(template_path, 'db/generated.hcl')
      converter.convert!
      
      hcl_content = File.read('db/generated.hcl')
      
      # Should generate valid HCL with example tables
      expect(hcl_content).to include('table "users"')
      expect(hcl_content).to include('table "leagues"')
      
      # Should have applied defaults and patterns
      expect(hcl_content).to include('column "id"')
      expect(hcl_content).to include('column "created_at"')
      expect(hcl_content).to include('column "league_id"')
      
      # Should have foreign key for league_id
      expect(hcl_content).to include('foreign_key "fk_users_league_id"')
      expect(hcl_content).to include('ref_columns = [table.leagues.column.id]')
    end
  end

  describe 'pluralization' do
    it 'pluralizes table names correctly' do
      schema_with_various_ids = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "_id$"
            template: "integer -> {table}.id on_delete=cascade not_null"
        tables:
          posts:
            columns:
              id: primary_key
              category_id: ~
              company_id: ~
              leaf_id: ~
              wife_id: ~
      YAML
      
      create_test_yaml(schema_with_various_ids)
      
      converter = described_class.new
      converter.convert!
      
      hcl_content = read_generated_hcl
      
      # Test various pluralization rules
      expect(hcl_content).to include('ref_columns = [table.categories.column.id]')  # y -> ies
      expect(hcl_content).to include('ref_columns = [table.companies.column.id]')   # y -> ies
      expect(hcl_content).to include('ref_columns = [table.leaves.column.id]')      # f -> ves
      expect(hcl_content).to include('ref_columns = [table.wives.column.id]')       # fe -> ves
    end
  end
end
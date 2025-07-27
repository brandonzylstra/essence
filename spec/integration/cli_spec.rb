# frozen_string_literal: true

require 'spec_helper'
require 'open3'

RSpec.describe 'CLI Integration Tests' do
  let(:cli_path) { File.expand_path('../../exe/essence', __dir__) }
  
  before do
    # Ensure CLI is executable
    FileUtils.chmod(0755, cli_path)
  end

  describe 'CLI executable' do
    describe 'essence template' do
      it 'generates a template file with default path' do
        stdout, stderr, status = Open3.capture3("ruby #{cli_path} template")
        
        expect(status.success?).to be true
        expect(stdout).to include('Generating Essence schema template')
        expect(stdout).to include('Schema template created at db/schema.yaml')
        expect(File.exist?('db/schema.yaml')).to be true
        
        content = File.read('db/schema.yaml')
        expect(content).to include('schema_name: public')
        expect(content).to include('defaults:')
        expect(content).to include('column_patterns:')
      end

      it 'generates a template file with custom path' do
        custom_path = 'custom/my_schema.yaml'
        stdout, stderr, status = Open3.capture3("ruby #{cli_path} template #{custom_path}")
        
        expect(status.success?).to be true
        expect(stdout).to include("Generating Essence schema template at #{custom_path}")
        expect(File.exist?(custom_path)).to be true
      end

      it 'creates directories if they do not exist' do
        deep_path = 'very/deep/nested/schema.yaml'
        stdout, stderr, status = Open3.capture3("ruby #{cli_path} template #{deep_path}")
        
        expect(status.success?).to be true
        expect(File.exist?(deep_path)).to be true
      end
    end

    describe 'essence compile' do
      before do
        # Create a test schema file
        test_schema = <<~YAML
          schema_name: test
          defaults:
            "*":
              columns:
                id: primary_key
                created_at: datetime not_null
          column_patterns:
            - "_id$": "integer -> {table}.id on_delete=cascade not_null"
            - "_at$": "datetime not_null"
            - ".*": "string"
          tables:
            users:
              columns:
                email: string(255) not_null unique
                league_id: ~
                last_login_at: ~
            posts:
              columns:
                title: string(255) not_null
                user_id: ~
                published_at: ~
        YAML
        
        FileUtils.mkdir_p('db')
        File.write('test_input.yaml', test_schema)
      end

      it 'compiles YAML to HCL with default paths' do
        # First create the default input file
        FileUtils.cp('test_input.yaml', 'db/schema.yaml')
        
        stdout, stderr, status = Open3.capture3("ruby #{cli_path} compile")
        
        expect(status.success?).to be true
        expect(stdout).to include('Compiling schema to HCL format')
        expect(stdout).to include('Compilation completed successfully')
        expect(File.exist?('db/schema.hcl')).to be true
        
        hcl_content = File.read('db/schema.hcl')
        expect(hcl_content).to include('schema "test"')
        expect(hcl_content).to include('table "users"')
        expect(hcl_content).to include('table "posts"')
        expect(hcl_content).to include('foreign_key')
      end

      it 'compiles YAML to HCL with custom paths' do
        stdout, stderr, status = Open3.capture3("ruby #{cli_path} compile test_input.yaml test_output.hcl")
        
        expect(status.success?).to be true
        expect(stdout).to include('Compiling schema to HCL format')
        expect(File.exist?('test_output.hcl')).to be true
        
        hcl_content = File.read('test_output.hcl')
        expect(hcl_content).to include('table "users"')
        expect(hcl_content).to include('foreign_key "fk_users_league_id"')
        expect(hcl_content).to include('foreign_key "fk_posts_user_id"')
      end

      it 'reports error for missing input file' do
        stdout, stderr, status = Open3.capture3("ruby #{cli_path} compile nonexistent.yaml output.hcl")
        
        expect(status.success?).to be false
        expect(stdout).to include('YAML file not found: nonexistent.yaml')
      end

      it 'handles malformed YAML gracefully' do
        File.write('malformed.yaml', 'invalid: yaml: [content')
        
        stdout, stderr, status = Open3.capture3("ruby #{cli_path} compile malformed.yaml output.hcl")
        
        expect(status.success?).to be false
        expect(stdout).to include('Error during compilation')
      end
    end

    describe 'essence version' do
      it 'displays version information' do
        stdout, stderr, status = Open3.capture3("ruby #{cli_path} version")
        
        expect(status.success?).to be true
        expect(stdout).to include('Essence v0.1.0')
        expect(stdout).to include('Essence - Database Schema Management')
      end

      it 'responds to -v flag' do
        stdout, stderr, status = Open3.capture3("ruby #{cli_path} -v")
        
        expect(status.success?).to be true
        expect(stdout).to include('Essence v0.1.0')
      end

      it 'responds to --version flag' do
        stdout, stderr, status = Open3.capture3("ruby #{cli_path} --version")
        
        expect(status.success?).to be true
        expect(stdout).to include('Essence v0.1.0')
        expect(stdout).to include('Essence - Database Schema Management')
      end
    end

    describe 'essence help' do
      it 'displays help information' do
        stdout, stderr, status = Open3.capture3("ruby #{cli_path} --help")
        
        expect(status.success?).to be true
        expect(stdout).to include('Essence - Database Schema Management')
        expect(stdout).to include('EXAMPLES:')
        expect(stdout).to include('FEATURES:')
        expect(stdout).to include('template')
        expect(stdout).to include('compile')
        expect(stdout).to include('version')
        expect(stdout).to include('EXAMPLES:')
        expect(stdout).to include('FEATURES:')
      end

      it 'responds to -h flag' do
        stdout, stderr, status = Open3.capture3("ruby #{cli_path} -h")
        
        expect(status.success?).to be true
        expect(stdout).to include('Essence - Database Schema Management')
      end

      it 'responds to --help flag' do
        stdout, stderr, status = Open3.capture3("ruby #{cli_path} --help")
        
        expect(status.success?).to be true
        expect(stdout).to include('USAGE:')
      end

      it 'shows help when no command is provided' do
        stdout, stderr, status = Open3.capture3("ruby #{cli_path}")
        
        expect(status.success?).to be true
        expect(stdout).to include('Essence - Database Schema Management')
      end
    end

    describe 'command aliases' do
      it 'accepts t as alias for template' do
        stdout, stderr, status = Open3.capture3("ruby #{cli_path} t custom_template.yaml")
        
        expect(status.success?).to be true
        expect(stdout).to include('Schema template created')
        expect(File.exist?('custom_template.yaml')).to be true
      end

      it 'accepts c as alias for compile' do
        # Create test input
        test_schema = <<~YAML
          schema_name: test
          tables:
            users:
              columns:
                id: primary_key
        YAML
        File.write('alias_test.yaml', test_schema)
        
        stdout, stderr, status = Open3.capture3("ruby #{cli_path} c alias_test.yaml alias_test.hcl")
        
        expect(status.success?).to be true
        expect(stdout).to include('Compiling schema to HCL format')
        expect(File.exist?('alias_test.hcl')).to be true
      end

      it 'accepts v as alias for version' do
        stdout, stderr, status = Open3.capture3("ruby #{cli_path} v")
        
        expect(status.success?).to be true
        expect(stdout).to include('Essence v0.1.0')
      end
    end

    describe 'error handling' do
      it 'reports unknown commands' do
        stdout, stderr, status = Open3.capture3("ruby #{cli_path} unknown_command")
        
        expect(status.success?).to be false
        expect(stdout).to include('Unknown command: unknown_command')
        expect(stdout).to include("Run 'essence help' for available commands")
      end

      it 'handles file permission errors' do
        # Create a read-only directory
        FileUtils.mkdir_p('readonly_dir')
        FileUtils.chmod(0444, 'readonly_dir')
        
        stdout, stderr, status = Open3.capture3("ruby #{cli_path} template readonly_dir/schema.yaml")
        
        expect(status.success?).to be false
        expect(stdout).to include('Error generating template')
        
        # Clean up
        FileUtils.chmod(0755, 'readonly_dir')
        FileUtils.rm_rf('readonly_dir')
      end

      it 'handles invalid file paths gracefully' do
        stdout, stderr, status = Open3.capture3("ruby #{cli_path} compile /invalid/path/file.yaml output.hcl")
        
        expect(status.success?).to be false
        expect(stdout).to include('YAML file not found')
      end
    end
  end

  describe 'End-to-end workflows' do
    it 'performs complete template -> compile -> validate workflow' do
      # Step 1: Generate template
      stdout, stderr, status = Open3.capture3("ruby #{cli_path} template workflow_test.yaml")
      expect(status.success?).to be true
      expect(File.exist?('workflow_test.yaml')).to be true
      
      # Step 2: Compile to HCL
      stdout, stderr, status = Open3.capture3("ruby #{cli_path} compile workflow_test.yaml workflow_test.hcl")
      expect(status.success?).to be true
      expect(File.exist?('workflow_test.hcl')).to be true
      
      # Step 3: Validate content
      yaml_content = File.read('workflow_test.yaml')
      hcl_content = File.read('workflow_test.hcl')
      
      expect(yaml_content).to include('schema_name: public')
      expect(yaml_content).to include('column_patterns:')
      expect(yaml_content).to include('tables:')
      
      expect(hcl_content).to include('schema "public"')
      expect(hcl_content).to include('table "users"')
      expect(hcl_content).to include('table "leagues"')
      expect(hcl_content).to include('foreign_key')
      expect(hcl_content).to include('primary_key')
    end

    it 'handles complex schema with all pattern types' do
      complex_schema = <<~YAML
        schema_name: complex
        defaults:
          "*":
            columns:
              id: primary_key
              created_at: datetime not_null
              updated_at: datetime not_null
        column_patterns:
          - "_id$": "integer -> {table}.id on_delete=cascade not_null"
          - "_at$": "datetime not_null"
          - "_on$": "date"
          - "^is_": "boolean default=false not_null"
          - "^has_": "boolean default=false not_null"
          - "_count$": "integer default=0 not_null"
          - "_email$": "string(255)"
          - "_url$": "string(500)"
          - "_slug$": "string(255) unique"
          - "_status$": "string(20) default='pending' not_null"
          - ".*": "string"
        tables:
          users:
            columns:
              email: string(255) not_null unique
              company_id: ~
              last_login_at: ~
              birth_date: date
              is_active: ~
              has_premium: ~
              login_count: ~
              backup_email: ~
              profile_url: ~
              user_slug: ~
              account_status: ~
          posts:
            columns:
              title: string(255) not_null
              user_id: ~
              published_at: ~
              due_on: ~
              is_featured: ~
              view_count: ~
              post_slug: ~
          companies:
            columns:
              name: string(255) not_null
              website_url: ~
              contact_email: ~
              is_verified: ~
      YAML
      
      File.write('complex_test.yaml', complex_schema)
      
      stdout, stderr, status = Open3.capture3("ruby #{cli_path} compile complex_test.yaml complex_test.hcl")
      
      expect(status.success?).to be true
      expect(File.exist?('complex_test.hcl')).to be true
      
      hcl_content = File.read('complex_test.hcl')
      
      # Verify all tables are generated
      expect(hcl_content).to include('table "users"')
      expect(hcl_content).to include('table "posts"')
      expect(hcl_content).to include('table "companies"')
      
      # Verify foreign keys are generated
      expect(hcl_content).to include('foreign_key "fk_users_company_id"')
      expect(hcl_content).to include('foreign_key "fk_posts_user_id"')
      
      # Verify pattern applications
      expect(hcl_content).to match(/column "last_login_at".*?type = datetime/m)
      expect(hcl_content).to match(/column "is_active".*?type = boolean.*?default = false/m)
      expect(hcl_content).to match(/column "has_premium".*?type = boolean.*?default = false/m)
      expect(hcl_content).to match(/column "login_count".*?type = integer.*?default = 0/m)
      expect(hcl_content).to match(/column "backup_email".*?type = varchar\(255\)/m)
      expect(hcl_content).to match(/column "profile_url".*?type = varchar\(500\)/m)
      expect(hcl_content).to match(/column "account_status".*?type = varchar\(20\).*?default = "pending"/m)
    end

    it 'handles incremental schema development workflow' do
      # Start with basic schema
      basic_schema = <<~YAML
        schema_name: incremental
        defaults:
          "*":
            columns:
              id: primary_key
              created_at: datetime not_null
              updated_at: datetime not_null
        column_patterns:
          - "_id$": "integer -> {table}.id on_delete=cascade not_null"
          - ".*": "string"

        tables:
          users:
            columns:
              email: string(255) not_null unique
              name: string(100) not_null
      YAML
      
      File.write('incremental_v1.yaml', basic_schema)
      
      # Compile v1
      stdout, stderr, status = Open3.capture3("ruby #{cli_path} compile incremental_v1.yaml incremental_v1.hcl")
      expect(status.success?).to be true
      
      v1_content = File.read('incremental_v1.hcl')
      expect(v1_content).to include('table "users"')
      expect(v1_content).not_to include('table "posts"')
      
      # Add more tables and patterns
      enhanced_schema = <<~YAML
        schema_name: incremental
        defaults:
          "*":
            columns:
              id: primary_key
              created_at: datetime not_null
              updated_at: datetime not_null
        column_patterns:
          - "_id$": "integer -> {table}.id on_delete=cascade not_null"
          - "_at$": "datetime not_null"
          - "^is_": "boolean default=false not_null"
          - ".*": "string"
        tables:
          users:
            columns:
              email: string(255) not_null unique
              name: string(100) not_null
              last_login_at: ~
              is_active: ~
          posts:
            columns:
              title: string(255) not_null
              user_id: ~
              published_at: ~
              is_published: ~
          categories:
            columns:
              name: string(100) not_null
              is_active: ~
      YAML
      
      File.write('incremental_v2.yaml', enhanced_schema)
      
      # Compile v2
      stdout, stderr, status = Open3.capture3("ruby #{cli_path} compile incremental_v2.yaml incremental_v2.hcl")
      expect(status.success?).to be true
      
      v2_content = File.read('incremental_v2.hcl')
      expect(v2_content).to include('table "users"')
      expect(v2_content).to include('table "posts"')
      expect(v2_content).to include('table "categories"')
      expect(v2_content).to include('foreign_key "fk_posts_user_id"')
      expect(v2_content).to match(/column "last_login_at".*?type = datetime/m)
      expect(v2_content).to match(/column "is_active".*?type = boolean.*?default = false/m)
    end

    it 'handles schema with overrides and mixed explicit/pattern definitions' do
      mixed_schema = <<~YAML
        schema_name: mixed
        defaults:
          "*":
            columns:
              id: primary_key
              created_at: datetime not_null
              updated_at: datetime not_null
        column_patterns:
          - "_id$": "integer -> {table}.id on_delete=cascade not_null"
          - "_at$": "datetime not_null"
          - ".*": "string"
        tables:
          users:
            columns:
              email: string(255) not_null unique
              company_id: bigint -> companies.id on_delete=set_null  # Override pattern
              last_login_at: ~                                       # Use pattern
              bio: text                                              # Override pattern
          posts:
            columns:
              title: string(255) not_null
              user_id: ~                                             # Use pattern
              published_at: timestamp not_null                       # Override pattern
              content: text not_null
      YAML
      
      File.write('mixed_test.yaml', mixed_schema)
      
      stdout, stderr, status = Open3.capture3("ruby #{cli_path} compile mixed_test.yaml mixed_test.hcl")
      
      expect(status.success?).to be true
      
      hcl_content = File.read('mixed_test.hcl')
      
      # Verify overrides work
      expect(hcl_content).to match(/column "company_id".*?type = bigint/m)
      expect(hcl_content).to include('on_delete = SET_NULL')
      expect(hcl_content).to match(/column "published_at".*?type = timestamp/m)
      expect(hcl_content).to match(/column "bio".*?type = text/m)
      
      # Verify patterns still work where not overridden
      expect(hcl_content).to include('foreign_key "fk_posts_user_id"')
      expect(hcl_content).to match(/column "last_login_at".*?type = datetime/m)
    end
  end

  describe 'Performance and reliability' do
    it 'handles large schemas efficiently' do
      # Generate a large schema with many tables and columns
      large_schema = {
        'schema_name' => 'large',
        'defaults' => {
          '*' => {
            'columns' => {
              'id' => 'primary_key',
              'created_at' => 'datetime not_null',
              'updated_at' => 'datetime not_null'
            }
          }
        },
        'column_patterns' => [
          { '_id$' => 'integer -> {table}.id on_delete=cascade not_null' },
          { '_at$' => 'datetime not_null' },
          { '.*' => 'string' }
        ],
        'tables' => {}
      }
      
      # Generate 25 tables with 10 columns each
      25.times do |i|
        table_name = "table_#{i}"
        large_schema['tables'][table_name] = {
          'columns' => {
            'name' => 'string(255) not_null',
            'description' => 'text',
            'other_table_id' => '~',
            'published_at' => '~',
            'status' => 'string(20)',
            'count' => 'integer default=0',
            'price' => 'decimal(10,2)',
            'active' => 'boolean default=true',
            'metadata' => 'text',
            'notes' => 'string(500)'
          },
          'indexes' => ['name', 'other_table_id', 'published_at']
        }
      end
      
      File.write('large_test.yaml', large_schema.to_yaml)
      
      start_time = Time.now
      stdout, stderr, status = Open3.capture3("ruby #{cli_path} compile large_test.yaml large_test.hcl")
      end_time = Time.now
      
      expect(status.success?).to be true
      expect(File.exist?('large_test.hcl')).to be true
      
      # Should complete within reasonable time (under 5 seconds)
      execution_time = end_time - start_time
      expect(execution_time).to be < 5.0
      
      # Verify output correctness
      hcl_content = File.read('large_test.hcl')
      expect(hcl_content.scan(/table "table_\d+"/).length).to eq(25)
      expect(hcl_content.scan(/foreign_key/).length).to be > 20  # Should have many foreign keys
    end

    it 'maintains consistent output across multiple runs' do
      test_schema = <<~YAML
        schema_name: consistency
        defaults:
          "*":
            columns:
              id: primary_key
        column_patterns:
          - "_id$": "integer -> {table}.id on_delete=cascade not_null"
          - ".*": "string"
        tables:
          users:
            columns:
              name: string(100) not_null
              company_id: ~
          companies:
            columns:
              name: string(100) not_null
      YAML
      
      File.write('consistency_test.yaml', test_schema)
      
      # Run conversion multiple times
      outputs = []
      3.times do |i|
        stdout, stderr, status = Open3.capture3("ruby #{cli_path} compile consistency_test.yaml consistency_#{i}.hcl")
        expect(status.success?).to be true
        outputs << File.read("consistency_#{i}.hcl")
      end
      
      # All outputs should be identical
      expect(outputs[0]).to eq(outputs[1])
      expect(outputs[1]).to eq(outputs[2])
    end

    it 'handles concurrent CLI invocations gracefully' do
      test_schema = <<~YAML
        schema_name: concurrent
        tables:
          test:
            columns:
              id: primary_key
              name: string(100) not_null
      YAML
      
      File.write('concurrent_test.yaml', test_schema)
      
      # Run multiple conversions concurrently
      threads = []
      5.times do |i|
        threads << Thread.new do
          stdout, stderr, status = Open3.capture3("ruby #{cli_path} compile concurrent_test.yaml concurrent_#{i}.hcl")
          { status: status.success?, file_exists: File.exist?("concurrent_#{i}.hcl") }
        end
      end
      
      results = threads.map(&:value)
      
      # All should succeed
      expect(results.all? { |r| r[:status] }).to be true
      expect(results.all? { |r| r[:file_exists] }).to be true
    end
  end
end
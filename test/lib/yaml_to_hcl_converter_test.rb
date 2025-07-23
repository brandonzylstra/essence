# frozen_string_literal: true

require 'test_helper'
require_relative '../../lib/yaml_to_hcl_converter'
require 'tempfile'
require 'fileutils'

class YamlToHclConverterTest < ActiveSupport::TestCase
  def setup
    @test_dir = Dir.mktmpdir('atlas_test')
    @original_dir = Dir.pwd
    Dir.chdir(@test_dir)
    
    # Create db directory
    FileUtils.mkdir_p('db')
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@test_dir)
  end

  test "prefers .yaml extension over .yml" do
    # Create both files
    File.write('db/schema.yaml', test_yaml_content)
    File.write('db/schema.yml', 'invalid: yaml: content')
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    # Should use .yaml file, not .yml
    hcl_content = File.read('db/schema.hcl')
    assert_includes hcl_content, 'table "users"'
    refute_includes hcl_content, 'invalid'
  end

  test "prefers db/ directory over root" do
    # Create files in both locations
    File.write('db/schema.yaml', test_yaml_content)
    File.write('schema.yaml', 'invalid: yaml: content')
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    # Should use db/ file
    hcl_content = File.read('db/schema.hcl')
    assert_includes hcl_content, 'table "users"'
    refute_includes hcl_content, 'invalid'
  end

  test "falls back to .yml if .yaml doesn't exist" do
    File.write('db/schema.yml', test_yaml_content)
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    assert File.exist?('db/schema.hcl')
    hcl_content = File.read('db/schema.hcl')
    assert_includes hcl_content, 'table "users"'
  end

  test "converts basic table structure" do
    File.write('db/schema.yaml', test_yaml_content)
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    hcl_content = File.read('db/schema.hcl')
    
    # Check for basic structure
    assert_includes hcl_content, 'schema "main" {}'
    assert_includes hcl_content, 'table "users" {'
    assert_includes hcl_content, 'schema = schema.main'
  end

  test "converts column types correctly" do
    yaml_content = <<~YAML
      schema_name: main
      tables:
        test_table:
          columns:
            id: primary_key
            name: string(255) not_null
            age: integer
            active: boolean default=true not_null
            bio: text
            created_at: datetime not_null
            score: decimal(8,2)
    YAML
    
    File.write('db/schema.yaml', yaml_content)
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    hcl_content = File.read('db/schema.hcl')
    
    # Check column type conversions
    assert_includes hcl_content, 'type = varchar(255)'
    assert_includes hcl_content, 'type = integer'
    assert_includes hcl_content, 'type = boolean'
    assert_includes hcl_content, 'type = text'
    assert_includes hcl_content, 'type = datetime'
    assert_includes hcl_content, 'type = decimal(8,2)'
  end

  test "handles null constraints correctly" do
    yaml_content = <<~YAML
      schema_name: main
      tables:
        test_table:
          columns:
            id: primary_key
            required_field: string(100) not_null
            optional_field: string(100)
    YAML
    
    File.write('db/schema.yaml', yaml_content)
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    hcl_content = File.read('db/schema.hcl')
    
    # Check null constraints
    assert_match(/column "required_field".*null = false/m, hcl_content)
    assert_match(/column "optional_field".*null = true/m, hcl_content)
  end

  test "handles default values correctly" do
    yaml_content = <<~YAML
      schema_name: main
      tables:
        test_table:
          columns:
            id: primary_key
            active: boolean default=true not_null
            role: string(20) default='user' not_null
            count: integer default=0 not_null
    YAML
    
    File.write('db/schema.yaml', yaml_content)
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    hcl_content = File.read('db/schema.hcl')
    
    # Check default values
    assert_includes hcl_content, 'default = true'
    assert_includes hcl_content, "default = 'user'"
    assert_includes hcl_content, 'default = 0'
  end

  test "generates foreign keys correctly" do
    yaml_content = <<~YAML
      schema_name: main
      tables:
        users:
          columns:
            id: primary_key
            name: string(100) not_null
        posts:
          columns:
            id: primary_key
            user_id: integer -> users.id on_delete=cascade not_null
            author_id: integer -> users.id on_delete=set_null
    YAML
    
    File.write('db/schema.yaml', yaml_content)
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    hcl_content = File.read('db/schema.hcl')
    
    # Check foreign keys
    assert_includes hcl_content, 'foreign_key "fk_posts_user_id"'
    assert_includes hcl_content, 'columns = [column.user_id]'
    assert_includes hcl_content, 'ref_columns = [table.users.column.id]'
    assert_includes hcl_content, 'on_delete = CASCADE'
    assert_includes hcl_content, 'on_delete = SET_NULL'
  end

  test "generates primary keys correctly" do
    File.write('db/schema.yaml', test_yaml_content)
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    hcl_content = File.read('db/schema.hcl')
    
    # Check primary key generation
    assert_includes hcl_content, 'primary_key {'
    assert_includes hcl_content, 'columns = [column.id]'
    assert_includes hcl_content, 'auto_increment = true'
  end

  test "generates simple indexes correctly" do
    yaml_content = <<~YAML
      schema_name: main
      tables:
        users:
          columns:
            id: primary_key
            email: string(255) not_null
            role: string(20) not_null
          indexes:
            - email
            - role
    YAML
    
    File.write('db/schema.yaml', yaml_content)
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    hcl_content = File.read('db/schema.hcl')
    
    # Check simple indexes
    assert_includes hcl_content, 'index "index_users_on_email"'
    assert_includes hcl_content, 'columns = [column.email]'
    assert_includes hcl_content, 'index "index_users_on_role"'
    assert_includes hcl_content, 'columns = [column.role]'
  end

  test "generates unique indexes correctly" do
    yaml_content = <<~YAML
      schema_name: main
      tables:
        users:
          columns:
            id: primary_key
            email: string(255) not_null
            username: string(50) not_null
          indexes:
            - columns: [email]
              unique: true
            - columns: [username, email]
              unique: true
    YAML
    
    File.write('db/schema.yaml', yaml_content)
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    hcl_content = File.read('db/schema.hcl')
    
    # Check unique indexes
    assert_includes hcl_content, 'index "index_users_on_email_unique"'
    assert_includes hcl_content, 'unique = true'
    assert_includes hcl_content, 'index "index_users_on_username_and_email_unique"'
    assert_includes hcl_content, 'columns = [column.username, column.email]'
  end

  test "generates multi-column indexes correctly" do
    yaml_content = <<~YAML
      schema_name: main
      tables:
        posts:
          columns:
            id: primary_key
            user_id: integer not_null
            category_id: integer not_null
            created_at: datetime not_null
          indexes:
            - columns: [user_id, created_at]
            - columns: [category_id, user_id, created_at]
    YAML
    
    File.write('db/schema.yaml', yaml_content)
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    hcl_content = File.read('db/schema.hcl')
    
    # Check multi-column indexes
    assert_includes hcl_content, 'index "index_posts_on_user_id_and_created_at"'
    assert_includes hcl_content, 'columns = [column.user_id, column.created_at]'
    assert_includes hcl_content, 'index "index_posts_on_category_id_and_user_id_and_created_at"'
  end

  test "handles missing YAML file gracefully" do
    converter = YamlToHclConverter.new('nonexistent.yaml', 'output.hcl')
    
    assert_raises(SystemExit) do
      converter.convert!
    end
  end

  test "handles invalid YAML gracefully" do
    File.write('db/schema.yaml', 'invalid: yaml: [content')
    
    converter = YamlToHclConverter.new
    
    assert_raises(Psych::SyntaxError) do
      converter.convert!
    end
  end

  test "generates proper HCL header" do
    File.write('db/schema.yaml', test_yaml_content)
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    hcl_content = File.read('db/schema.hcl')
    
    # Check header
    assert_includes hcl_content, '# Auto-generated Atlas HCL schema from db/schema.yaml'
    assert_includes hcl_content, '# Edit the YAML file and re-run the converter'
  end

  test "uses custom schema name" do
    yaml_content = <<~YAML
      schema_name: custom_schema
      tables:
        users:
          columns:
            id: primary_key
            name: string(100) not_null
    YAML
    
    File.write('db/schema.yaml', yaml_content)
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    hcl_content = File.read('db/schema.hcl')
    
    # Check custom schema name
    assert_includes hcl_content, 'schema "custom_schema" {}'
    assert_includes hcl_content, 'schema = schema.custom_schema'
  end

  test "handles empty tables section" do
    yaml_content = <<~YAML
      schema_name: main
      tables: {}
    YAML
    
    File.write('db/schema.yaml', yaml_content)
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    hcl_content = File.read('db/schema.hcl')
    
    # Should generate valid HCL with just schema
    assert_includes hcl_content, 'schema "main" {}'
    refute_includes hcl_content, 'table'
  end

  test "handles table without columns" do
    yaml_content = <<~YAML
      schema_name: main
      tables:
        empty_table: {}
    YAML
    
    File.write('db/schema.yaml', yaml_content)
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    hcl_content = File.read('db/schema.hcl')
    
    # Should generate empty table
    assert_includes hcl_content, 'table "empty_table" {'
    assert_includes hcl_content, 'schema = schema.main'
  end

  test "preserves file paths correctly" do
    File.write('db/schema.yaml', test_yaml_content)
    
    converter = YamlToHclConverter.new('db/schema.yaml', 'db/output.hcl')
    converter.convert!
    
    assert File.exist?('db/output.hcl')
    hcl_content = File.read('db/output.hcl')
    assert_includes hcl_content, 'table "users"'
  end

  private

  def test_yaml_content
    <<~YAML
      schema_name: main
      rails_version: "8.0"
      
      tables:
        users:
          columns:
            id: primary_key
            first_name: string(100) not_null
            last_name: string(100) not_null
            email: string(255) not_null unique
            active: boolean default=true not_null
            created_at: datetime not_null
            updated_at: datetime not_null
          indexes:
            - email
            - active
            
        posts:
          columns:
            id: primary_key
            user_id: integer -> users.id on_delete=cascade not_null
            title: string(255) not_null
            body: text
            published: boolean default=false not_null
            created_at: datetime not_null
            updated_at: datetime not_null
          indexes:
            - user_id
            - published
            - columns: [user_id, published]
    YAML
  end
end
#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'tempfile'
require 'fileutils'
require 'yaml'

# Add lib directory to load path
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'yaml_to_hcl_converter'

class StandaloneYamlConverterTest < Minitest::Test
  def setup
    @test_dir = Dir.mktmpdir('yaml_converter_test')
    @original_dir = Dir.pwd
    Dir.chdir(@test_dir)
    
    # Create db directory
    FileUtils.mkdir_p('db')
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@test_dir)
  end

  def test_prefers_yaml_extension_over_yml
    # Create both files
    File.write('db/schema.yaml', test_yaml_content)
    File.write('db/schema.yml', 'invalid: yaml: content')
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    # Should use .yaml file, not .yml
    assert File.exist?('db/schema.hcl')
    hcl_content = File.read('db/schema.hcl')
    assert_includes hcl_content, 'table "users"'
    refute_includes hcl_content, 'invalid'
  end

  def test_prefers_db_directory_over_root
    # Create files in both locations
    File.write('db/schema.yaml', test_yaml_content)
    File.write('schema.yaml', 'invalid: yaml: content')
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    # Should use db/ file
    assert File.exist?('db/schema.hcl')
    hcl_content = File.read('db/schema.hcl')
    assert_includes hcl_content, 'table "users"'
    refute_includes hcl_content, 'invalid'
  end

  def test_falls_back_to_yml_if_yaml_doesnt_exist
    File.write('db/schema.yml', test_yaml_content)
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    assert File.exist?('db/schema.hcl')
    hcl_content = File.read('db/schema.hcl')
    assert_includes hcl_content, 'table "users"'
  end

  def test_converts_basic_table_structure
    File.write('db/schema.yaml', test_yaml_content)
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    hcl_content = File.read('db/schema.hcl')
    
    # Check for basic structure
    assert_includes hcl_content, 'schema "main" {}'
    assert_includes hcl_content, 'table "users" {'
    assert_includes hcl_content, 'schema = schema.main'
  end

  def test_converts_column_types_correctly
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

  def test_handles_null_constraints_correctly
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

  def test_handles_default_values_correctly
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
    assert_includes hcl_content, 'default = "user"'
    assert_includes hcl_content, 'default = 0'
  end

  def test_generates_foreign_keys_correctly
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

  def test_generates_primary_keys_correctly
    File.write('db/schema.yaml', test_yaml_content)
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    hcl_content = File.read('db/schema.hcl')
    
    # Check primary key generation
    assert_includes hcl_content, 'primary_key {'
    assert_includes hcl_content, 'columns = [column.id]'
    assert_includes hcl_content, 'auto_increment = true'
  end

  def test_generates_simple_indexes_correctly
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

  def test_generates_unique_indexes_correctly
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

  def test_generates_multi_column_indexes_correctly
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

  def test_handles_missing_yaml_file_gracefully
    converter = YamlToHclConverter.new('nonexistent.yaml', 'output.hcl')
    
    assert_raises(SystemExit) do
      capture_output { converter.convert! }
    end
  end

  def test_handles_invalid_yaml_gracefully
    File.write('db/schema.yaml', 'invalid: yaml: [content')
    
    converter = YamlToHclConverter.new
    
    assert_raises(Psych::SyntaxError) do
      converter.convert!
    end
  end

  def test_generates_proper_hcl_header
    File.write('db/schema.yaml', test_yaml_content)
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    hcl_content = File.read('db/schema.hcl')
    
    # Check header
    assert_includes hcl_content, '# Auto-generated Atlas HCL schema from db/schema.yaml'
    assert_includes hcl_content, '# Edit the YAML file and re-run the converter'
  end

  def test_uses_custom_schema_name
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

  def test_handles_empty_tables_section
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

  def test_handles_table_without_columns
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

  def test_preserves_file_paths_correctly
    File.write('db/schema.yaml', test_yaml_content)
    
    converter = YamlToHclConverter.new('db/schema.yaml', 'db/output.hcl')
    converter.convert!
    
    assert File.exist?('db/output.hcl')
    hcl_content = File.read('db/output.hcl')
    assert_includes hcl_content, 'table "users"'
  end

  def test_validates_generated_hcl_syntax
    File.write('db/schema.yaml', test_yaml_content)
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    hcl_content = File.read('db/schema.hcl')
    
    # Basic HCL syntax validation
    assert_match(/schema "main" \{\}/, hcl_content)
    assert_match(/table "\w+" \{/, hcl_content)
    assert_match(/column "\w+" \{/, hcl_content)
    
    # Ensure braces are balanced
    open_braces = hcl_content.scan(/\{/).length
    close_braces = hcl_content.scan(/\}/).length
    assert_equal open_braces, close_braces, "HCL braces should be balanced"
  end

  def test_preserves_case_sensitivity_in_names
    case_yaml = <<~YAML
      schema_name: main
      tables:
        UserProfiles:
          columns:
            id: primary_key
            firstName: string(100) not_null
            lastName: string(100) not_null
            emailAddress: string(255) not_null unique
    YAML
    
    File.write('db/schema.yaml', case_yaml)
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    hcl_content = File.read('db/schema.hcl')
    
    # Should preserve exact case
    assert_includes hcl_content, 'table "UserProfiles"'
    assert_includes hcl_content, 'column "firstName"'
    assert_includes hcl_content, 'column "lastName"'
    assert_includes hcl_content, 'column "emailAddress"'
  end

  def test_supports_all_column_types
    types_yaml = <<~YAML
      schema_name: main
      tables:
        test_types:
          columns:
            id: primary_key
            name: string(255) not_null
            age: integer
            bio: text
            active: boolean default=true not_null
            created_at: datetime not_null
            birth_date: date
            score: decimal(8,2)
            data: binary(1024)
    YAML
    
    File.write('db/schema.yaml', types_yaml)
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    hcl_content = File.read('db/schema.hcl')
    
    # Verify all column types
    assert_includes hcl_content, 'type = varchar(255)'
    assert_includes hcl_content, 'type = integer'
    assert_includes hcl_content, 'type = text'
    assert_includes hcl_content, 'type = boolean'
    assert_includes hcl_content, 'type = datetime'
    assert_includes hcl_content, 'type = date'
    assert_includes hcl_content, 'type = decimal(8,2)'
    assert_includes hcl_content, 'type = binary(1024)'
  end

  def test_handles_polymorphic_relationships
    polymorphic_yaml = <<~YAML
      schema_name: main
      tables:
        comments:
          columns:
            id: primary_key
            body: text not_null
            commentable_id: integer not_null
            commentable_type: string(50) not_null
            created_at: datetime not_null
          indexes:
            - columns: [commentable_id, commentable_type]
            - columns: [commentable_type]
    YAML
    
    File.write('db/schema.yaml', polymorphic_yaml)
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    hcl_content = File.read('db/schema.hcl')
    
    # Verify polymorphic columns
    assert_includes hcl_content, 'column "commentable_id"'
    assert_includes hcl_content, 'column "commentable_type"'
    
    # Verify polymorphic index
    assert_includes hcl_content, 'index "index_comments_on_commentable_id_and_commentable_type"'
    assert_includes hcl_content, 'columns = [column.commentable_id, column.commentable_type]'
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

  def capture_output
    original_stdout = $stdout
    original_stderr = $stderr
    
    captured_stdout = StringIO.new
    captured_stderr = StringIO.new
    
    $stdout = captured_stdout
    $stderr = captured_stderr
    
    yield
    
    [captured_stdout.string, captured_stderr.string]
  ensure
    $stdout = original_stdout
    $stderr = original_stderr
  end
end

if __FILE__ == $0
  # Run the tests when executed directly
  puts "Running standalone YAML to HCL converter tests..."
  puts
end
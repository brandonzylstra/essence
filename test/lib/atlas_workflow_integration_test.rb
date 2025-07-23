# frozen_string_literal: true

require 'test_helper'
require_relative '../../lib/yaml_to_hcl_converter'
require_relative '../../lib/atlas_rails_bridge'
require 'tempfile'
require 'fileutils'
require 'sqlite3'

class AtlasWorkflowIntegrationTest < ActiveSupport::TestCase
  def setup
    @test_dir = Dir.mktmpdir('atlas_integration_test')
    @original_dir = Dir.pwd
    Dir.chdir(@test_dir)
    
    # Create Rails-like directory structure
    FileUtils.mkdir_p('db/migrate')
    FileUtils.mkdir_p('db/atlas_migrations')
    FileUtils.mkdir_p('storage')
    FileUtils.mkdir_p('config')
    
    # Create test database
    @db_path = 'storage/test.sqlite3'
    @db = SQLite3::Database.new(@db_path)
    
    # Create basic database.yml
    File.write('config/database.yml', test_database_yml)
    
    # Create Atlas configuration
    File.write('atlas.hcl', test_atlas_config)
  end

  def teardown
    @db&.close
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@test_dir)
  end

  test "complete workflow: YAML to database" do
    # Step 1: Create YAML schema
    create_test_yaml_schema
    
    # Step 2: Convert YAML to HCL
    converter = YamlToHclConverter.new
    converter.convert!
    
    # Verify HCL file was created
    assert File.exist?('db/schema.hcl')
    
    # Step 3: Verify HCL content is correct
    hcl_content = File.read('db/schema.hcl')
    assert_includes hcl_content, 'table "users"'
    assert_includes hcl_content, 'table "posts"'
    assert_includes hcl_content, 'foreign_key "fk_posts_user_id"'
    
    # Step 4: Test that we can inspect the HCL with Atlas (dry run)
    # This verifies the HCL syntax is valid
    skip_atlas_commands unless atlas_available?
    
    result = system("atlas schema apply --env test --dry-run > /dev/null 2>&1")
    assert result, "Atlas should be able to parse the generated HCL"
  end

  test "file location preferences work correctly" do
    # Test 1: Prefers .yaml over .yml
    File.write('db/schema.yaml', simple_yaml_schema)
    File.write('db/schema.yml', 'invalid: yaml')
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    hcl_content = File.read('db/schema.hcl')
    assert_includes hcl_content, 'table "test_table"'
    refute_includes hcl_content, 'invalid'
    
    # Clean up
    File.delete('db/schema.hcl')
    File.delete('db/schema.yml')
    
    # Test 2: Prefers db/ over root
    File.write('schema.yaml', 'invalid: yaml')
    # db/schema.yaml already exists from previous test
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    hcl_content = File.read('db/schema.hcl')
    assert_includes hcl_content, 'table "test_table"'
    refute_includes hcl_content, 'invalid'
    
    # Clean up
    File.delete('schema.yaml')
  end

  test "YAML conversion handles complex relationships" do
    create_complex_yaml_schema
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    hcl_content = File.read('db/schema.hcl')
    
    # Test foreign keys
    assert_includes hcl_content, 'foreign_key "fk_posts_user_id"'
    assert_includes hcl_content, 'on_delete = CASCADE'
    assert_includes hcl_content, 'foreign_key "fk_posts_category_id"'
    assert_includes hcl_content, 'on_delete = SET_NULL'
    
    # Test indexes
    assert_includes hcl_content, 'index "index_users_on_email"'
    assert_includes hcl_content, 'index "index_posts_on_user_id_and_published_unique"'
    assert_includes hcl_content, 'unique = true'
    
    # Test column types and constraints
    assert_includes hcl_content, 'type = varchar(255)'
    assert_includes hcl_content, 'null = false'
    assert_includes hcl_content, 'default = true'
  end

  test "Atlas Rails Bridge generates correct seed data" do
    bridge = AtlasRailsBridge.new(atlas_env: 'test', rails_root: '.')
    bridge.generate_seed_data
    
    assert File.exist?('db/seeds.rb')
    
    seed_content = File.read('db/seeds.rb')
    
    # Verify all expected event types
    expected_events = [
      'Persuasive Speaking',
      'Informative Speaking', 
      'Original Oratory',
      'Duo Interpretation',
      'Team Policy Debate',
      'Lincoln Douglas Debate',
      'Apologetics'
    ]
    
    expected_events.each do |event|
      assert_includes seed_content, "name: '#{event}'"
    end
    
    # Verify proper Ruby syntax
    assert_nothing_raised do
      RubyVM::InstructionSequence.compile(seed_content)
    end
  end

  test "migration generation works with valid SQL" do
    bridge = AtlasRailsBridge.new(atlas_env: 'test', rails_root: '.')
    
    # Mock Atlas migration plan
    test_sql = [
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name VARCHAR(255) NOT NULL)',
      'CREATE INDEX idx_users_name ON users (name)',
      'CREATE UNIQUE INDEX idx_users_email ON users (email)'
    ]
    
    bridge.define_singleton_method(:get_atlas_migration_plan) { test_sql }
    
    # Generate migration
    bridge.generate_migration('create_users')
    
    # Verify migration file exists
    migration_files = Dir.glob('db/migrate/*create_users.rb')
    assert_equal 1, migration_files.length
    
    # Verify migration content
    content = File.read(migration_files.first)
    assert_includes content, 'class CreateUsers < ActiveRecord::Migration[8.0]'
    assert_includes content, 'def up'
    assert_includes content, 'def down'
    assert_includes content, 'ActiveRecord::IrreversibleMigration'
    
    # Verify valid Ruby syntax
    assert_nothing_raised do
      RubyVM::InstructionSequence.compile(content)
    end
  end

  test "handles polymorphic relationships correctly" do
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

  test "handles enum-like string constraints" do
    enum_yaml = <<~YAML
      schema_name: main
      tables:
        orders:
          columns:
            id: primary_key
            status: string(20) default='pending' not_null
            priority: string(10) default='normal' not_null
            created_at: datetime not_null
          indexes:
            - status
            - priority
    YAML
    
    File.write('db/schema.yaml', enum_yaml)
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    hcl_content = File.read('db/schema.hcl')
    
    # Verify enum-like columns with defaults
    assert_includes hcl_content, "default = 'pending'"
    assert_includes hcl_content, "default = 'normal'"
    assert_includes hcl_content, 'type = varchar(20)'
    assert_includes hcl_content, 'type = varchar(10)'
  end

  test "supports different column types correctly" do
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

  test "handles missing files gracefully" do
    # Test missing YAML file
    converter = YamlToHclConverter.new('nonexistent.yaml', 'output.hcl')
    
    assert_raises(SystemExit) do
      capture_io { converter.convert! }
    end
  end

  test "validates generated HCL syntax" do
    create_test_yaml_schema
    
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

  test "handles empty schema gracefully" do
    empty_yaml = <<~YAML
      schema_name: main
      tables: {}
    YAML
    
    File.write('db/schema.yaml', empty_yaml)
    
    converter = YamlToHclConverter.new
    converter.convert!
    
    hcl_content = File.read('db/schema.hcl')
    
    # Should generate valid HCL with just schema
    assert_includes hcl_content, 'schema "main" {}'
    assert_match(/\A.*schema "main" \{\}.*\z/m, hcl_content)
  end

  test "preserves case sensitivity in names" do
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

  private

  def create_test_yaml_schema
    yaml_content = <<~YAML
      schema_name: main
      tables:
        users:
          columns:
            id: primary_key
            email: string(255) not_null unique
            name: string(100) not_null
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
    YAML
    
    File.write('db/schema.yaml', yaml_content)
  end

  def create_complex_yaml_schema
    yaml_content = <<~YAML
      schema_name: main
      tables:
        categories:
          columns:
            id: primary_key
            name: string(100) not_null unique
            created_at: datetime not_null

        users:
          columns:
            id: primary_key
            email: string(255) not_null unique
            name: string(100) not_null
            role: string(20) default='user' not_null
            created_at: datetime not_null
          indexes:
            - email
            - role

        posts:
          columns:
            id: primary_key
            user_id: integer -> users.id on_delete=cascade not_null
            category_id: integer -> categories.id on_delete=set_null
            title: string(255) not_null
            body: text
            published: boolean default=false not_null
            view_count: integer default=0 not_null
            created_at: datetime not_null
          indexes:
            - user_id
            - category_id
            - published
            - columns: [user_id, published]
              unique: true
    YAML
    
    File.write('db/schema.yaml', yaml_content)
  end

  def simple_yaml_schema
    <<~YAML
      schema_name: main
      tables:
        test_table:
          columns:
            id: primary_key
            name: string(100) not_null
    YAML
  end

  def test_database_yml
    <<~YAML
      test:
        adapter: sqlite3
        database: #{@db_path}
        pool: 5
        timeout: 5000
    YAML
  end

  def test_atlas_config
    <<~HCL
      env "test" {
        src = "file://db/schema.hcl"
        url = "sqlite://#{@db_path}"
        dev = "sqlite://file?mode=memory&_fk=1"
        migration {
          dir = "file://db/atlas_migrations"
        }
      }
    HCL
  end

  def atlas_available?
    system("atlas version > /dev/null 2>&1")
  end

  def skip_atlas_commands
    skip "Atlas CLI not available - install with: curl -sSf https://atlasgo.sh | sh"
  end

  def capture_io
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
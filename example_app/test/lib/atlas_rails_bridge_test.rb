# frozen_string_literal: true

require 'test_helper'
require_relative '../../lib/atlas_rails_bridge'
require 'tempfile'
require 'fileutils'
require 'open3'

class AtlasRailsBridgeTest < ActiveSupport::TestCase
  def setup
    @test_dir = Dir.mktmpdir('atlas_bridge_test')
    @original_dir = Dir.pwd
    Dir.chdir(@test_dir)

    # Create Rails-like directory structure
    FileUtils.mkdir_p('db/migrate')
    FileUtils.mkdir_p('db/atlas_migrations')
    FileUtils.mkdir_p('config')

    # Create basic database.yml
    File.write('config/database.yml', test_database_yml)

    @bridge = AtlasRailsBridge.new(atlas_env: 'test', rails_root: '.')
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@test_dir)
  end

  test "initializes with correct directories" do
    assert_equal 'test', @bridge.instance_variable_get(:@atlas_env)
    assert_equal '.', @bridge.instance_variable_get(:@rails_root)
    assert File.directory?('db/migrate')
    assert File.directory?('db')
  end

  test "generates seed data correctly" do
    @bridge.generate_seed_data

    assert File.exist?('db/seeds.rb')
    seed_content = File.read('db/seeds.rb')

    # Check that all expected event types are present
    assert_includes seed_content, "EventType.find_or_create_by(name: 'Persuasive Speaking')"
    assert_includes seed_content, "EventType.find_or_create_by(name: 'Lincoln Douglas Debate')"
    assert_includes seed_content, "EventType.find_or_create_by(name: 'Team Policy Debate')"
    assert_includes seed_content, "EventType.find_or_create_by(name: 'Apologetics')"

    # Check structure
    assert_includes seed_content, "event.abbreviation = 'PERS'"
    assert_includes seed_content, "event.category = 'speech'"
    assert_includes seed_content, "event.participant_type = 'individual'"
    assert_includes seed_content, "event.max_participants_per_match = 8"
  end

  test "generates seed data with proper file header" do
    @bridge.generate_seed_data

    seed_content = File.read('db/seeds.rb')
    assert_includes seed_content, "# Event Types for Speech & Debate Tournaments"
  end

  test "seed data includes all required event types" do
    @bridge.generate_seed_data

    seed_content = File.read('db/seeds.rb')

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
  end

  test "converts SQL types to Rails types correctly" do
    # Test the private method through reflection
    bridge = @bridge

    assert_equal 'string, limit: 255', bridge.send(:convert_sql_type_to_rails, 'varchar(255)')
    assert_equal 'decimal, precision: 8, scale: 2', bridge.send(:convert_sql_type_to_rails, 'decimal(8,2)')
    assert_equal 'integer', bridge.send(:convert_sql_type_to_rails, 'integer')
    assert_equal 'text', bridge.send(:convert_sql_type_to_rails, 'text')
    assert_equal 'boolean', bridge.send(:convert_sql_type_to_rails, 'boolean')
    assert_equal 'datetime', bridge.send(:convert_sql_type_to_rails, 'datetime')
    assert_equal 'date', bridge.send(:convert_sql_type_to_rails, 'date')
  end

  test "converts simple SQL statements to Rails equivalents" do
    bridge = @bridge

    # Test CREATE TABLE
    assert_equal 'create_table :users do |t|',
                 bridge.send(:convert_sql_to_rails, 'CREATE TABLE users (')

    # Test DROP TABLE
    assert_equal 'drop_table :users',
                 bridge.send(:convert_sql_to_rails, 'DROP TABLE users')

    # Test ADD COLUMN
    assert_equal 'add_column :users, :email, :string',
                 bridge.send(:convert_sql_to_rails, 'ALTER TABLE users ADD COLUMN email VARCHAR')

    # Test DROP COLUMN
    assert_equal 'remove_column :users, :email',
                 bridge.send(:convert_sql_to_rails, 'ALTER TABLE users DROP COLUMN email')
  end

  test "generates Rails migration content correctly" do
    sql_statements = [
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name VARCHAR(255))',
      'CREATE INDEX idx_users_name ON users (name)'
    ]

    content = @bridge.send(:generate_migration_content, 'CreateUsers', sql_statements)

    assert_includes content, 'class CreateUsers < ActiveRecord::Migration[8.0]'
    assert_includes content, 'def up'
    assert_includes content, 'def down'
    assert_includes content, 'ActiveRecord::IrreversibleMigration'
  end

  test "creates migration file with correct timestamp" do
    # Mock the get_atlas_migration_plan method
    @bridge.define_singleton_method(:get_atlas_migration_plan) do
      [ 'CREATE TABLE test_table (id INTEGER)' ]
    end

    freeze_time = Time.new(2024, 1, 15, 12, 30, 45)

    Time.stub(:now, freeze_time) do
      @bridge.generate_migration('test_migration')
    end

    expected_filename = '20240115123045_test_migration.rb'
    assert File.exist?("db/migrate/#{expected_filename}")

    content = File.read("db/migrate/#{expected_filename}")
    assert_includes content, 'class TestMigration < ActiveRecord::Migration[8.0]'
  end

  test "handles empty migration plan gracefully" do
    # Mock empty migration plan
    @bridge.define_singleton_method(:get_atlas_migration_plan) { [] }

    # Capture output
    output = capture_io do
      @bridge.generate_migration('test_migration')
    end.first

    assert_includes output, 'No schema changes detected'
  end

  test "formats default values correctly" do
    bridge = @bridge

    assert_equal 'true', bridge.send(:format_default_value, 'true')
    assert_equal 'false', bridge.send(:format_default_value, 'false')
    assert_equal '42', bridge.send(:format_default_value, '42')
    assert_equal '3.14', bridge.send(:format_default_value, '3.14')
    assert_equal "'hello'", bridge.send(:format_default_value, 'hello')
    assert_equal "'user'", bridge.send(:format_default_value, 'user')
  end

  test "gets Rails version correctly" do
    version = @bridge.send(:get_rails_version)
    assert_equal '8.0', version
  end

  test "generates migration with complex SQL fallback" do
    complex_sql = [
      'CREATE UNIQUE INDEX CONCURRENTLY idx_complex ON users (lower(email))',
      'ALTER TABLE users ADD CONSTRAINT check_positive_age CHECK (age > 0)'
    ]

    @bridge.define_singleton_method(:get_atlas_migration_plan) { complex_sql }

    @bridge.generate_migration('complex_migration')

    # Find the generated migration file
    migration_files = Dir.glob('db/migrate/*complex_migration.rb')
    assert_equal 1, migration_files.length

    content = File.read(migration_files.first)

    # Should fall back to raw SQL for complex statements
    assert_includes content, 'execute <<~SQL'
    assert_includes content, 'CREATE UNIQUE INDEX CONCURRENTLY'
    assert_includes content, 'CHECK (age > 0)'
  end

  test "handles invalid SQL gracefully" do
    invalid_sql = [ 'INVALID SQL STATEMENT' ]

    @bridge.define_singleton_method(:get_atlas_migration_plan) { invalid_sql }

    # Should not raise an error, should create migration with raw SQL
    assert_nothing_raised do
      @bridge.generate_migration('invalid_sql_migration')
    end

    migration_files = Dir.glob('db/migrate/*invalid_sql_migration.rb')
    assert_equal 1, migration_files.length

    content = File.read(migration_files.first)
    assert_includes content, 'execute <<~SQL'
    assert_includes content, 'INVALID SQL STATEMENT'
  end

  test "generates seed data file in correct location" do
    @bridge.generate_seed_data

    assert File.exist?('db/seeds.rb')
    refute File.exist?('seeds.rb') # Should not create in root
  end

  test "seed data contains proper Ruby syntax" do
    @bridge.generate_seed_data

    seed_content = File.read('db/seeds.rb')

    # Check for proper Ruby syntax
    assert_no_match /syntax error/, seed_content

    # Should be valid Ruby code
    assert_nothing_raised do
      # Parse the Ruby code to check syntax
      RubyVM::InstructionSequence.compile(seed_content)
    end
  end

  test "handles migration name with spaces and special characters" do
    @bridge.define_singleton_method(:get_atlas_migration_plan) do
      [ 'CREATE TABLE test (id INTEGER)' ]
    end

    @bridge.generate_migration('Add User Tables & Indexes')

    # Should convert to valid filename and class name
    migration_files = Dir.glob('db/migrate/*add_user_tables_&_indexes.rb')
    assert_equal 1, migration_files.length

    content = File.read(migration_files.first)
    assert_includes content, 'class AddUserTablesIndexes <'
  end

  test "migration content includes proper documentation" do
    @bridge.define_singleton_method(:get_atlas_migration_plan) do
      [ 'CREATE TABLE users (id INTEGER)' ]
    end

    @bridge.generate_migration('test_migration')

    migration_files = Dir.glob('db/migrate/*test_migration.rb')
    content = File.read(migration_files.first)

    # Should include documentation about rollback
    assert_includes content, '# Atlas handles rollbacks via schema state comparison'
    assert_includes content, '# To rollback, revert your schema.hcl file'
  end

  private

  def test_database_yml
    <<~YAML
      development:
        adapter: sqlite3
        database: storage/development.sqlite3
        pool: 5
        timeout: 5000

      test:
        adapter: sqlite3
        database: storage/test.sqlite3
        pool: 5
        timeout: 5000
    YAML
  end

  def capture_io
    original_stdout = $stdout
    original_stderr = $stderr

    captured_stdout = StringIO.new
    captured_stderr = StringIO.new

    $stdout = captured_stdout
    $stderr = captured_stderr

    yield

    [ captured_stdout.string, captured_stderr.string ]
  ensure
    $stdout = original_stdout
    $stderr = original_stderr
  end
end

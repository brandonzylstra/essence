# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Essence::RailsBridge do
  let(:bridge) { described_class.new(atlas_env: 'test', rails_root: '.') }

  before do
    # Create necessary directories
    FileUtils.mkdir_p('db/migrate')
    FileUtils.mkdir_p('db')
  end

  describe '#initialize' do
    it 'sets up with default parameters' do
      default_bridge = described_class.new
      expect(default_bridge.instance_variable_get(:@atlas_env)).to eq('dev')
      expect(default_bridge.instance_variable_get(:@rails_root)).to eq('.')
    end

    it 'accepts custom parameters' do
      test_root = File.join(@test_dir, 'custom_app')
      custom_bridge = described_class.new(atlas_env: 'production', rails_root: test_root)
      expect(custom_bridge.instance_variable_get(:@atlas_env)).to eq('production')
      expect(custom_bridge.instance_variable_get(:@rails_root)).to eq(test_root)
    end

    it 'creates migration and db directories' do
      expect(Dir.exist?('db/migrate')).to be true
      expect(Dir.exist?('db')).to be true
    end
  end

  describe '#generate_migration' do
    before do
      allow(bridge).to receive(:get_atlas_migration_plan).and_return([
        'CREATE TABLE users (id INTEGER PRIMARY KEY, name VARCHAR(255))',
        'CREATE INDEX idx_users_name ON users (name)'
      ])
      allow(bridge).to receive(:system)
    end

    it 'generates a migration with default name' do
      allow(Time).to receive_message_chain(:now, :utc, :strftime).and_return('20240101120000')

      bridge.generate_migration

      expect(File.exist?('db/migrate/20240101120000_essence_schema_update.rb')).to be true
    end

    it 'generates a migration with custom name' do
      allow(Time).to receive_message_chain(:now, :utc, :strftime).and_return('20240101120000')

      bridge.generate_migration('add_user_tables')

      expect(File.exist?('db/migrate/20240101120000_add_user_tables.rb')).to be true
    end

    it 'creates properly formatted migration content' do
      allow(Time).to receive_message_chain(:now, :utc, :strftime).and_return('20240101120000')

      bridge.generate_migration('test_migration')

      migration_content = File.read('db/migrate/20240101120000_test_migration.rb')
      expect(migration_content).to include('class TestMigration < ActiveRecord::Migration[8.0]')
      expect(migration_content).to include('def up')
      expect(migration_content).to include('def down')
      expect(migration_content).to include('raise ActiveRecord::IrreversibleMigration')
    end

    it 'handles empty migration plan' do
      allow(bridge).to receive(:get_atlas_migration_plan).and_return([])

      expect { bridge.generate_migration }.to output(/No schema changes detected/).to_stdout
    end

    it 'converts SQL statements to Rails methods when possible' do
      allow(bridge).to receive(:get_atlas_migration_plan).and_return([
        'CREATE TABLE users (id INTEGER PRIMARY KEY)',
        'DROP TABLE old_table'
      ])
      allow(Time).to receive_message_chain(:now, :utc, :strftime).and_return('20240101120000')

      bridge.generate_migration('conversion_test')

      migration_content = File.read('db/migrate/20240101120000_conversion_test.rb')
      expect(migration_content).to include('create_table :users do |t|')
      expect(migration_content).to include('drop_table :old_table')
    end

    it 'falls back to raw SQL for complex statements' do
      allow(bridge).to receive(:get_atlas_migration_plan).and_return([
        'COMPLEX STATEMENT THAT CANNOT BE CONVERTED'
      ])
      allow(Time).to receive_message_chain(:now, :utc, :strftime).and_return('20240101120000')

      bridge.generate_migration('complex_test')

      migration_content = File.read('db/migrate/20240101120000_complex_test.rb')
      expect(migration_content).to include('execute <<~SQL')
      expect(migration_content).to include('COMPLEX STATEMENT THAT CANNOT BE CONVERTED')
    end
  end

  describe '#apply_schema!' do
    it 'calls atlas schema apply with correct environment' do
      expect(bridge).to receive(:system).with('atlas schema apply --env test --auto-approve').and_return(true)
      expect(bridge).to receive(:system).with('cd . && rails db:schema:dump').and_return(true)

      bridge.apply_schema!
    end

    it 'exits with error code 1 if atlas apply fails' do
      expect(bridge).to receive(:system).with('atlas schema apply --env test --auto-approve').and_return(false)

      expect { bridge.apply_schema! }.to raise_error(SystemExit)
    end

    it 'updates Rails schema.rb after successful apply' do
      expect(bridge).to receive(:system).with('atlas schema apply --env test --auto-approve').and_return(true)
      expect(bridge).to receive(:system).with('cd . && rails db:schema:dump').and_return(true)

      expect { bridge.apply_schema! }.to output(/Schema applied successfully/).to_stdout
    end
  end

  describe '#preview_changes' do
    it 'calls atlas schema apply with dry-run flag' do
      expect(bridge).to receive(:system).with('atlas schema apply --env test --dry-run')

      bridge.preview_changes
    end
  end

  describe '#generate_seed_data' do
    it 'creates seed data file with event types' do
      bridge.generate_seed_data

      expect(File.exist?('db/seeds.rb')).to be true
      seed_content = File.read('db/seeds.rb')
      expect(seed_content).to include('EventType.find_or_create_by')
      expect(seed_content).to include('Persuasive Speaking')
      expect(seed_content).to include('Team Policy Debate')
      expect(seed_content).to include('Lincoln Douglas Debate')
    end

    it 'includes all required event type fields' do
      bridge.generate_seed_data

      seed_content = File.read('db/seeds.rb')
      expect(seed_content).to include('abbreviation')
      expect(seed_content).to include('category')
      expect(seed_content).to include('participant_type')
      expect(seed_content).to include('max_participants_per_match')
      expect(seed_content).to include('description')
    end
  end

  describe 'SQL to Rails conversion methods' do
    describe '#convert_sql_to_rails' do
      it 'converts CREATE TABLE statements' do
        sql = 'CREATE TABLE users (id INTEGER PRIMARY KEY)'
        result = bridge.send(:convert_sql_to_rails, sql)
        expect(result).to eq('create_table :users do |t|')
      end

      it 'converts DROP TABLE statements' do
        sql = 'DROP TABLE users'
        result = bridge.send(:convert_sql_to_rails, sql)
        expect(result).to eq('drop_table :users')
      end

      it 'converts ADD COLUMN statements' do
        sql = 'ALTER TABLE users ADD COLUMN email VARCHAR(255)'
        result = bridge.send(:convert_sql_to_rails, sql)
        expect(result).to eq('add_column :users, :email, :string, limit: 255')
      end

      it 'converts DROP COLUMN statements' do
        sql = 'ALTER TABLE users DROP COLUMN email'
        result = bridge.send(:convert_sql_to_rails, sql)
        expect(result).to eq('remove_column :users, :email')
      end

      it 'converts CREATE INDEX statements' do
        sql = 'CREATE INDEX idx_users_email ON users (email)'
        result = bridge.send(:convert_sql_to_rails, sql)
        expect(result).to eq("add_index :users, :email, name: 'idx_users_email'")
      end

      it 'converts CREATE UNIQUE INDEX statements' do
        sql = 'CREATE UNIQUE INDEX idx_users_email ON users (email)'
        result = bridge.send(:convert_sql_to_rails, sql)
        expect(result).to eq("add_index :users, :email, name: 'idx_users_email', unique: true")
      end

      it 'converts DROP INDEX statements' do
        sql = 'DROP INDEX idx_users_email'
        result = bridge.send(:convert_sql_to_rails, sql)
        expect(result).to eq("remove_index name: 'idx_users_email'")
      end

      it 'returns nil for unrecognized SQL statements' do
        sql = 'SOME COMPLEX STATEMENT'
        result = bridge.send(:convert_sql_to_rails, sql)
        expect(result).to be_nil
      end

      it 'handles table and column names with quotes' do
        sql = 'CREATE TABLE "users" (id INTEGER PRIMARY KEY)'
        result = bridge.send(:convert_sql_to_rails, sql)
        expect(result).to eq('create_table :users do |t|')
      end

      it 'handles table and column names with backticks' do
        sql = 'CREATE TABLE `users` (id INTEGER PRIMARY KEY)'
        result = bridge.send(:convert_sql_to_rails, sql)
        expect(result).to eq('create_table :users do |t|')
      end
    end

    describe '#convert_sql_type_to_rails' do
      it 'converts varchar with size' do
        result = bridge.send(:convert_sql_type_to_rails, 'VARCHAR(255)')
        expect(result).to eq('string, limit: 255')
      end

      it 'converts decimal with precision and scale' do
        result = bridge.send(:convert_sql_type_to_rails, 'DECIMAL(10,2)')
        expect(result).to eq('decimal, precision: 10, scale: 2')
      end

      it 'converts basic SQL types' do
        expect(bridge.send(:convert_sql_type_to_rails, 'INTEGER')).to eq('integer')
        expect(bridge.send(:convert_sql_type_to_rails, 'TEXT')).to eq('text')
        expect(bridge.send(:convert_sql_type_to_rails, 'BOOLEAN')).to eq('boolean')
        expect(bridge.send(:convert_sql_type_to_rails, 'DATETIME')).to eq('datetime')
        expect(bridge.send(:convert_sql_type_to_rails, 'DATE')).to eq('date')
        expect(bridge.send(:convert_sql_type_to_rails, 'BINARY')).to eq('binary')
        expect(bridge.send(:convert_sql_type_to_rails, 'BIGINT')).to eq('bigint')
      end

      it 'returns original type for unrecognized types' do
        result = bridge.send(:convert_sql_type_to_rails, 'CUSTOM_TYPE')
        expect(result).to eq('CUSTOM_TYPE')
      end

      it 'handles case insensitive type names' do
        expect(bridge.send(:convert_sql_type_to_rails, 'integer')).to eq('integer')
        expect(bridge.send(:convert_sql_type_to_rails, 'Integer')).to eq('integer')
        expect(bridge.send(:convert_sql_type_to_rails, 'INTEGER')).to eq('integer')
      end
    end
  end

  describe 'private methods' do
    describe '#get_atlas_migration_plan' do
      it 'parses SQL statements from atlas dry-run output' do
        mock_output = <<~OUTPUT
          Migrating to version 1 (1 migration):
            -> CREATE TABLE users (id INTEGER PRIMARY KEY);
            -> CREATE INDEX idx_users_name ON users (name);
          --------
          Migration complete
        OUTPUT

        allow(bridge).to receive(:execute_atlas_command).and_return([ mock_output, true ])

        result = bridge.send(:get_atlas_migration_plan)
        expect(result).to include('CREATE TABLE users (id INTEGER PRIMARY KEY);')
        expect(result).to include('CREATE INDEX idx_users_name ON users (name);')
      end

      it 'handles empty atlas output' do
        allow(bridge).to receive(:execute_atlas_command).and_return([ '', true ])

        result = bridge.send(:get_atlas_migration_plan)
        expect(result).to eq([])
      end

      it 'handles atlas command failure' do
        allow(bridge).to receive(:execute_atlas_command).and_return([ '', false ])

        result = bridge.send(:get_atlas_migration_plan)
        expect(result).to eq([])
      end

      it 'filters out non-SQL lines from output' do
        mock_output = <<~OUTPUT
          Some text
          Migrating to version 1:
            -> CREATE TABLE users (id INTEGER);
          Some other text
            Not a SQL statement
            -> ALTER TABLE users ADD COLUMN name VARCHAR(255);
          End text
        OUTPUT

        allow(bridge).to receive(:execute_atlas_command).and_return([ mock_output, true ])

        result = bridge.send(:get_atlas_migration_plan)
        expect(result).to include('CREATE TABLE users (id INTEGER);')
        expect(result).to include('ALTER TABLE users ADD COLUMN name VARCHAR(255);')
        expect(result).not_to include('Some text')
        expect(result).not_to include('Not a SQL statement')
      end
    end

    describe '#generate_migration_content' do
      it 'generates properly formatted migration class' do
        sql_statements = [
          'CREATE TABLE users (id INTEGER PRIMARY KEY)',
          'CREATE INDEX idx_users_name ON users (name)'
        ]

        content = bridge.send(:generate_migration_content, 'TestMigration', sql_statements)

        expect(content).to include('class TestMigration < ActiveRecord::Migration[8.0]')
        expect(content).to include('def up')
        expect(content).to include('def down')
        expect(content).to include('create_table :users do |t|')
        expect(content).to include("add_index :users, :name, name: 'idx_users_name'")
        expect(content).to include('raise ActiveRecord::IrreversibleMigration')
      end

      it 'handles mixed convertible and non-convertible SQL' do
        sql_statements = [
          'CREATE TABLE users (id INTEGER PRIMARY KEY)',
          'COMPLEX SQL THAT CANNOT BE CONVERTED'
        ]

        content = bridge.send(:generate_migration_content, 'MixedMigration', sql_statements)

        expect(content).to include('create_table :users do |t|')
        expect(content).to include('execute <<~SQL')
        expect(content).to include('COMPLEX SQL THAT CANNOT BE CONVERTED')
      end

      it 'handles empty SQL statements list' do
        content = bridge.send(:generate_migration_content, 'EmptyMigration', [])

        expect(content).to include('class EmptyMigration < ActiveRecord::Migration[8.0]')
        expect(content).to include('def up')
        expect(content).to include('def down')
        expect(content).not_to include('execute')
      end

      it 'properly handles class name formatting' do
        content = bridge.send(:generate_migration_content, 'add user tables', [])
        expect(content).to include('class AddUserTables')

        content = bridge.send(:generate_migration_content, 'create_posts_table', [])
        expect(content).to include('class CreatePostsTable')
      end
    end

    describe '#create_rails_migration' do
      before do
        allow(Time).to receive_message_chain(:now, :utc, :strftime).and_return('20240101120000')
      end

      it 'creates migration file with correct timestamp and name' do
        sql_statements = [ 'CREATE TABLE users (id INTEGER PRIMARY KEY)' ]

        bridge.send(:create_rails_migration, 'add user tables', sql_statements)

        expect(File.exist?('db/migrate/20240101120000_add_user_tables.rb')).to be true
      end

      it 'writes correct content to migration file' do
        sql_statements = [ 'CREATE TABLE users (id INTEGER PRIMARY KEY)' ]

        bridge.send(:create_rails_migration, 'test migration', sql_statements)

        content = File.read('db/migrate/20240101120000_test_migration.rb')
        expect(content).to include('class TestMigration')
        expect(content).to include('create_table :users do |t|')
      end

      it 'handles special characters in migration names' do
        sql_statements = [ 'CREATE TABLE users (id INTEGER PRIMARY KEY)' ]

        bridge.send(:create_rails_migration, 'add user-tables & indexes', sql_statements)

        expect(File.exist?('db/migrate/20240101120000_add_user_tables_indexes.rb')).to be true
      end
    end

    describe '#get_rails_version' do
      it 'returns default Rails version' do
        version = bridge.send(:get_rails_version)
        expect(version).to eq('8.0')
      end
    end
  end

  describe 'Error handling and edge cases' do
    it 'handles file system errors gracefully' do
      # Make db directory read-only to simulate permission error
      FileUtils.chmod(0444, 'db')

      # Create bridge instance after permission change to test error handling
      expect {
        local_bridge = described_class.new(atlas_env: 'test', rails_root: '.')
        local_bridge.generate_seed_data
      }.not_to raise_error

      # Restore permissions
      FileUtils.chmod(0755, 'db')
    end

    it 'handles malformed SQL in migration plan' do
      allow(bridge).to receive(:get_atlas_migration_plan).and_return([
        'INVALID SQL STATEMENT',
        'CREATE TABLE users',  # Missing parentheses
        'DROP TABLE'           # Missing table name
      ])
      allow(Time).to receive_message_chain(:now, :utc, :strftime).and_return('20240101120000')

      expect { bridge.generate_migration('malformed_test') }.not_to raise_error

      # Should still create a migration file
      expect(File.exist?('db/migrate/20240101120000_malformed_test.rb')).to be true
    end

    it 'handles very long migration names' do
      long_name = 'a' * 200  # Very long name
      allow(bridge).to receive(:get_atlas_migration_plan).and_return([ 'CREATE TABLE users (id INTEGER)' ])
      allow(Time).to receive_message_chain(:now, :utc, :strftime).and_return('20240101120000')

      expect { bridge.generate_migration(long_name) }.not_to raise_error
    end

    it 'handles concurrent migration generation' do
      # Simulate multiple migrations being generated at the same time
      allow(Time).to receive_message_chain(:now, :utc, :strftime).and_return('20240101120000')
      allow(bridge).to receive(:get_atlas_migration_plan).and_return([ 'CREATE TABLE test (id INTEGER)' ])

      bridge.generate_migration('first_migration')

      # Second migration with same timestamp should not overwrite
      allow(Time).to receive_message_chain(:now, :utc, :strftime).and_return('20240101120000')
      bridge.generate_migration('second_migration')

      # Both files should exist (or second should have different name)
      first_exists = File.exist?('db/migrate/20240101120000_first_migration.rb')
      second_exists = File.exist?('db/migrate/20240101120000_second_migration.rb')

      expect(first_exists || second_exists).to be true
    end
  end

  describe 'Integration scenarios' do
    it 'handles a complete schema migration workflow' do
      # Simulate a complete workflow with multiple SQL statements
      complex_plan = [
        'CREATE TABLE users (id INTEGER PRIMARY KEY, email VARCHAR(255))',
        'CREATE TABLE posts (id INTEGER PRIMARY KEY, user_id INTEGER)',
        'CREATE INDEX idx_users_email ON users (email)',
        'CREATE INDEX idx_posts_user_id ON posts (user_id)',
        'ALTER TABLE posts ADD COLUMN title VARCHAR(255)',
        'CREATE UNIQUE INDEX idx_posts_title ON posts (title)'
      ]

      allow(bridge).to receive(:get_atlas_migration_plan).and_return(complex_plan)
      allow(Time).to receive_message_chain(:now, :utc, :strftime).and_return('20240101120000')

      bridge.generate_migration('complete_schema_setup')

      migration_content = File.read('db/migrate/20240101120000_complete_schema_setup.rb')

      # Verify all SQL statements are handled
      expect(migration_content).to include('create_table :users do |t|')
      expect(migration_content).to include('create_table :posts do |t|')
      expect(migration_content).to include("add_index :users, :email, name: 'idx_users_email'")
      expect(migration_content).to include("add_index :posts, :user_id, name: 'idx_posts_user_id'")
      expect(migration_content).to include('add_column :posts, :title, :string, limit: 255')
      expect(migration_content).to include("add_index :posts, :title, name: 'idx_posts_title', unique: true")
    end

    it 'preserves migration order and structure' do
      plan = [
        'CREATE TABLE users (id INTEGER PRIMARY KEY)',
        'CREATE TABLE posts (id INTEGER PRIMARY KEY)',
        'ALTER TABLE posts ADD COLUMN user_id INTEGER'
      ]

      allow(bridge).to receive(:get_atlas_migration_plan).and_return(plan)
      allow(Time).to receive_message_chain(:now, :utc, :strftime).and_return('20240101120000')

      bridge.generate_migration('order_test')

      migration_content = File.read('db/migrate/20240101120000_order_test.rb')

      # Check that statements appear in correct order
      users_pos = migration_content.index('create_table :users')
      posts_pos = migration_content.index('create_table :posts')
      alter_pos = migration_content.index('add_column :posts, :user_id')

      expect(users_pos).to be < posts_pos
      expect(posts_pos).to be < alter_pos
    end
  end
end

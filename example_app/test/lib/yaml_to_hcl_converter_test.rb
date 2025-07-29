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
    if @original_dir && Dir.exist?(@original_dir)
      Dir.chdir(@original_dir)
    end
    FileUtils.rm_rf(@test_dir) if @test_dir && Dir.exist?(@test_dir)
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
      schema_name: public
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
      schema_name: public
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
      schema_name: public
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

  test "generates foreign keys correctly" do
    yaml_content = <<~YAML
      schema_name: public
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
      schema_name: public
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
      schema_name: public
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
      schema_name: public
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

  test "applies default columns to all tables" do
    yaml_content = <<~YAML
      schema_name: public
      defaults:
        "*":
          columns:
            id: primary_key
            created_at: datetime not_null
            updated_at: datetime not_null
      tables:
        users:
          columns:
            email: string(255) not_null
        posts:
          columns:
            title: string(255) not_null
    YAML

    File.write('db/schema.yaml', yaml_content)

    converter = YamlToHclConverter.new
    converter.convert!

    hcl_content = File.read('db/schema.hcl')

    # Both tables should have default columns
    assert_includes hcl_content, 'table "users"'
    assert_includes hcl_content, 'table "posts"'

    # Check that id, created_at, updated_at appear in both tables
    user_section = hcl_content[/table "users".*?(?=table|$)/m]
    post_section = hcl_content[/table "posts".*?(?=table|$)/m]

    %w[id created_at updated_at].each do |col|
      assert_includes user_section, "column \"#{col}\""
      assert_includes post_section, "column \"#{col}\""
    end

    # Check that explicit columns are also present
    assert_includes user_section, 'column "email"'
    assert_includes post_section, 'column "title"'
  end

  test "handles foreign key pattern matching" do
    yaml_content = <<~YAML
      schema_name: public
      defaults:
        "*":
          columns:
            id: primary_key
      column_patterns:
        - "_id$": "integer -> {table}.id on_delete=cascade not_null"
      tables:
        users:
          columns:
            email: string(255) not_null
        posts:
          columns:
            user_id: ~
            author_id: ~
    YAML

    File.write('db/schema.yaml', yaml_content)

    converter = YamlToHclConverter.new
    converter.convert!

    hcl_content = File.read('db/schema.hcl')

    # Check foreign key generation
    assert_includes hcl_content, 'foreign_key "fk_posts_user_id"'
    assert_includes hcl_content, 'columns = [column.user_id]'
    assert_includes hcl_content, 'ref_columns = [table.users.column.id]'
    assert_includes hcl_content, 'on_delete = CASCADE'

    assert_includes hcl_content, 'foreign_key "fk_posts_author_id"'
    assert_includes hcl_content, 'ref_columns = [table.authors.column.id]'
  end

  test "handles timestamp pattern matching" do
    yaml_content = <<~YAML
      schema_name: public
      defaults:
        "*":
          columns:
            id: primary_key
      column_patterns:
        - "_at$": "datetime not_null"
      tables:
        users:
          columns:
            last_login_at: ~
            created_at: ~
            deleted_at: ~
    YAML

    File.write('db/schema.yaml', yaml_content)

    converter = YamlToHclConverter.new
    converter.convert!

    hcl_content = File.read('db/schema.hcl')

    # Check that _at columns get datetime type
    user_section = hcl_content[/table "users".*?(?=table|$)/m]

    %w[last_login_at created_at deleted_at].each do |col|
      column_section = user_section[/column "#{col}".*?}/m]
      assert_includes column_section, 'type = datetime'
      assert_includes column_section, 'null = false'
    end
  end

  test "handles default pattern fallback" do
    yaml_content = <<~YAML
      schema_name: public
      defaults:
        "*":
          columns:
            id: primary_key
      column_patterns:
        - ".*": "string"
      tables:
        users:
          columns:
            first_name: ~
            bio: ~
            nickname: ~
    YAML

    File.write('db/schema.yaml', yaml_content)

    converter = YamlToHclConverter.new
    converter.convert!

    hcl_content = File.read('db/schema.hcl')

    # Check that unmatched columns get string type
    user_section = hcl_content[/table "users".*?(?=table|$)/m]

    %w[first_name bio nickname].each do |col|
      column_section = user_section[/column "#{col}".*?}/m]
      assert_includes column_section, 'type = varchar'
    end
  end

  test "explicit columns override patterns and defaults" do
    yaml_content = <<~YAML
      schema_name: public
      defaults:
        "*":
          columns:
            id: primary_key
            created_at: datetime not_null
      column_patterns:
        - "_id$": "integer -> {table}.id on_delete=cascade not_null"
        - "_at$": "datetime not_null"
      tables:
        posts:
          columns:
            # Override default created_at
            created_at: timestamp not_null
            # Override pattern for user_id
            user_id: bigint -> users.id on_delete=set_null
            # Use pattern matching
            category_id: ~
            published_at: ~
    YAML

    File.write('db/schema.yaml', yaml_content)

    converter = YamlToHclConverter.new
    converter.convert!

    hcl_content = File.read('db/schema.hcl')

    post_section = hcl_content[/table "posts".*?(?=table|$)/m]

    # created_at should be timestamp (explicit override)
    created_at_section = post_section[/column "created_at".*?}/m]
    assert_includes created_at_section, 'type = timestamp'

    # user_id should be bigint with SET_NULL (explicit override)
    user_id_section = post_section[/column "user_id".*?}/m]
    assert_includes user_id_section, 'type = bigint'
    assert_includes hcl_content, 'on_delete = SET_NULL'

    # category_id should use pattern (foreign key)
    assert_includes hcl_content, 'foreign_key "fk_posts_category_id"'
    assert_includes hcl_content, 'ref_columns = [table.categories.column.id]'

    # published_at should use timestamp pattern
    published_at_section = post_section[/column "published_at".*?}/m]
    assert_includes published_at_section, 'type = datetime'
  end

  test "uses default patterns when none specified" do
    yaml_content = <<~YAML
      schema_name: public
      tables:
        posts:
          columns:
            id: primary_key
            user_id: ~
            published_at: ~
            title: ~
    YAML

    File.write('db/schema.yaml', yaml_content)

    converter = YamlToHclConverter.new
    converter.convert!

    hcl_content = File.read('db/schema.hcl')

    # Should use built-in default patterns
    assert_includes hcl_content, 'foreign_key "fk_posts_user_id"'  # _id pattern

    post_section = hcl_content[/table "posts".*?(?=table|$)/m]
    published_at_section = post_section[/column "published_at".*?}/m]
    assert_includes published_at_section, 'type = datetime'  # _at pattern

    title_section = post_section[/column "title".*?}/m]
    assert_includes title_section, 'type = varchar'  # default fallback
  end

  test "handles table-specific defaults" do
    yaml_content = <<~YAML
      schema_name: public
      defaults:
        "*":
          columns:
            id: primary_key
            created_at: datetime not_null
        users:
          columns:
            active: boolean default=true not_null
            role: string(20) default='user' not_null
      tables:
        users:
          columns:
            email: string(255) not_null
        posts:
          columns:
            title: string(255) not_null
    YAML

    File.write('db/schema.yaml', yaml_content)

    converter = YamlToHclConverter.new
    converter.convert!

    hcl_content = File.read('db/schema.hcl')

    user_section = hcl_content[/table "users".*?(?=table "posts"|$)/m]
    post_section = hcl_content[/table "posts".*?(?=table|$)/m]

    # Users should have table-specific defaults
    assert_includes user_section, 'column "active"'
    assert_includes user_section, 'column "role"'

    # Posts should not have user-specific defaults
    refute_includes post_section, 'column "active"'
    refute_includes post_section, 'column "role"'

    # Both should have global defaults
    assert_includes user_section, 'column "id"'
    assert_includes user_section, 'column "created_at"'
    assert_includes post_section, 'column "id"'
    assert_includes post_section, 'column "created_at"'
  end

  test "generates template file correctly" do
    template_path = File.join(@test_dir, 'custom_schema.yaml')

    YamlToHclConverter.generate_template(template_path)

    assert File.exist?(template_path)

    template_content = File.read(template_path)

    # Check for key sections
    assert_includes template_content, 'schema_name: public'
    assert_includes template_content, 'defaults:'
    assert_includes template_content, '"*":'
    assert_includes template_content, 'column_patterns:'
    assert_includes template_content, 'pattern: "_id$"'
    assert_includes template_content, 'pattern: "_at$"'
    assert_includes template_content, 'tables:'
    assert_includes template_content, 'users:'
    assert_includes template_content, 'leagues:'

    # Verify it's valid YAML
    parsed = YAML.load_file(template_path)
    assert_not_nil parsed['defaults']['*']['columns']['id']
    assert_not_nil parsed['column_patterns']
    assert_equal 3, parsed['column_patterns'].length
  end

  test "template generates valid convertible schema" do
    template_path = File.join(@test_dir, 'db', 'schema.yaml')
    YamlToHclConverter.generate_template(template_path)

    # Convert the generated template
    converter = YamlToHclConverter.new(template_path, 'db/schema.hcl')
    converter.convert!

    assert File.exist?('db/schema.hcl')
    hcl_content = File.read('db/schema.hcl')

    # Should generate valid HCL with example tables
    assert_includes hcl_content, 'table "users"'
    assert_includes hcl_content, 'table "leagues"'

    # Should have applied defaults and patterns
    user_section = hcl_content[/table "users".*?(?=table|$)/m]
    assert_includes user_section, 'column "id"'
    assert_includes user_section, 'column "created_at"'
    assert_includes user_section, 'column "updated_at"'
    assert_includes user_section, 'column "league_id"'
    assert_includes user_section, 'column "last_login_at"'

    # Should have foreign key for league_id
    assert_includes hcl_content, 'foreign_key "fk_users_league_id"'
    assert_includes hcl_content, 'ref_columns = [table.leagues.column.id]'
  end

  test "pluralization works correctly" do
    yaml_content = <<~YAML
      schema_name: public
      column_patterns:
        - "_id$": "integer -> {table}.id on_delete=cascade not_null"
      tables:
        posts:
          columns:
            id: primary_key
            category_id: ~
            company_id: ~
            leaf_id: ~
            wife_id: ~
    YAML

    File.write('db/schema.yaml', yaml_content)

    converter = YamlToHclConverter.new
    converter.convert!

    hcl_content = File.read('db/schema.hcl')

    # Test various pluralization rules
    assert_includes hcl_content, 'ref_columns = [table.categories.column.id]'  # y -> ies
    assert_includes hcl_content, 'ref_columns = [table.companies.column.id]'   # y -> ies
    assert_includes hcl_content, 'ref_columns = [table.leaves.column.id]'      # f -> ves
    assert_includes hcl_content, 'ref_columns = [table.wives.column.id]'       # fe -> ves
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
      schema_name: public
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
      schema_name: public
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

  ##################################################################################################

  private def test_yaml_content
    <<~YAML
      schema_name: public

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

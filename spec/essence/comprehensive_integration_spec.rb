# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Comprehensive Integration Tests' do
  describe 'full template integration with all patterns' do
    it 'compiles a complete real-world schema with all patterns working together' do
      comprehensive_schema = <<~YAML
        # Enhanced Essence Schema with Default Columns and Pattern Matching
        schema_name: public

        # Default columns applied to all tables with clean ~ syntax
        defaults:
          "*":
            columns:
              id: ~
              created_at: ~
              updated_at: ~

        # Complete pattern set for comprehensive testing
        column_patterns:
          - "^id$": "primary_key"
          - "_id$": "integer -> {table}.id on_delete=cascade not_null"
          - "_at$": "datetime not_null"
          - "_on$": "date"
          - "_date$": "date"
          - "^is_": "boolean default=false not_null"
          - "^has_": "boolean default=false not_null"
          - "^can_": "boolean default=false not_null"
          - "_flag$": "boolean default=false not_null"
          - "_content$": "text"
          - "_body$": "text"
          - "_text$": "text"
          - "_html$": "text"
          - "_count$": "integer default=0 not_null"
          - "_score$": "decimal(8,2)"
          - "_amount$": "decimal(10,2)"
          - "_price$": "decimal(10,2)"
          - "_email$": "string(255)"
          - "_url$": "string(500)"
          - "_code$": "string(50)"
          - "_slug$": "string(255) unique"
          - "_status$": "string(50)"
          - "_state$": "string(50)"
          - ".*": "string"

        # Three interconnected tables with comprehensive pattern usage
        tables:
          leagues:
            columns:
              # id, created_at, updated_at auto-added from defaults
              name: string(255) not_null unique
              abbreviation: string(10)
              description: text
              website_url: ~          # → string(500)
              contact_email: ~        # → string(255)
              is_active: ~            # → boolean default=false not_null
            indexes:
              - name

          users:
            columns:
              # id, created_at, updated_at auto-added from defaults
              email: string(255) not_null unique
              first_name: string(100) not_null
              last_name: string(100) not_null
              league_id: ~            # → integer -> leagues.id on_delete=cascade not_null
              last_login_at: ~        # → datetime not_null
              birth_date: ~           # → date
              is_active: ~            # → boolean default=false not_null
              has_premium: ~          # → boolean default=false not_null
              view_count: ~           # → integer default=0 not_null
              backup_email: ~         # → string(255)
              website_url: ~          # → string(500)
              user_slug: ~            # → string(255) unique
              account_status: ~       # → string(50)
              bio: ~                  # → string (fallback pattern)
            indexes:
              - email
              - league_id
              - user_slug

          posts:
            columns:
              # id, created_at, updated_at auto-added from defaults
              title: string(255) not_null
              user_id: ~              # → integer -> users.id on_delete=cascade not_null
              published_at: ~         # → datetime not_null
              due_on: ~               # → date
              post_content: ~         # → text
              view_count: ~           # → integer default=0 not_null
              rating_score: ~         # → decimal(8,2)
              is_published: ~         # → boolean default=false not_null
              post_slug: ~            # → string(255) unique
              post_status: ~          # → string(50)
            indexes:
              - user_id
              - post_slug
              - is_published
      YAML

      create_test_yaml(comprehensive_schema)
      compiler = Essence::Compiler.new
      compiler.compile!
      hcl_content = read_generated_hcl

      # Verify all three tables are created
      expect(hcl_content).to include('table "leagues"')
      expect(hcl_content).to include('table "users"')
      expect(hcl_content).to include('table "posts"')

      # Verify default columns are applied with patterns to all tables
      expect(hcl_content.scan(/column "id"/).length).to eq(3)
      expect(hcl_content.scan(/auto_increment = true/).length).to eq(3)
      expect(hcl_content.scan(/column "created_at"/).length).to eq(3)
      expect(hcl_content.scan(/column "updated_at"/).length).to eq(3)
      expect(hcl_content.scan(/type = datetime/).length).to be >= 8  # 6 default + published_at + last_login_at

      # Verify foreign key relationships are established correctly
      expect(hcl_content).to include('foreign_key "fk_users_league_id"')
      expect(hcl_content).to include('ref_columns = [table.leagues.column.id]')
      expect(hcl_content).to include('foreign_key "fk_posts_user_id"')
      expect(hcl_content).to include('ref_columns = [table.users.column.id]')
      expect(hcl_content.scan(/on_delete = CASCADE/).length).to eq(2)

      # Verify unique constraints generate unique indexes (bug fix verification)
      expect(hcl_content).to include('index "index_users_on_user_slug_unique"')
      expect(hcl_content).to include('index "index_posts_on_post_slug_unique"')
      expect(hcl_content.scan(/unique = true/).length).to be >= 2

      # Verify explicit indexes are preserved alongside pattern-generated ones
      expect(hcl_content).to include('index "index_users_on_email"')
      expect(hcl_content).to include('index "index_users_on_league_id"')
      expect(hcl_content).to include('index "index_posts_on_user_id"')
      expect(hcl_content).to include('index "index_posts_on_is_published"')
      expect(hcl_content).to include('index "index_leagues_on_name"')

      # Verify comprehensive pattern application across all categories
      
      # Boolean patterns
      expect(hcl_content.scan(/type = boolean/).length).to be >= 4  # is_active(2), has_premium, is_published
      expect(hcl_content.scan(/default = false/).length).to be >= 4
      
      # Text patterns
      expect(hcl_content).to include('column "post_content"')
      expect(hcl_content.scan(/type = text/).length).to be >= 2  # description, post_content
      
      # Numeric patterns
      expect(hcl_content.scan(/column "view_count"/).length).to eq(2)  # users and posts
      expect(hcl_content).to include('column "rating_score"')
      expect(hcl_content.scan(/default = 0/).length).to be >= 2
      expect(hcl_content.scan(/type = decimal\(8,2\)/).length).to be >= 1
      
      # String patterns with different sizes
      expect(hcl_content.scan(/column "backup_email"/).length).to eq(1)
      expect(hcl_content.scan(/column "contact_email"/).length).to eq(1)
      expect(hcl_content.scan(/type = varchar\(255\)/).length).to be >= 6  # emails, slugs
      expect(hcl_content.scan(/column "website_url"/).length).to eq(2)  # leagues and users
      expect(hcl_content.scan(/type = varchar\(500\)/).length).to be >= 2  # website_urls
      expect(hcl_content.scan(/type = varchar\(50\)/).length).to be >= 2   # account_status, post_status
      
      # Date patterns
      expect(hcl_content).to include('column "birth_date"')
      expect(hcl_content).to include('column "due_on"')
      expect(hcl_content.scan(/type = date/).length).to be >= 2
      
      # Fallback pattern
      expect(hcl_content).to include('column "bio"')  # Should use fallback string pattern
    end

    it 'handles complex mixed explicit and pattern definitions correctly' do
      mixed_schema = <<~YAML
        schema_name: public
        
        defaults:
          "*":
            columns:
              id: ~
              created_at: ~
              updated_at: ~
        
        column_patterns:
          - "^id$": "primary_key"
          - "_id$": "integer -> {table}.id on_delete=cascade not_null"
          - "_slug$": "string(255) unique"
          - "_count$": "integer default=0 not_null"
          - ".*": "string"
        
        tables:
          categories:
            columns:
              name: string(255) not_null unique
              parent_id: integer -> categories.id on_delete=set_null  # Override pattern
              
          products:
            columns:
              name: string(255) not_null
              category_id: ~                    # Use pattern: integer -> categories.id
              product_slug: ~                   # Use pattern: string(255) unique
              view_count: ~                     # Use pattern: integer default=0 not_null
              special_count: bigint not_null    # Override pattern
              custom_field: text                # Explicit non-pattern field
      YAML

      create_test_yaml(mixed_schema)
      compiler = Essence::Compiler.new
      compiler.compile!
      hcl_content = read_generated_hcl

      # Verify explicit overrides work correctly
      expect(hcl_content).to include('foreign_key "fk_categories_parent_id"')
      expect(hcl_content).to include('on_delete = SET_NULL')  # Explicit override
      
      # Verify patterns work alongside explicit definitions
      expect(hcl_content).to include('foreign_key "fk_products_category_id"')
      expect(hcl_content).to include('on_delete = CASCADE')   # From pattern
      
      # Verify unique slug pattern generates index
      expect(hcl_content).to include('index "index_products_on_product_slug_unique"')
      expect(hcl_content).to include('unique = true')
      
      # Verify count pattern vs explicit override
      expect(hcl_content).to match(/column "view_count".*?type = integer.*?default = 0/m)
      expect(hcl_content).to match(/column "special_count".*?type = bigint/m)
      expect(hcl_content).not_to match(/column "special_count".*?default = 0/m)
      
      # Verify explicit non-pattern field
      expect(hcl_content).to include('column "custom_field"')
      expect(hcl_content).to match(/column "custom_field".*?type = text/m)
    end

    it 'generates valid HCL syntax for complex schemas' do
      complex_schema = <<~YAML
        schema_name: public
        
        defaults:
          "*":
            columns:
              id: ~
              created_at: ~
              updated_at: ~
        
        column_patterns:
          - "^id$": "primary_key"
          - "_id$": "integer -> {table}.id on_delete=cascade not_null"
          - "_slug$": "string(255) unique"
          - "^is_": "boolean default=false not_null"
          - "_count$": "integer default=0 not_null"
          - "_at$": "datetime not_null"
          - ".*": "string"
        
        tables:
          organizations:
            columns:
              name: string(255) not_null unique
              org_slug: ~
              is_active: ~
            indexes:
              - name
              - org_slug
          
          teams:
            columns:
              name: string(255) not_null
              organization_id: ~
              team_slug: ~
              member_count: ~
              is_public: ~
              created_by_id: integer -> users.id on_delete=set_null
            indexes:
              - organization_id
              - team_slug
              - is_public
          
          users:
            columns:
              email: string(255) not_null unique
              username: string(50) not_null unique
              team_id: ~
              last_seen_at: ~
              login_count: ~
              is_admin: ~
              user_slug: ~
            indexes:
              - email
              - username
              - team_id
              - user_slug
      YAML

      create_test_yaml(complex_schema)
      compiler = Essence::Compiler.new
      compiler.compile!
      hcl_content = read_generated_hcl

      # Verify HCL is syntactically valid (basic structure checks)
      expect(hcl_content).to match(/^schema "public" \{\}/)
      expect(hcl_content.scan(/table "\w+" \{/).length).to eq(3)
      expect(hcl_content.scan(/column "\w+" \{/).length).to be >= 15  # Many columns
      expect(hcl_content.scan(/primary_key \{/).length).to eq(3)
      expect(hcl_content.scan(/foreign_key "\w+" \{/).length).to be >= 3
      expect(hcl_content.scan(/index "\w+" \{/).length).to be >= 10   # Explicit + unique generated
      
      # Verify all closing braces are balanced
      open_braces = hcl_content.scan(/\{/).length
      close_braces = hcl_content.scan(/\}/).length
      expect(open_braces).to eq(close_braces)
      
      # Verify no syntax errors in generated identifiers
      expect(hcl_content).not_to include('""')  # No empty strings
      expect(hcl_content).not_to match(/column "\w+" \{\s*\}/)  # No empty column blocks
      
      # Verify circular foreign key references are handled
      expect(hcl_content).to include('ref_columns = [table.organizations.column.id]')
      expect(hcl_content).to include('ref_columns = [table.teams.column.id]')
      expect(hcl_content).to include('ref_columns = [table.users.column.id]')
    end

    it 'preserves performance with large schemas' do
      # Test that the compiler handles reasonably large schemas efficiently
      large_schema = <<~YAML
        schema_name: public
        
        defaults:
          "*":
            columns:
              id: ~
              created_at: ~
              updated_at: ~
        
        column_patterns:
          - "^id$": "primary_key"
          - "_id$": "integer -> {table}.id on_delete=cascade not_null"
          - "_slug$": "string(255) unique"
          - "^is_": "boolean default=false not_null"
          - "_count$": "integer default=0 not_null"
          - ".*": "string"
        
        tables:
      YAML

      # Generate 10 tables with multiple relationships
      10.times do |i|
        table_name = "table_#{i}"
        large_schema += "          #{table_name}:\n"
        large_schema += "            columns:\n"
        large_schema += "              name: string(255) not_null\n"
        large_schema += "              #{table_name}_slug: ~\n"
        large_schema += "              is_active_#{i}: ~\n"
        large_schema += "              record_count_#{i}: ~\n"
        
        # Add some cross-references
        if i > 0
          large_schema += "              ref_id_#{i}: integer -> table_#{i-1}.id on_delete=cascade not_null\n"
        end
        
        large_schema += "            indexes:\n"
        large_schema += "              - #{table_name}_slug\n"
        large_schema += "              - is_active_#{i}\n"
      end

      create_test_yaml(large_schema)
      
      # Measure compilation time
      start_time = Time.now
      compiler = Essence::Compiler.new
      compiler.compile!
      end_time = Time.now
      
      compilation_time = end_time - start_time
      
      # Should compile reasonably quickly (under 1 second for 10 tables)
      expect(compilation_time).to be < 1.0
      
      hcl_content = read_generated_hcl
      
      # Verify all tables were generated
      expect(hcl_content.scan(/table "table_\d+"/).length).to eq(10)
      
      # Verify relationships were established
      expect(hcl_content.scan(/foreign_key/).length).to be >= 9  # 9 cross-references
      
      # Verify unique indexes were generated for all slugs
      expect(hcl_content.scan(/unique = true/).length).to be >= 10
    end
  end
end
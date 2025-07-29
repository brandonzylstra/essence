# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Pattern Verification' do
  describe 'comprehensive pattern testing' do
    it 'applies all documented patterns correctly' do
      schema_yaml = <<~YAML
        schema_name: public

        defaults:
          "*":
            columns:
              id: ~           # Should become: primary_key
              created_at: ~   # Should become: datetime not_null
              updated_at: ~   # Should become: datetime not_null

        column_patterns:
          - "^id$": "primary_key"
          - "_id$": "integer -> {table}.id on_delete=cascade not_null"
          - "_at$": "datetime not_null"
          - "_on$": "date not_null"
          - "_date$": "date not_null"
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

        tables:
          users:
            columns:
              email: string(255) not_null unique
              company_id: ~

          posts:
            columns:
              title: string(255) not_null
              user_id: ~

              # Test timestamp patterns
              published_at: ~
              scheduled_at: ~

              # Test date patterns
              published_on: ~
              birth_date: ~

              # Test boolean patterns
              is_active: ~
              is_published: ~
              has_comments: ~
              can_edit: ~
              admin_flag: ~

              # Test text patterns
              post_content: ~
              email_body: ~
              bio_text: ~
              content_html: ~

              # Test numeric patterns
              view_count: ~
              rating_score: ~
              total_amount: ~
              unit_price: ~

              # Test string patterns
              contact_email: ~
              website_url: ~
              product_code: ~
              post_slug: ~
              order_status: ~
              workflow_state: ~

          companies:
            columns:
              name: string(255) not_null unique
      YAML

      create_test_yaml(schema_yaml)
      compiler = Essence::Compiler.new
      compiler.compile!
      hcl_content = read_generated_hcl

      # Test default columns with patterns
      expect(hcl_content).to include('column "id" {')
      expect(hcl_content).to include('auto_increment = true')
      expect(hcl_content).to include('column "created_at" {')
      expect(hcl_content).to include('column "updated_at" {')
      expect(hcl_content.scan(/type = datetime/).length).to be >= 4  # created_at, updated_at, published_at, scheduled_at

      # Test foreign key patterns
      expect(hcl_content).to include('foreign_key "fk_users_company_id"')
      expect(hcl_content).to include('foreign_key "fk_posts_user_id"')
      expect(hcl_content).to include('ref_columns = [table.companies.column.id]')
      expect(hcl_content).to include('ref_columns = [table.users.column.id]')
      expect(hcl_content).to include('on_delete = CASCADE')

      # Test timestamp patterns (_at$)
      expect(hcl_content.scan(/column "published_at"/).length).to eq(1)
      expect(hcl_content.scan(/column "scheduled_at"/).length).to eq(1)

      # Test date patterns (_on$, _date$)
      expect(hcl_content.scan(/column "published_on"/).length).to eq(1)
      expect(hcl_content.scan(/column "birth_date"/).length).to eq(1)
      expect(hcl_content.scan(/type = date/).length).to be >= 2

      # Test boolean patterns
      expect(hcl_content.scan(/column "is_active"/).length).to eq(1)
      expect(hcl_content.scan(/column "is_published"/).length).to eq(1)
      expect(hcl_content.scan(/column "has_comments"/).length).to eq(1)
      expect(hcl_content.scan(/column "can_edit"/).length).to eq(1)
      expect(hcl_content.scan(/column "admin_flag"/).length).to eq(1)
      expect(hcl_content.scan(/type = boolean/).length).to be >= 5
      expect(hcl_content.scan(/default = false/).length).to be >= 5

      # Test text patterns
      expect(hcl_content.scan(/column "post_content"/).length).to eq(1)
      expect(hcl_content.scan(/column "email_body"/).length).to eq(1)
      expect(hcl_content.scan(/column "bio_text"/).length).to eq(1)
      expect(hcl_content.scan(/column "content_html"/).length).to eq(1)
      expect(hcl_content.scan(/type = text/).length).to be >= 4

      # Test numeric patterns
      expect(hcl_content.scan(/column "view_count"/).length).to eq(1)
      expect(hcl_content.scan(/column "rating_score"/).length).to eq(1)
      expect(hcl_content.scan(/column "total_amount"/).length).to eq(1)
      expect(hcl_content.scan(/column "unit_price"/).length).to eq(1)
      expect(hcl_content.scan(/default = 0/).length).to be >= 1  # view_count
      expect(hcl_content.scan(/type = decimal\(8,2\)/).length).to be >= 1  # rating_score
      expect(hcl_content.scan(/type = decimal\(10,2\)/).length).to be >= 2  # total_amount, unit_price

      # Test string patterns
      expect(hcl_content.scan(/column "contact_email"/).length).to eq(1)
      expect(hcl_content.scan(/column "website_url"/).length).to eq(1)
      expect(hcl_content.scan(/column "product_code"/).length).to eq(1)
      expect(hcl_content.scan(/column "post_slug"/).length).to eq(1)
      expect(hcl_content.scan(/column "order_status"/).length).to eq(1)
      expect(hcl_content.scan(/column "workflow_state"/).length).to eq(1)
      expect(hcl_content.scan(/type = varchar\(255\)/).length).to be >= 2  # contact_email, post_slug
      expect(hcl_content.scan(/type = varchar\(500\)/).length).to be >= 1  # website_url
      expect(hcl_content.scan(/type = varchar\(50\)/).length).to be >= 3   # product_code, order_status, workflow_state
    end

    it 'generates unique indexes for slug patterns' do
      schema_yaml = <<~YAML
        schema_name: public

        column_patterns:
          - "_slug$": "string(255) unique"
          - ".*": "string"

        tables:
          posts:
            columns:
              id: primary_key
              title: string(255) not_null
              post_slug: ~
              category_slug: ~
      YAML

      create_test_yaml(schema_yaml)
      compiler = Essence::Compiler.new
      compiler.compile!
      hcl_content = read_generated_hcl

      # Verify slug columns are created
      expect(hcl_content).to include('column "post_slug"')
      expect(hcl_content).to include('column "category_slug"')
      expect(hcl_content).to include('type = varchar(255)')

      # CRITICAL TEST: Verify unique indexes are generated for slug columns
      # This test will fail with the current bug and should be fixed
      expect(hcl_content).to include('index "index_posts_on_post_slug_unique"')
      expect(hcl_content).to include('index "index_posts_on_category_slug_unique"')
      expect(hcl_content).to include('unique = true')
    end

    it 'applies patterns to default columns with ~ shorthand' do
      schema_yaml = <<~YAML
        schema_name: public

        defaults:
          "*":
            columns:
              id: ~
              created_at: ~
              updated_at: ~
              tenant_id: ~

        column_patterns:
          - "^id$": "primary_key"
          - "_at$": "datetime not_null"
          - "_id$": "integer -> {table}.id on_delete=cascade not_null"
          - ".*": "string"

        tables:
          users:
            columns:
              email: string(255) not_null unique

          tenants:
            columns:
              name: string(255) not_null unique
      YAML

      create_test_yaml(schema_yaml)
      compiler = Essence::Compiler.new
      compiler.compile!
      hcl_content = read_generated_hcl

      # Verify default patterns are applied correctly
      expect(hcl_content.scan(/column "id"/).length).to eq(2)  # users and tenants
      expect(hcl_content.scan(/auto_increment = true/).length).to eq(2)
      expect(hcl_content.scan(/column "created_at"/).length).to eq(2)
      expect(hcl_content.scan(/column "updated_at"/).length).to eq(2)
      expect(hcl_content.scan(/type = datetime/).length).to eq(4)  # 2 created_at + 2 updated_at

      # Verify tenant_id foreign key is created correctly in users table
      expect(hcl_content).to include('column "tenant_id"')
      expect(hcl_content).to include('foreign_key "fk_users_tenant_id"')
      expect(hcl_content).to include('ref_columns = [table.tenants.column.id]')
    end

    it 'handles pattern priority correctly' do
      schema_yaml = <<~YAML
        schema_name: public

        column_patterns:
          - "_email$": "string(255)"
          - "contact_": "string(100)"
          - ".*": "string"

        tables:
          users:
            columns:
              id: primary_key
              contact_email: ~  # Should match _email$ pattern, not contact_ pattern
              contact_name: ~   # Should match contact_ pattern
              other_field: ~    # Should match .* pattern
      YAML

      create_test_yaml(schema_yaml)
      compiler = Essence::Compiler.new
      compiler.compile!
      hcl_content = read_generated_hcl

      # contact_email should use _email$ pattern (string(255))
      expect(hcl_content).to include('column "contact_email"')
      expect(hcl_content).to match(/column "contact_email".*?type = varchar\(255\)/m)

      # contact_name should use contact_ pattern (string(100))
      expect(hcl_content).to include('column "contact_name"')
      expect(hcl_content).to match(/column "contact_name".*?type = varchar\(100\)/m)

      # other_field should use .* pattern (string - defaults to appropriate size)
      expect(hcl_content).to include('column "other_field"')
    end

    it 'allows explicit definitions to override patterns' do
      schema_yaml = <<~YAML
        schema_name: public

        column_patterns:
          - "_id$": "integer -> {table}.id on_delete=cascade not_null"
          - "_count$": "integer default=0 not_null"
          - ".*": "string"

        tables:
          posts:
            columns:
              id: primary_key
              user_id: bigint -> users.id on_delete=set_null  # Override pattern
              view_count: ~                                   # Use pattern
              special_count: bigint not_null                  # Override pattern

          users:
            columns:
              id: primary_key
              name: string(255) not_null
      YAML

      create_test_yaml(schema_yaml)
      compiler = Essence::Compiler.new
      compiler.compile!
      hcl_content = read_generated_hcl

      # user_id should use explicit definition (bigint, SET_NULL)
      expect(hcl_content).to include('type = bigint')
      expect(hcl_content).to include('on_delete = SET_NULL')

      # view_count should use pattern (integer, default=0)
      expect(hcl_content).to match(/column "view_count".*?type = integer.*?default = 0/m)

      # special_count should use explicit definition (bigint, no default)
      expect(hcl_content).to match(/column "special_count".*?type = bigint/m)
      expect(hcl_content).not_to match(/column "special_count".*?default = 0/m)
    end
  end
end

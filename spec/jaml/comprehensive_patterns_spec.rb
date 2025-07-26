# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'JAML Comprehensive Pattern Matching' do
  describe 'Foreign Key Patterns' do
    it 'generates foreign keys for _id columns' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "_id$"
            template: "integer -> {table}.id on_delete=cascade not_null"
        tables:
          posts:
            columns:
              id: primary_key
              user_id: ~
              category_id: ~
              author_id: ~
      YAML
      
      create_test_yaml(schema_content)
      
      converter = JAML::Converter.new
      converter.convert!
      
      hcl_content = read_generated_hcl
      
      expect(hcl_content).to include('foreign_key "fk_posts_user_id"')
      expect(hcl_content).to include('ref_columns = [table.users.column.id]')
      expect(hcl_content).to include('foreign_key "fk_posts_category_id"')
      expect(hcl_content).to include('ref_columns = [table.categories.column.id]')
      expect(hcl_content).to include('foreign_key "fk_posts_author_id"')
      expect(hcl_content).to include('ref_columns = [table.authors.column.id]')
      expect(hcl_content).to include('on_delete = CASCADE')
    end
  end

  describe 'Date and Time Patterns' do
    it 'applies _at pattern for datetime columns' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "_at$"
            attributes: "datetime not_null"
        tables:
          events:
            columns:
              id: primary_key
              published_at: ~
              deleted_at: ~
              archived_at: ~
              scheduled_at: ~
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      converter.convert!
      hcl_content = read_generated_hcl
      
      %w[published_at deleted_at archived_at scheduled_at].each do |col|
        expect(hcl_content).to include("column \"#{col}\"")
        column_section = hcl_content[/column "#{col}".*?}/m]
        expect(column_section).to include('type = datetime')
        expect(column_section).to include('null = false')
      end
    end

    it 'applies _on pattern for date columns' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "_on$"
            attributes: "date"
        tables:
          tasks:
            columns:
              id: primary_key
              due_on: ~
              completed_on: ~
              started_on: ~
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      converter.convert!
      hcl_content = read_generated_hcl
      
      %w[due_on completed_on started_on].each do |col|
        column_section = hcl_content[/column "#{col}".*?}/m]
        expect(column_section).to include('type = date')
      end
    end

    it 'applies _date pattern for date columns' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "_date$"
            attributes: "date"
        tables:
          people:
            columns:
              id: primary_key
              birth_date: ~
              hire_date: ~
              expiry_date: ~
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      converter.convert!
      hcl_content = read_generated_hcl
      
      %w[birth_date hire_date expiry_date].each do |col|
        column_section = hcl_content[/column "#{col}".*?}/m]
        expect(column_section).to include('type = date')
      end
    end
  end

  describe 'Boolean Patterns' do
    it 'applies is_ pattern for boolean columns' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "^is_"
            attributes: "boolean default=false not_null"
        tables:
          users:
            columns:
              id: primary_key
              is_active: ~
              is_verified: ~
              is_admin: ~
              is_public: ~
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      converter.convert!
      hcl_content = read_generated_hcl
      
      %w[is_active is_verified is_admin is_public].each do |col|
        column_section = hcl_content[/column "#{col}".*?}/m]
        expect(column_section).to include('type = boolean')
        expect(column_section).to include('default = false')
        expect(column_section).to include('null = false')
      end
    end

    it 'applies has_ pattern for boolean columns' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "^has_"
            attributes: "boolean default=false not_null"
        tables:
          users:
            columns:
              id: primary_key
              has_premium: ~
              has_avatar: ~
              has_newsletter: ~
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      converter.convert!
      hcl_content = read_generated_hcl
      
      %w[has_premium has_avatar has_newsletter].each do |col|
        column_section = hcl_content[/column "#{col}".*?}/m]
        expect(column_section).to include('type = boolean')
        expect(column_section).to include('default = false')
      end
    end

    it 'applies can_ pattern for boolean columns' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "^can_"
            attributes: "boolean default=false not_null"
        tables:
          users:
            columns:
              id: primary_key
              can_edit: ~
              can_delete: ~
              can_moderate: ~
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      converter.convert!
      hcl_content = read_generated_hcl
      
      %w[can_edit can_delete can_moderate].each do |col|
        column_section = hcl_content[/column "#{col}".*?}/m]
        expect(column_section).to include('type = boolean')
        expect(column_section).to include('default = false')
      end
    end

    it 'applies _flag pattern for boolean columns' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "_flag$"
            attributes: "boolean default=false not_null"
        tables:
          records:
            columns:
              id: primary_key
              admin_flag: ~
              verified_flag: ~
              archived_flag: ~
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      converter.convert!
      hcl_content = read_generated_hcl
      
      %w[admin_flag verified_flag archived_flag].each do |col|
        column_section = hcl_content[/column "#{col}".*?}/m]
        expect(column_section).to include('type = boolean')
        expect(column_section).to include('default = false')
      end
    end
  end

  describe 'Text Content Patterns' do
    it 'applies _content pattern for text columns' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "_content$"
            attributes: "text"
        tables:
          posts:
            columns:
              id: primary_key
              post_content: ~
              message_content: ~
              email_content: ~
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      converter.convert!
      hcl_content = read_generated_hcl
      
      %w[post_content message_content email_content].each do |col|
        column_section = hcl_content[/column "#{col}".*?}/m]
        expect(column_section).to include('type = text')
      end
    end

    it 'applies _body pattern for text columns' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "_body$"
            attributes: "text"
        tables:
          emails:
            columns:
              id: primary_key
              email_body: ~
              article_body: ~
              response_body: ~
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      converter.convert!
      hcl_content = read_generated_hcl
      
      %w[email_body article_body response_body].each do |col|
        column_section = hcl_content[/column "#{col}".*?}/m]
        expect(column_section).to include('type = text')
      end
    end

    it 'applies _text pattern for text columns' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "_text$"
            attributes: "text"
        tables:
          profiles:
            columns:
              id: primary_key
              bio_text: ~
              description_text: ~
              notes_text: ~
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      converter.convert!
      hcl_content = read_generated_hcl
      
      %w[bio_text description_text notes_text].each do |col|
        column_section = hcl_content[/column "#{col}".*?}/m]
        expect(column_section).to include('type = text')
      end
    end

    it 'applies _html pattern for text columns' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "_html$"
            attributes: "text"
        tables:
          pages:
            columns:
              id: primary_key
              content_html: ~
              formatted_html: ~
              raw_html: ~
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      converter.convert!
      hcl_content = read_generated_hcl
      
      %w[content_html formatted_html raw_html].each do |col|
        column_section = hcl_content[/column "#{col}".*?}/m]
        expect(column_section).to include('type = text')
      end
    end
  end

  describe 'Numeric Patterns' do
    it 'applies _count pattern for integer columns with default 0' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "_count$"
            attributes: "integer default=0 not_null"
        tables:
          analytics:
            columns:
              id: primary_key
              view_count: ~
              like_count: ~
              download_count: ~
              share_count: ~
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      converter.convert!
      hcl_content = read_generated_hcl
      
      %w[view_count like_count download_count share_count].each do |col|
        column_section = hcl_content[/column "#{col}".*?}/m]
        expect(column_section).to include('type = integer')
        expect(column_section).to include('default = 0')
        expect(column_section).to include('null = false')
      end
    end

    it 'applies _score pattern for decimal columns' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "_score$"
            attributes: "decimal(8,2)"
        tables:
          evaluations:
            columns:
              id: primary_key
              rating_score: ~
              test_score: ~
              credit_score: ~
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      converter.convert!
      hcl_content = read_generated_hcl
      
      %w[rating_score test_score credit_score].each do |col|
        column_section = hcl_content[/column "#{col}".*?}/m]
        expect(column_section).to include('type = decimal(8,2)')
      end
    end

    it 'applies _amount pattern for decimal columns' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "_amount$"
            attributes: "decimal(10,2)"
        tables:
          transactions:
            columns:
              id: primary_key
              total_amount: ~
              fee_amount: ~
              discount_amount: ~
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      converter.convert!
      hcl_content = read_generated_hcl
      
      %w[total_amount fee_amount discount_amount].each do |col|
        column_section = hcl_content[/column "#{col}".*?}/m]
        expect(column_section).to include('type = decimal(10,2)')
      end
    end

    it 'applies _price pattern for decimal columns' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "_price$"
            attributes: "decimal(10,2)"
        tables:
          products:
            columns:
              id: primary_key
              unit_price: ~
              sale_price: ~
              list_price: ~
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      converter.convert!
      hcl_content = read_generated_hcl
      
      %w[unit_price sale_price list_price].each do |col|
        column_section = hcl_content[/column "#{col}".*?}/m]
        expect(column_section).to include('type = decimal(10,2)')
      end
    end
  end

  describe 'String Patterns' do
    it 'applies _email pattern for string(255) columns' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "_email$"
            attributes: "string(255)"
        tables:
          contacts:
            columns:
              id: primary_key
              contact_email: ~
              backup_email: ~
              notification_email: ~
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      converter.convert!
      hcl_content = read_generated_hcl
      
      %w[contact_email backup_email notification_email].each do |col|
        column_section = hcl_content[/column "#{col}".*?}/m]
        expect(column_section).to include('type = varchar(255)')
      end
    end

    it 'applies _url pattern for string(500) columns' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "_url$"
            attributes: "string(500)"
        tables:
          links:
            columns:
              id: primary_key
              website_url: ~
              avatar_url: ~
              callback_url: ~
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      converter.convert!
      hcl_content = read_generated_hcl
      
      %w[website_url avatar_url callback_url].each do |col|
        column_section = hcl_content[/column "#{col}".*?}/m]
        expect(column_section).to include('type = varchar(500)')
      end
    end

    it 'applies _code pattern for string(50) columns' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "_code$"
            attributes: "string(50)"
        tables:
          items:
            columns:
              id: primary_key
              product_code: ~
              access_code: ~
              coupon_code: ~
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      converter.convert!
      hcl_content = read_generated_hcl
      
      %w[product_code access_code coupon_code].each do |col|
        column_section = hcl_content[/column "#{col}".*?}/m]
        expect(column_section).to include('type = varchar(50)')
      end
    end

    it 'applies _slug pattern for unique string columns' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "_slug$"
            attributes: "string(255) unique"
        tables:
          content:
            columns:
              id: primary_key
              post_slug: ~
              category_slug: ~
              user_slug: ~
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      converter.convert!
      hcl_content = read_generated_hcl
      
      %w[post_slug category_slug user_slug].each do |col|
        column_section = hcl_content[/column "#{col}".*?}/m]
        expect(column_section).to include('type = varchar(255)')
        # Note: unique constraint would be implemented as an index, not column property
      end
    end
  end

  describe 'Status and State Patterns' do
    it 'applies _status pattern for status columns with pending default' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "_status$"
            attributes: "string(20) default='pending' not_null"
        tables:
          workflows:
            columns:
              id: primary_key
              order_status: ~
              job_status: ~
              payment_status: ~
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      converter.convert!
      hcl_content = read_generated_hcl
      
      %w[order_status job_status payment_status].each do |col|
        column_section = hcl_content[/column "#{col}".*?}/m]
        expect(column_section).to include('type = varchar(20)')
        expect(column_section).to include("default = \"pending\"")
        expect(column_section).to include('null = false')
      end
    end

    it 'applies _state pattern for state columns' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "_state$"
            attributes: "string(20)"
        tables:
          machines:
            columns:
              id: primary_key
              workflow_state: ~
              approval_state: ~
              current_state: ~
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      converter.convert!
      hcl_content = read_generated_hcl
      
      %w[workflow_state approval_state current_state].each do |col|
        column_section = hcl_content[/column "#{col}".*?}/m]
        expect(column_section).to include('type = varchar(20)')
      end
    end
  end

  describe 'Pattern Priority and Conflicts' do
    it 'applies patterns in order of specificity' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "_email$"
            attributes: "string(255)"
          - pattern: "contact_.*"
            attributes: "string(100)"
          - pattern: ".*"
            attributes: "string"
        tables:
          users:
            columns:
              id: primary_key
              contact_email: ~  # Should match _email$ first
              contact_name: ~   # Should match contact_.* 
              bio: ~            # Should match .* fallback
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      converter.convert!
      hcl_content = read_generated_hcl
      
      # contact_email should match _email$ pattern first
      contact_email_section = hcl_content[/column "contact_email".*?}/m]
      expect(contact_email_section).to include('type = varchar(255)')
      
      # contact_name should match contact_.* pattern
      contact_name_section = hcl_content[/column "contact_name".*?}/m]
      expect(contact_name_section).to include('type = varchar(100)')
      
      # bio should match .* fallback
      bio_section = hcl_content[/column "bio".*?}/m]
      expect(bio_section).to include('type = varchar')
    end

    it 'allows explicit definitions to override patterns' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "_id$"
            template: "integer -> {table}.id on_delete=cascade not_null"
          - pattern: "_count$"
            attributes: "integer default=0 not_null"
        tables:
          posts:
            columns:
              id: primary_key
              user_id: bigint -> users.id on_delete=set_null  # Override pattern
              view_count: ~                                    # Use pattern
              special_count: decimal(10,2)                     # Override pattern
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      converter.convert!
      hcl_content = read_generated_hcl
      
      # user_id should use explicit definition
      user_id_section = hcl_content[/column "user_id".*?}/m]
      expect(user_id_section).to include('type = bigint')
      expect(hcl_content).to include('on_delete = SET_NULL')
      
      # view_count should use pattern
      view_count_section = hcl_content[/column "view_count".*?}/m]
      expect(view_count_section).to include('type = integer')
      expect(view_count_section).to include('default = 0')
      
      # special_count should use explicit definition
      special_count_section = hcl_content[/column "special_count".*?}/m]
      expect(special_count_section).to include('type = decimal(10,2)')
    end
  end

  describe 'Real-world Complex Schema' do
    it 'handles a complex schema with mixed patterns' do
      schema_content = <<~YAML
        schema_name: main
        defaults:
          "*":
            columns:
              id: primary_key
              created_at: datetime not_null
              updated_at: datetime not_null
        column_patterns:
          - pattern: "_id$"
            template: "integer -> {table}.id on_delete=cascade not_null"
          - pattern: "_at$"
            attributes: "datetime not_null"
          - pattern: "_on$"
            attributes: "date"
          - pattern: "^is_"
            attributes: "boolean default=false not_null"
          - pattern: "_count$"
            attributes: "integer default=0 not_null"
          - pattern: "_email$"
            attributes: "string(255)"
          - pattern: "_url$"
            attributes: "string(500)"
          - pattern: "_status$"
            attributes: "string(20) default='pending' not_null"
          - pattern: ".*"
            attributes: "string"
        tables:
          users:
            columns:
              email: string(255) not_null unique
              first_name: string(100) not_null
              last_name: string(100) not_null
              company_id: ~
              last_login_at: ~
              birth_date: date
              is_active: ~
              is_verified: ~
              profile_url: ~
              backup_email: ~
              login_count: ~
              account_status: ~
              bio: ~
            indexes:
              - email
              - company_id
              - is_active
          posts:
            columns:
              title: string(255) not_null
              user_id: ~
              category_id: ~
              published_at: ~
              due_on: ~
              is_featured: ~
              view_count: ~
              post_status: ~
              slug: string(255) unique
            indexes:
              - user_id
              - category_id
              - is_featured
              - slug
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      converter.convert!
      hcl_content = read_generated_hcl
      
      # Verify defaults are applied
      expect(hcl_content).to include('column "id"')
      expect(hcl_content).to include('column "created_at"')
      expect(hcl_content).to include('column "updated_at"')
      
      # Verify foreign keys
      expect(hcl_content).to include('foreign_key "fk_users_company_id"')
      expect(hcl_content).to include('foreign_key "fk_posts_user_id"')
      expect(hcl_content).to include('foreign_key "fk_posts_category_id"')
      
      # Verify pattern applications
      expect(hcl_content).to include('ref_columns = [table.companies.column.id]')
      
      last_login_at_section = hcl_content[/column "last_login_at".*?}/m]
      expect(last_login_at_section).to include('type = datetime')
      
      is_active_section = hcl_content[/column "is_active".*?}/m]
      expect(is_active_section).to include('type = boolean')
      expect(is_active_section).to include('default = false')
      
      profile_url_section = hcl_content[/column "profile_url".*?}/m]
      expect(profile_url_section).to include('type = varchar(500)')
      
      backup_email_section = hcl_content[/column "backup_email".*?}/m]
      expect(backup_email_section).to include('type = varchar(255)')
      
      login_count_section = hcl_content[/column "login_count".*?}/m]
      expect(login_count_section).to include('type = integer')
      expect(login_count_section).to include('default = 0')
      
      account_status_section = hcl_content[/column "account_status".*?}/m]
      expect(account_status_section).to include('type = varchar(20)')
      expect(account_status_section).to include('default = "pending"')
      
      # Verify indexes
      expect(hcl_content).to include('index "index_users_on_email"')
      expect(hcl_content).to include('index "index_users_on_company_id"')
      expect(hcl_content).to include('index "index_posts_on_slug"')
    end
  end

  describe 'Edge Cases and Error Handling' do
    it 'handles columns with multiple pattern matches gracefully' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "_email_.*"
            attributes: "string(100)"
          - pattern: ".*_email$"
            attributes: "string(255)"
          - pattern: ".*"
            attributes: "string"
        tables:
          contacts:
            columns:
              id: primary_key
              contact_email: ~  # Should match first pattern that matches
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      converter.convert!
      hcl_content = read_generated_hcl
      
      # Should use the first matching pattern
      contact_email_section = hcl_content[/column "contact_email".*?}/m]
      expect(contact_email_section).to include('type = varchar(255)')
    end

    it 'handles empty pattern lists gracefully' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns: []
        tables:
          simple:
            columns:
              id: primary_key
              name: ~
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      converter.convert!
      hcl_content = read_generated_hcl
      
      # Should use built-in default patterns
      expect(hcl_content).to include('column "name"')
    end

    it 'handles malformed pattern configurations gracefully' do
      schema_content = <<~YAML
        schema_name: main
        column_patterns:
          - pattern: "_id$"
            # Missing template/attributes should not crash
          - pattern: "invalid[regex"
            attributes: "string"
        tables:
          test:
            columns:
              id: primary_key
              user_id: ~
              name: ~
      YAML
      
      create_test_yaml(schema_content)
      converter = JAML::Converter.new
      
      # Should not crash, may use fallback patterns
      expect { converter.convert! }.not_to raise_error
    end
  end
end
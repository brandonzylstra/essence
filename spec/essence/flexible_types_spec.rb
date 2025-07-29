# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Essence::Compiler, '#flexible_types' do
  describe 'RAILS_TYPE_MAPPING' do
    it 'includes all expected Rails type mappings' do
      expected_mappings = {
        "bigint" => "bigint",
        "float" => "float",
        "timestamp" => "datetime",
        "time" => "time"
      }

      expect(described_class::RAILS_TYPE_MAPPING).to include(expected_mappings)
    end
  end

  describe '#convert_type_to_hcl' do
    let(:compiler) { described_class.new }

    context 'with Essence native types' do
      it 'converts string types correctly' do
        expect(compiler.send(:convert_type_to_hcl, 'string', nil)).to eq('varchar')
        expect(compiler.send(:convert_type_to_hcl, 'string', '255')).to eq('varchar(255)')
      end

      it 'converts integer types correctly' do
        expect(compiler.send(:convert_type_to_hcl, 'integer', nil)).to eq('integer')
      end

      it 'converts boolean types correctly' do
        expect(compiler.send(:convert_type_to_hcl, 'boolean', nil)).to eq('boolean')
      end

      it 'converts datetime types correctly' do
        expect(compiler.send(:convert_type_to_hcl, 'datetime', nil)).to eq('datetime')
      end

      it 'converts text types correctly' do
        expect(compiler.send(:convert_type_to_hcl, 'text', nil)).to eq('text')
      end

      it 'converts decimal types correctly' do
        expect(compiler.send(:convert_type_to_hcl, 'decimal', nil)).to eq('decimal')
        expect(compiler.send(:convert_type_to_hcl, 'decimal', '10,2')).to eq('decimal(10,2)')
      end
    end

    context 'with Rails migration types' do
      it 'converts :bigint to bigint HCL type' do
        expect(compiler.send(:convert_type_to_hcl, 'bigint', nil)).to eq('bigint')
      end

      it 'converts :float to float HCL type' do
        expect(compiler.send(:convert_type_to_hcl, 'float', nil)).to eq('float')
      end

      it 'converts :timestamp to datetime HCL type' do
        expect(compiler.send(:convert_type_to_hcl, 'timestamp', nil)).to eq('datetime')
      end

      it 'converts :time to time HCL type' do
        expect(compiler.send(:convert_type_to_hcl, 'time', nil)).to eq('time')
      end

      it 'handles Rails types that map to existing Essence types' do
        # These should work the same as Essence types
        expect(compiler.send(:convert_type_to_hcl, 'string', '100')).to eq('varchar(100)')
        expect(compiler.send(:convert_type_to_hcl, 'integer', nil)).to eq('integer')
        expect(compiler.send(:convert_type_to_hcl, 'boolean', nil)).to eq('boolean')
      end
    end

    context 'with unknown types' do
      it 'returns the type as-is for unknown types' do
        expect(compiler.send(:convert_type_to_hcl, 'unknown_type', nil)).to eq('unknown_type')
        expect(compiler.send(:convert_type_to_hcl, 'custom_type', nil)).to eq('custom_type')
      end
    end
  end

  describe 'full schema compilation with mixed types' do
    it 'successfully compiles schemas with mixed type syntax' do
      schema_yaml = <<~YAML
        schema_name: public
        tables:
          users:
            columns:
              id: primary_key
              name: string(100) not_null
              email: string not_null unique
              age: integer
              bio: text
              salary: decimal(10,2)
              is_active: boolean default=true
              created_at: datetime not_null
              updated_at: timestamp not_null
          posts:
            columns:
              id: primary_key
              title: string(255) not_null
              content: text
              user_id: integer -> users.id on_delete=cascade not_null
              view_count: bigint default=0
              rating: float
              published_at: timestamp
              reminder_time: time
      YAML

      create_test_yaml(schema_yaml)
      compiler = described_class.new

      expect { compiler.compile! }.not_to raise_error
    end

    it 'generates correct HCL for Rails timestamp type' do
      schema_yaml = <<~YAML
        schema_name: public
        tables:
          posts:
            columns:
              id: primary_key
              updated_at: timestamp not_null
              published_at: timestamp
      YAML

      create_test_yaml(schema_yaml)
      compiler = described_class.new
      compiler.compile!

      hcl_content = read_generated_hcl
      # timestamp should be converted to datetime in HCL
      expect(hcl_content).to include('type = datetime')
    end

    it 'generates correct HCL for Rails bigint type' do
      schema_yaml = <<~YAML
        schema_name: public
        tables:
          analytics:
            columns:
              id: primary_key
              view_count: bigint default=0
      YAML

      create_test_yaml(schema_yaml)
      compiler = described_class.new
      compiler.compile!

      hcl_content = read_generated_hcl
      expect(hcl_content).to include('type = bigint')
    end

    it 'generates correct HCL for Rails float type' do
      schema_yaml = <<~YAML
        schema_name: public
        tables:
          products:
            columns:
              id: primary_key
              rating: float
      YAML

      create_test_yaml(schema_yaml)
      compiler = described_class.new
      compiler.compile!

      hcl_content = read_generated_hcl
      expect(hcl_content).to include('type = float')
    end

    it 'generates correct HCL for Rails time type' do
      schema_yaml = <<~YAML
        schema_name: public
        tables:
          events:
            columns:
              id: primary_key
              reminder_time: time
      YAML

      create_test_yaml(schema_yaml)
      compiler = described_class.new
      compiler.compile!

      hcl_content = read_generated_hcl
      expect(hcl_content).to include('type = time')
    end
  end

  describe 'pattern matching with Rails types' do
    it 'applies patterns correctly regardless of other column syntax' do
      schema_yaml = <<~YAML
        schema_name: public
        column_patterns:
          - "_id$": "integer -> {table}.id on_delete=cascade not_null"
          - "_at$": "datetime not_null"
          - "is_*": "boolean default=false not_null"
        tables:
          comments:
            columns:
              id: primary_key
              content: text
              post_id: ~
              created_at: ~
              is_approved: ~
      YAML

      create_test_yaml(schema_yaml)
      compiler = described_class.new
      compiler.compile!

      hcl_content = read_generated_hcl

      # Should have foreign key for post_id
      expect(hcl_content).to include('ref_columns = [table.posts.column.id]')

      # Should have datetime for created_at
      expect(hcl_content).to include('type = datetime')

      # Should have boolean for is_approved
      expect(hcl_content).to include('type = boolean')
    end
  end

  describe 'backwards compatibility' do
    it 'compiles existing Essence schemas without any changes' do
      create_basic_schema

      compiler = described_class.new
      expect { compiler.compile! }.not_to raise_error

      hcl_content = read_generated_hcl

      # Should generate valid HCL with expected types
      expect(hcl_content).to include('type = varchar(255)')
      expect(hcl_content).to include('type = varchar(100)')
      expect(hcl_content).to include('type = integer')
      expect(hcl_content).to include('type = text')
      expect(hcl_content).to include('type = datetime')
    end
  end

  describe 'error handling' do
    let(:compiler) { described_class.new }

    context 'with nil types' do
      it 'handles nil type gracefully' do
        expect(compiler.send(:convert_type_to_hcl, nil, nil)).to be_nil
      end
    end

    context 'with empty string types' do
      it 'handles empty string type' do
        expect(compiler.send(:convert_type_to_hcl, '', nil)).to eq('')
      end
    end
  end

  describe 'integration with parse_simple_column_def' do
    let(:compiler) { described_class.new }

    context 'with Rails-style type definitions' do
      it 'parses Rails timestamp type correctly' do
        result = compiler.send(:parse_simple_column_def, 'timestamp not_null')

        expect(result[:type]).to eq('timestamp')
        expect(result[:hcl_type]).to eq('datetime')  # Should be mapped
        expect(result[:not_null]).to be true
      end

      it 'parses Rails bigint type correctly' do
        result = compiler.send(:parse_simple_column_def, 'bigint not_null')

        expect(result[:type]).to eq('bigint')
        expect(result[:hcl_type]).to eq('bigint')
        expect(result[:not_null]).to be true
      end

      it 'parses Rails float type correctly' do
        result = compiler.send(:parse_simple_column_def, 'float')

        expect(result[:type]).to eq('float')
        expect(result[:hcl_type]).to eq('float')
      end
    end
  end
end

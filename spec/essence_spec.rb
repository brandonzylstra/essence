# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Essence do
  it 'has a version number' do
    expect(Essence::VERSION).not_to be nil
    expect(Essence::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  describe '.generate_template' do
    it 'delegates to Converter.generate_template' do
      file_path = 'custom/path.yaml'
      
      expect(Essence::Converter).to receive(:generate_template).with(file_path)
      
      Essence.generate_template(file_path)
    end

    it 'uses default path when none provided' do
      expect(Essence::Converter).to receive(:generate_template).with('db/schema.yaml')
      
      Essence.generate_template
    end
  end

  describe '.convert' do
    it 'creates a converter instance and calls convert!' do
      yaml_file = 'input.yaml'
      hcl_file = 'output.hcl'
      
      converter_instance = instance_double(Essence::Converter)
      expect(Essence::Converter).to receive(:new).with(yaml_file, hcl_file).and_return(converter_instance)
      expect(converter_instance).to receive(:convert!)
      
      Essence.convert(yaml_file, hcl_file)
    end

    it 'handles nil arguments' do
      converter_instance = instance_double(Essence::Converter)
      expect(Essence::Converter).to receive(:new).with(nil, nil).and_return(converter_instance)
      expect(converter_instance).to receive(:convert!)
      
      Essence.convert
    end
  end

  describe '.rails_bridge' do
    it 'creates a RailsBridge instance with default options' do
      bridge_instance = instance_double(Essence::RailsBridge)
      expect(Essence::RailsBridge).to receive(:new).with(atlas_env: 'dev', rails_root: '.').and_return(bridge_instance)
      
      result = Essence.rails_bridge
      
      expect(result).to eq(bridge_instance)
    end

    it 'creates a RailsBridge instance with custom options' do
      bridge_instance = instance_double(Essence::RailsBridge)
      expect(Essence::RailsBridge).to receive(:new).with(atlas_env: 'production', rails_root: '/app').and_return(bridge_instance)
      
      result = Essence.rails_bridge(atlas_env: 'production', rails_root: '/app')
      
      expect(result).to eq(bridge_instance)
    end
  end

  describe 'error handling' do
    it 'defines a custom Error class' do
      expect(Essence::Error).to be < StandardError
    end

    it 'allows raising custom errors' do
      expect { raise Essence::Error, 'test message' }.to raise_error(Essence::Error, 'test message')
    end
  end

  describe 'module structure' do
    it 'properly defines the module hierarchy' do
      expect(defined?(Essence)).to eq('constant')
      expect(Essence).to be_a(Module)
    end

    it 'includes all expected classes' do
      expect(defined?(Essence::Converter)).to eq('constant')
      expect(defined?(Essence::RailsBridge)).to eq('constant')
      expect(defined?(Essence::VERSION)).to eq('constant')
    end

    it 'has proper class inheritance' do
      expect(Essence::Converter).to be_a(Class)
      expect(Essence::RailsBridge).to be_a(Class)
    end
  end

  describe 'integration test' do
    it 'performs end-to-end template generation and conversion' do
      # Generate template
      Essence.generate_template('db/integration_test.yaml')
      
      expect(File.exist?('db/integration_test.yaml')).to be true
      
      # Convert the template
      Essence.convert('db/integration_test.yaml', 'db/integration_test.hcl')
      
      expect(File.exist?('db/integration_test.hcl')).to be true
      
      # Verify the output
      hcl_content = File.read('db/integration_test.hcl')
      expect(hcl_content).to include('schema "main"')
      expect(hcl_content).to include('table "users"')
      expect(hcl_content).to include('foreign_key')
    end
  end
end
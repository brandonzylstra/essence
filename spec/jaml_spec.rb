# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JAML do
  it 'has a version number' do
    expect(JAML::VERSION).not_to be nil
    expect(JAML::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  describe '.generate_template' do
    it 'delegates to Converter.generate_template' do
      file_path = 'custom/path.yaml'
      
      expect(JAML::Converter).to receive(:generate_template).with(file_path)
      
      JAML.generate_template(file_path)
    end

    it 'uses default path when none provided' do
      expect(JAML::Converter).to receive(:generate_template).with('db/schema.yaml')
      
      JAML.generate_template
    end
  end

  describe '.convert' do
    it 'creates a converter instance and calls convert!' do
      yaml_file = 'input.yaml'
      hcl_file = 'output.hcl'
      
      converter_instance = instance_double(JAML::Converter)
      expect(JAML::Converter).to receive(:new).with(yaml_file, hcl_file).and_return(converter_instance)
      expect(converter_instance).to receive(:convert!)
      
      JAML.convert(yaml_file, hcl_file)
    end

    it 'handles nil arguments' do
      converter_instance = instance_double(JAML::Converter)
      expect(JAML::Converter).to receive(:new).with(nil, nil).and_return(converter_instance)
      expect(converter_instance).to receive(:convert!)
      
      JAML.convert
    end
  end

  describe '.rails_bridge' do
    it 'creates a RailsBridge instance with default options' do
      bridge_instance = instance_double(JAML::RailsBridge)
      expect(JAML::RailsBridge).to receive(:new).with(atlas_env: 'dev', rails_root: '.').and_return(bridge_instance)
      
      result = JAML.rails_bridge
      
      expect(result).to eq(bridge_instance)
    end

    it 'creates a RailsBridge instance with custom options' do
      bridge_instance = instance_double(JAML::RailsBridge)
      expect(JAML::RailsBridge).to receive(:new).with(atlas_env: 'production', rails_root: '/app').and_return(bridge_instance)
      
      result = JAML.rails_bridge(atlas_env: 'production', rails_root: '/app')
      
      expect(result).to eq(bridge_instance)
    end
  end

  describe 'error handling' do
    it 'defines a custom Error class' do
      expect(JAML::Error).to be < StandardError
    end

    it 'allows raising custom errors' do
      expect { raise JAML::Error, 'test message' }.to raise_error(JAML::Error, 'test message')
    end
  end

  describe 'module structure' do
    it 'properly defines the module hierarchy' do
      expect(defined?(JAML)).to eq('constant')
      expect(JAML).to be_a(Module)
    end

    it 'includes all expected classes' do
      expect(defined?(JAML::Converter)).to eq('constant')
      expect(defined?(JAML::RailsBridge)).to eq('constant')
      expect(defined?(JAML::VERSION)).to eq('constant')
    end

    it 'has proper class inheritance' do
      expect(JAML::Converter).to be_a(Class)
      expect(JAML::RailsBridge).to be_a(Class)
    end
  end

  describe 'integration test' do
    it 'performs end-to-end template generation and conversion' do
      # Generate template
      JAML.generate_template('db/integration_test.yaml')
      
      expect(File.exist?('db/integration_test.yaml')).to be true
      
      # Convert the template
      JAML.convert('db/integration_test.yaml', 'db/integration_test.hcl')
      
      expect(File.exist?('db/integration_test.hcl')).to be true
      
      # Verify the output
      hcl_content = File.read('db/integration_test.hcl')
      expect(hcl_content).to include('schema "main"')
      expect(hcl_content).to include('table "users"')
      expect(hcl_content).to include('foreign_key')
    end
  end
end
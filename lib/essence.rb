# frozen_string_literal: true

require_relative "essence/version"
require_relative "essence/converter"
require_relative "essence/rails_bridge"

module Essence
  class Error < StandardError; end

  # Main entry point for Essence functionality
  class << self
    # Generate a new schema template
    #
    # @param file_path [String] Path where to create the template
    # @return [void]
    def generate_template(file_path = 'db/schema.yaml')
      Essence::Converter.generate_template(file_path)
    end

    # Convert YAML schema to HCL format
    #
    # @param yaml_file [String] Input YAML file path
    # @param hcl_file [String] Output HCL file path
    # @return [void]
    def convert(yaml_file = nil, hcl_file = nil)
      converter = Essence::Converter.new(yaml_file, hcl_file)
      converter.convert!
    end

    # Create a Rails bridge instance for schema operations
    #
    # @param atlas_env [String] Atlas environment name
    # @param rails_root [String] Rails application root directory
    # @return [Essence::RailsBridge]
    def rails_bridge(atlas_env: 'dev', rails_root: '.')
      Essence::RailsBridge.new(atlas_env: atlas_env, rails_root: rails_root)
    end
  end
end

# Load rake tasks if we're in a Rails environment
if defined?(Rails)
  require_relative "essence/railtie"
end
# frozen_string_literal: true

require 'rails/railtie'

module JAML
  class Railtie < Rails::Railtie
    railtie_name :jaml

    # Load JAML rake tasks
    rake_tasks do
      load File.expand_path('tasks/jaml.rake', __dir__)
    end

    # Add configuration options
    config.jaml = ActiveSupport::OrderedOptions.new
    
    # Set default configuration
    config.jaml.schema_file = 'db/schema.yaml'
    config.jaml.hcl_file = 'db/schema.hcl'
    config.jaml.atlas_env = 'dev'

    # Initialize JAML after Rails has loaded
    initializer 'jaml.configure' do |app|
      JAML.configure do |config|
        config.schema_file = app.config.jaml.schema_file
        config.hcl_file = app.config.jaml.hcl_file
        config.atlas_env = app.config.jaml.atlas_env
      end
    end

    # Add generators if needed
    generators do
      require_relative 'generators/jaml/install_generator'
    end
  end

  # Configuration class
  class Configuration
    attr_accessor :schema_file, :hcl_file, :atlas_env

    def initialize
      @schema_file = 'db/schema.yaml'
      @hcl_file = 'db/schema.hcl'
      @atlas_env = 'dev'
    end
  end

  # Module-level configuration
  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end
end
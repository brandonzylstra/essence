# frozen_string_literal: true

require 'rails/railtie'

module Essence
  class Railtie < Rails::Railtie
    railtie_name :essence

    # Load Essence rake tasks
    rake_tasks do
      load File.expand_path('tasks/essence.rake', __dir__)
    end

    # Add configuration options
    config.essence = ActiveSupport::OrderedOptions.new
    
    # Set default configuration
    config.essence.schema_file = 'db/schema.yaml'
    config.essence.hcl_file = 'db/schema.hcl'
    config.essence.atlas_env = 'dev'

    # Initialize Essence after Rails has loaded
    initializer 'essence.configure' do |app|
      Essence.configure do |config|
        config.schema_file = app.config.essence.schema_file
        config.hcl_file = app.config.essence.hcl_file
        config.atlas_env = app.config.essence.atlas_env
      end
    end

    # Add generators if needed
    generators do
      require_relative 'generators/essence/install_generator'
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
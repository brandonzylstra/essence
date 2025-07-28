# frozen_string_literal: true

require 'simplecov'
require 'simplecov-html'

# Start SimpleCov before loading any application code
SimpleCov.start do
  add_filter '/spec/'
  add_filter '/example_app/'
  add_filter '/vendor/'

  add_group 'Core', 'lib/jaml'
  add_group 'Tasks', 'lib/jaml/tasks'

  minimum_coverage 90

  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter
  ])
end

require_relative '../lib/essence'

require 'fileutils'
require 'tempfile'
require 'yaml'

RSpec.configure do |config|
  # rspec-expectations config goes here. You can use an alternate
  # assertion/expectation library such as wrong or the stdlib/minitest
  # assertions if you prefer.
  config.expect_with :rspec do |expectations|
    # This option will default to `true` in RSpec 4. It makes the `description`
    # and `failure_message` of custom matchers include text for helper methods
    # defined using `chain`, e.g.:
    #     be_bigger_than(2).and_smaller_than(4).description
    #     # => "be bigger than 2 and smaller than 4"
    # ...rather than:
    #     # => "be bigger than 2"
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # rspec-mocks config goes here. You can use an alternate test double
  # library (such as bogus or mocha) by changing the `mock_with` option here.
  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended, and will default to
    # `true` in RSpec 4.
    mocks.verify_partial_doubles = true
  end

  # This option will default to `:apply_to_host_groups` in RSpec 4 (and will
  # have no way to turn it off -- the option exists only for backwards
  # compatibility in RSpec 3). It causes shared examples to be scoped to the
  # spec files that define them.
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Many RSpec users commonly either run the entire suite or an individual
  # file, and it's useful to allow more verbose output when running an
  # individual spec file.
  if config.files_to_run.one?
    # Use the documentation formatter for detailed output,
    # unless a formatter has already been configured
    config.default_formatter = "doc"
  end

  # Print the 10 slowest examples and example groups at the
  # end of the spec run, to help surface which specs are running
  # particularly slow.
  config.profile_examples = 10

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = :random

  # Seed global randomization in this process using the `--seed` CLI option.
  # Setting this allows you to use `--seed` to deterministically reproduce
  # test failures related to randomization by passing the same `--seed` value
  # as the one that triggered the failure.
  Kernel.srand config.seed

  # Configure test environment cleanup
  config.before(:each) do
    @test_dir = Dir.mktmpdir('jaml_test')
    @original_dir = Dir.pwd
    Dir.chdir(@test_dir)

    # Create a basic directory structure for tests
    FileUtils.mkdir_p('db')
    FileUtils.mkdir_p('lib')
  end

  config.after(:each) do
    if @original_dir && Dir.exist?(@original_dir)
      Dir.chdir(@original_dir)
    end
    FileUtils.rm_rf(@test_dir) if @test_dir && Dir.exist?(@test_dir)
  end

  # Disable monkey patching to encourage good practices
  config.disable_monkey_patching!

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Limit a spec run to individual examples or groups
  # you care about by tagging them with `:focus` metadata.
  config.filter_run_when_matching :focus

  # Allow more verbose output when running an individual spec file.
  config.default_formatter = 'doc' if config.files_to_run.one?

  # Helpers for testing file operations
  config.include Module.new {
    def create_test_yaml(content)
      File.write('db/schema.yaml', content)
    end

    def create_basic_schema
      schema_content = <<~YAML
        schema_name: public
        defaults:
          "*":
            columns:
              id: primary_key
              created_at: datetime not_null
              updated_at: datetime not_null
        column_patterns:
          - "_id$": "integer -> {table}.id on_delete=cascade not_null"
          - "_at$": "datetime not_null"
          - ".*": "string"
        tables:
          users:
            columns:
              email: string(255) not_null unique
              name: string(100) not_null
              league_id: ~
          leagues:
            columns:
              name: string(255) not_null unique
              description: text
      YAML
      create_test_yaml(schema_content)
    end

    def read_generated_hcl
      File.read('db/schema.hcl')
    end
  }
end

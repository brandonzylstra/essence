# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

# Load custom rake tasks
Dir[File.join(__dir__, 'lib', 'tasks', '*.rake')].each { |f| load f }

# Set up RSpec task
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
  spec.rspec_opts = [ '--format documentation', '--color' ]
end

# Set up RuboCop task
RuboCop::RakeTask.new(:rubocop) do |task|
  task.options = [ '--plugin', 'rubocop-rails', '--plugin', 'rubocop-rspec' ]
  task.fail_on_error = true
end

# Auto-correct RuboCop offenses
RuboCop::RakeTask.new('rubocop:autocorrect') do |task|
  task.options = [ '--plugin', 'rubocop-rails', '--plugin', 'rubocop-rspec', '--autocorrect' ]
  task.fail_on_error = false
end

# Yard documentation task
begin
  require 'yard'
  YARD::Rake::YardocTask.new(:doc) do |task|
    task.files = [ 'lib/**/*.rb' ]
    task.options = [
      '--output-dir', 'doc',
      '--markup', 'markdown',
      '--markup-provider', 'kramdown'
    ]
  end
rescue LoadError
  task :doc do
    puts "YARD is not available. Install it with: gem install yard"
  end
end

# Quality control task that runs all checks
desc "Run all quality control checks"
task qa: [ :rubocop, :spec ]

# Development setup task
desc "Set up development environment"
task :setup do
  puts "Installing dependencies..."
  system("bundle install")

  puts "Creating directories..."
  require 'fileutils'
  FileUtils.mkdir_p('tmp')
  FileUtils.mkdir_p('log')

  puts "✅ Development environment ready!"
  puts ""
  puts "Available tasks:"
  puts "  rake spec          # Run tests"
  puts "  rake rubocop       # Run code linting"
  puts "  rake qa            # Run all quality checks"
  puts "  rake doc           # Generate documentation"
  puts "  rake build         # Build gem"
  puts "  rake install       # Install gem locally"
  puts "  rake release       # Release gem (maintainers only)"
end

# Console task for interactive development
desc "Start an interactive console with JAML loaded"
task :console do
  require 'irb'
  require_relative 'lib/jaml'

  puts "🎯 JAML Console"
  puts "Available: JAML, JAML::Converter, JAML::RailsBridge"
  puts ""

  IRB.start
end

# Test the example application
desc "Test the example Rails application"
task :test_example do
  example_dir = File.join(__dir__, 'example_app')

  if Dir.exist?(example_dir)
    puts "🚂 Testing example Rails application..."
    Dir.chdir(example_dir) do
      system("bundle install --quiet")
      system("bundle exec rake test")
    end
  else
    puts "❌ Example application not found at #{example_dir}"
  end
end

# Clean up generated files
desc "Clean up generated files"
task :clean do
  puts "🧹 Cleaning up..."

  # Remove gem files
  FileUtils.rm_rf('pkg/')

  # Remove coverage reports
  FileUtils.rm_rf('coverage/')

  # Remove documentation
  FileUtils.rm_rf('doc/')

  # Remove log files
  FileUtils.rm_rf('log/')

  # Remove temp files
  FileUtils.rm_rf('tmp/')

  puts "✅ Cleanup complete!"
end

# Benchmark task for performance testing
desc "Run performance benchmarks"
task :benchmark do
  puts "🏃‍♂️ Running JAML performance benchmarks..."

  require 'benchmark'
  require_relative 'lib/jaml'
  require 'tempfile'

  # Create a large test schema
  large_schema = {
    'schema_name' => 'main',
    'defaults' => {
      '*' => {
        'columns' => {
          'id' => 'primary_key',
          'created_at' => 'datetime not_null',
          'updated_at' => 'datetime not_null'
        }
      }
    },
    'column_patterns' => [
      { 'pattern' => '_id$', 'template' => 'integer -> {table}.id on_delete=cascade not_null' },
      { 'pattern' => '_at$', 'attributes' => 'datetime not_null' },
      { 'pattern' => '.*', 'attributes' => 'string' }
    ],
    'tables' => {}
  }

  # Generate 50 tables with various columns
  50.times do |i|
    table_name = "table_#{i}"
    large_schema['tables'][table_name] = {
      'columns' => {
        'name' => 'string(255) not_null',
        'description' => 'text',
        'other_table_id' => '~',
        'created_at' => '~',
        'active' => 'boolean default=true'
      },
      'indexes' => [ 'name', 'other_table_id' ]
    }
  end

  Tempfile.create([ 'large_schema', '.yaml' ]) do |yaml_file|
    Tempfile.create([ 'large_schema', '.hcl' ]) do |hcl_file|
      File.write(yaml_file.path, large_schema.to_yaml)

      time = Benchmark.realtime do
        converter = JAML::Converter.new(yaml_file.path, hcl_file.path)
        converter.convert!
      end

      file_size = File.size(hcl_file.path)
      table_count = large_schema['tables'].size

      puts ""
      puts "📊 Benchmark Results:"
      puts "  Tables processed: #{table_count}"
      puts "  Conversion time: #{(time * 1000).round(2)}ms"
      puts "  Output file size: #{(file_size / 1024.0).round(2)}KB"
      puts "  Performance: #{(table_count / time).round(2)} tables/second"
    end
  end
end

# Default task
task default: [ :qa ]

# Help task
desc "Show available rake tasks"
task :help do
  puts "🎯 JAML Gem - Available Rake Tasks"
  puts "=" * 50
  puts ""

  Rake.application.tasks.each do |task|
    next if task.comment.nil?
    printf "%-20s # %s\n", task.name, task.comment
  end

  puts ""
  puts "For more information about JAML, visit:"
  puts "https://github.com/brandonzylstra/jaml"
end

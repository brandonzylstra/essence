# frozen_string_literal: true

require_relative "lib/essence/version"

Gem::Specification.new do |spec|
  spec.name = "essence"
  spec.version = Essence::VERSION
  spec.authors = [ "Brandon Zylstra" ]
  spec.email = [ "brandon.zylstra@gmail.com" ]

  spec.summary = "Essence - Rapid database schema iteration for Rails"
  spec.description = <<~DESC
    Essence is a powerful tool for rapid database schema iteration in Rails applications.
    It provides a clean, YAML-based syntax with intelligent defaults and pattern matching
    for defining database schemas that compile to Atlas HCL format.

    Features include:
    - Default columns for all tables (id, created_at, updated_at)
    - Pattern-based column inference (_id for foreign keys, _at for timestamps)
    - Automatic foreign key generation with pluralization
    - Clean, version-control friendly YAML syntax
    - Seamless Rails integration with rake tasks
    - Template generation for quick project setup
  DESC

  spec.homepage = "https://github.com/brandonzylstra/essence"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/brandonzylstra/essence"
  spec.metadata["changelog_uri"] = "https://github.com/brandonzylstra/essence/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://github.com/brandonzylstra/essence/blob/main/README.md"
  spec.metadata["supported_activerecord_versions"] = "8.0"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile example_app/])
    end
  end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = [ "lib" ]

  # Runtime dependencies
  spec.add_dependency "yaml", "~> 0.3"

  # Optional Rails integration
  spec.add_dependency "railties", ">= 7.0"

  # Development dependencies
  spec.add_development_dependency "bundler", "~> 2.6"
  spec.add_development_dependency "rake", "~> 13.3"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rubocop", "~> 1.75"
  spec.add_development_dependency "rubocop-rails", "~> 2.32"
  spec.add_development_dependency "rubocop-rails-omakase", "~> 1.1"
  spec.add_development_dependency "rubocop-rspec", "~> 3.6"
end

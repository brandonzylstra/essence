# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in jaml.gemspec
gemspec

gem "rake", "~> 13.3"

group :development, :test do
  gem "rspec", "~> 3.13"
  gem "rubocop", "~> 1.75"
  gem "rubocop-rails", "~> 2.32", require: false
  gem "rubocop-rails-omakase", "~> 1.1", require: false
  gem "rubocop-rspec", "~> 3.6", require: false
  gem "yard", "~> 0.9", require: false
end

group :test do
  gem "simplecov", "~> 0.22", require: false
  gem "simplecov-html", "~> 0.13", require: false
end

# Optional: Add platform-specific gems if needed
# gem "wdm", ">= 0.1.0", platforms: [:mingw, :mswin, :x64_mingw, :jruby]

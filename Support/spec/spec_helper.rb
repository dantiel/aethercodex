# frozen_string_literal: true

# Simple spec helper for RSpec tests
require 'rspec'

# Add the Support directory to the load path
$LOAD_PATH.unshift(File.expand_path('..', __dir__))

RSpec.configure do |config|
  config.formatter = :documentation
  config.color = true
  
  # Filter specs that are still in development
  config.filter_run_excluding :wip
end

# Helper method to create temporary test files
def create_test_file(path, content)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, content)
end

# Helper method to cleanup test files
def cleanup_test_files(*paths)
  paths.each do |path|
    File.delete(path) if File.exist?(path)
  end
end
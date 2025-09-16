# frozen_string_literal: true

# Support/argonaut/temp_create_file.rb
# Temporary File Creation Tool
#
# Provides simple temporary file creation with automatic cleanup
# for any infrastructure needs. Supports both system temp files and
# project-relative paths with nested context management.

require_relative 'temp_file_manager'

class Argonaut
  class TempFile
    class << self
      # Create a temporary file with given content
      # @param content [String] The file content
      # @param path [String, nil] Optional relative path within project (nil for system temp)
      # @return [Hash] { path: String, success: Boolean, error: String/nil }
      def create(content, path: nil)
        result = Argonaut::TempFileManager.create_file(content, path: path)
        # Return simplified result without internal context details
        { path: result[:path], success: result[:success], error: result[:error] }
      end

      # Clean up all temporary files in current context
      # @return [Hash] { cleaned: Array<String>, errors: Array<String> }
      def cleanup_all
        result = Argonaut::TempFileManager.cleanup_current_context
        { cleaned: result[:cleaned], errors: result[:errors] }
      end

      # Clean up a specific temporary file
      # @param path [String] Path to the temporary file
      # @return [Hash] { success: Boolean, error: String/nil }
      def cleanup_file(path)
        Argonaut::TempFileManager.cleanup_file(path)
      end

      # List all temporary files in current context
      # @return [Array<String>] List of file paths
      def list_files
        Argonaut::TempFileManager.list_current_context_files
      end

      # Check if a file is registered as temporary
      # @param path [String] File path to check
      # @return [Boolean]
      def temporary_file?(path)
        Argonaut::TempFileManager.temporary_file?(path)
      end
    end
  end
end


# Example usage:
# # Create system temp file
# result1 = Argonaut::TempFile.create("puts 'Hello World'")
#
# # Create file in project structure
# result2 = Argonaut::TempFile.create("config data", path: "tmp/test_config.yml")
#
# # Context-based cleanup happens automatically at oracle boundaries
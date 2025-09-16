# frozen_string_literal: true

# Support/argonaut/temp_file_manager.rb
# Temporary File Context Management System
#
# Provides context-based temporary file management with automatic cleanup
# for nested oracle calls, ensuring different sets of temporary files
# are maintained and cleaned up appropriately.

require 'fileutils'
require 'securerandom'
require 'tmpdir'

class Argonaut
  class TempFileManager
    # Global registry of contexts and their temporary files
    @contexts ||= {}
    @current_context_id ||= nil
    @context_stack ||= []

    class << self
      # Create a new context for temporary file management
      # @return [String] Context UUID
      def create_context
        context_id = SecureRandom.uuid
        @contexts[context_id] = { files: [], created_at: Time.now }
        
        context_id
      end

      # Enter a context - pushes current context onto stack and sets new context
      # @param context_id [String] Context UUID to enter
      def enter_context(context_id)
        @context_stack.push(@current_context_id)
        @current_context_id = context_id
      end

      # Exit current context - pops previous context from stack
      # @return [String] Previous context ID
      def exit_context
        previous_context = @context_stack.pop
        @current_context_id = previous_context
        previous_context
      end

      # Get current context ID
      # @return [String] Current context UUID
      def current_context_id
        @current_context_id ||= create_context
      end

      # Create a temporary file in the current context
      # @param content [String] The file content
      # @param path [String, nil] Optional relative path within project (nil for system temp)
      # @return [Hash] { path: String, context: String, success: Boolean, error: String/nil }
      def create_file(content, path: nil)
        context_id = @current_context_id || current_context_id
        
        begin
          if path
            # Debug: check what path is received
            puts "[TEMP_MANAGER] Creating project file with path: #{path}"
            # Create file within project structure
            # Use project base directory (where TextMate runs commands)
            project_base = ENV['TM_PROJECT_DIRECTORY'] || Dir.pwd
            full_path = File.expand_path(path, project_base)
            puts "[TEMP_MANAGER] Full path: #{full_path}"
            FileUtils.mkdir_p(File.dirname(full_path))
            File.write(full_path, content)
          else
            puts "[TEMP_MANAGER] Creating system temp file (path is nil)"
            # Create file in system temp directory
            temp_dir = Dir.mktmpdir("aether_")
            filename = "temp_#{Time.now.strftime('%Y%m%d-%H%M%S')}_#{SecureRandom.hex(4)}"
            full_path = File.join(temp_dir, filename)
            File.write(full_path, content)
          end
          
          # Register file in current context
          register_file(context_id, full_path)
          
          { path: full_path, context: context_id, success: true, error: nil }
        rescue StandardError => e
          { path: nil, context: context_id, success: false, error: e.message }
        end
      end
      

      # Clean up all files in a specific context
      # @param context_id [String] Context UUID to clean up
      # @return [Hash] { cleaned: Array<String>, errors: Array<String>, context: String }
      def cleanup_context(context_id)
        return { cleaned: [], errors: [], context: context_id } unless @contexts.key?(context_id)
        
        cleaned = []
        errors = []
        
        # Create a copy of the files array to avoid modification during iteration
        files_to_clean = @contexts[context_id][:files].dup
        files_to_clean.each do |file_path|
          result = cleanup_file(file_path)
          if result[:success]
            cleaned << file_path
          else
            errors << "#{file_path}: #{result[:error]}"
          end
        end
        
        # Remove context from registry after cleanup
        @contexts.delete(context_id)
        
        { cleaned: cleaned, errors: errors, context: context_id }
      end
      

      # Clean up all files in a specific domain
      # @param domain_id [String] Domain UUID to clean up
      # @return [Hash] { cleaned: Array<String>, errors: Array<String>, domain: String }
      def cleanup_domain(domain_id)
        return { cleaned: [], errors: [], domain: domain_id } unless @domains.key?(domain_id)
        
        cleaned = []
        errors = []
        
        # Create a copy of the files array to avoid modification during iteration
        files_to_clean = @domains[domain_id][:files].dup
        files_to_clean.each do |path|
          result = cleanup_file(path)
          if result[:success]
            cleaned << path
          else
            errors << "#{path}: #{result[:error]}"
          end
        end
        
        # Remove domain from registry after cleanup
        @domains.delete(domain_id)
        
        { cleaned: cleaned, errors: errors, domain: domain_id }
      end

      # Clean up all files in current context
      # @return [Hash] { cleaned: Array<String>, errors: Array<String>, context: String }
      def cleanup_current_context
        cleanup_context(current_context_id)
      end

      # Clean up a specific temporary file
      # @param path [String] Path to the temporary file
      # @return [Hash] { success: Boolean, error: String/nil }
      def cleanup_file(path)
        begin
          if File.exist?(path)
            File.delete(path)
            # Clean up empty parent directories for system temp files only
            clean_temp_parent_directories(path) if path.include?('/tmp/')
          end
          
          # Remove file from all contexts
          @contexts.each do |context_id, context_info|
            context_info[:files].delete(path)
          end
          
          { success: true, error: nil }
        rescue StandardError => e
          { success: false, error: e.message }
        end
      end

      # List all files in a specific context
      # @param context_id [String] Context UUID
      # @return [Array<String>] List of file paths
      def list_context_files(context_id)
        @contexts.key?(context_id) ? @contexts[context_id][:files].dup : []
      end

      # List all files in current context
      # @return [Array<String>] List of file paths
      def list_current_context_files
        list_context_files(current_context_id)
      end

      # Get information about all contexts
      # @return [Hash] Context information
      def list_contexts
        @contexts.transform_values do |context_info|
          {
            file_count: context_info[:files].size,
            created_at: context_info[:created_at],
            files: context_info[:files].dup
          }
        end
      end

      # Check if a context exists
      # @param context_id [String] Context UUID
      # @return [Boolean]
      def context_exists?(context_id)
        @contexts.key?(context_id)
      end

      # Check if a file is registered in any context
      # @param path [String] File path to check
      # @return [Boolean]
      def temporary_file?(path)
        @contexts.any? { |_, context_info| context_info[:files].include?(path) }
      end

      # Get the context that contains a specific file
      # @param path [String] File path
      # @return [String, nil] Context UUID or nil if not found
      def get_file_context(path)
        @contexts.each do |context_id, context_info|
          return context_id if context_info[:files].include?(path)
        end
        nil
      end

    private

      # Register a file in a specific context
      def register_file(context_id, path)
        unless @contexts.key?(context_id)
          @contexts[context_id] = { files: [], created_at: Time.now }
        end
        
        @contexts[context_id][:files] << path
        
        # Register global cleanup for all files
        register_global_cleanup unless @global_cleanup_registered
      end

      # Register global cleanup handler for process termination
      def register_global_cleanup
        return if @global_cleanup_registered
        
        # Register at_exit handler for cleanup of all contexts
        at_exit do
          cleanup_all_contexts unless @contexts.empty?
        end
        
        @global_cleanup_registered = true
      end

      # Clean up all contexts
      def cleanup_all_contexts
        cleaned = []
        errors = []
        
        @contexts.keys.each do |context_id|
          result = cleanup_context(context_id)
          cleaned.concat(result[:cleaned])
          errors.concat(result[:errors])
        end
        
        { cleaned: cleaned, errors: errors }
      end

      # Clean up empty parent directories for system temp files only
      def clean_temp_parent_directories(path)
        dir = File.dirname(path)
        
        # Only clean system temp directories, not project directories
        return unless dir.include?('/tmp/')
        
        # Remove directory if empty
        if Dir.exist?(dir) && Dir.empty?(dir)
          Dir.delete(dir)
          
          # Recursively clean parent directories if they're also empty and in system temp
          parent_dir = File.dirname(dir)
          clean_temp_parent_directories(parent_dir + '/dummy') if parent_dir.include?('/tmp/')
        end
      end
    end
  end
end

# Example usage:
# # Create a new context for nested operations
# context_id = Argonaut::TempFileManager.create_context
# Argonaut::TempFileManager.enter_context(context_id)
#
# # Create temporary files - system temp or project path
# result1 = Argonaut::TempFileManager.create_file("puts 'Hello World'")
# result2 = Argonaut::TempFileManager.create_file("config data", path: "tmp/test_config.yml")
#
# # When context operations are complete, cleanup automatically happens
# Argonaut::TempFileManager.cleanup_context(context_id)
# Argonaut::TempFileManager.exit_context
# frozen_string_literal: true
require 'fileutils'
require 'json'
require 'time'

# Hermetic trash management - moves files to void rather than destroying
class TrashManager
  TRASH_DIR = '.hermetic_trash'
  MANIFEST_FILE = 'manifest.json'
  MAX_TRASH_AGE_DAYS = 30

  class << self
    # Move file to hermetic void (trash)
    def delete_to_trash(path)
      return { error: 'Path not found' } unless File.exist?(full_path(path))
      return { error: 'Cannot trash directories yet' } if File.directory?(full_path(path))

      ensure_trash_exists
      
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
      original_name = File.basename(path)
      trash_name = "#{timestamp}_#{original_name}"
      trash_path = File.join(trash_dir, trash_name)
      
      # Move file to trash
      FileUtils.mv(full_path(path), trash_path)
      
      # Record in manifest
      update_manifest(trash_name, path, timestamp)
      
      { 
        ok: true, 
        message: "#{path} moved to hermetic void",
        trash_name: trash_name 
      }
    rescue => e
      { error: "Failed to move to trash: #{e.message}" }
    end

    # Restore file from trash
    def restore_from_trash(trash_name, restore_path = nil)
      manifest = load_manifest
      entry = manifest[trash_name]
      
      return { error: 'File not found in trash' } unless entry
      
      original_path = restore_path || entry['original_path']
      trash_file = File.join(trash_dir, trash_name)
      
      return { error: 'Trash file missing' } unless File.exist?(trash_file)
      return { error: 'Target already exists' } if File.exist?(full_path(original_path))
      
      # Restore file
      FileUtils.mv(trash_file, full_path(original_path))
      
      # Remove from manifest
      manifest.delete(trash_name)
      save_manifest(manifest)
      
      { 
        ok: true, 
        message: "#{trash_name} restored to #{original_path}",
        restored_to: original_path 
      }
    rescue => e
      { error: "Failed to restore: #{e.message}" }
    end

    # List trashed files
    def list_trash
      return { files: [] } unless File.exist?(manifest_path)
      
      manifest = load_manifest
      files = manifest.map do |trash_name, data|
        {
          trash_name: trash_name,
          original_path: data['original_path'],
          deleted_at: data['timestamp'],
          size_bytes: File.exist?(File.join(trash_dir, trash_name)) ? File.size(File.join(trash_dir, trash_name)) : 0
        }
      end
      
      { files: files.sort_by { |f| f[:deleted_at] }.reverse }
    end

    # Permanently delete old trash (called automatically)
    def cleanup_old_trash
      return { cleaned: 0 } unless File.exist?(manifest_path)
      
      manifest = load_manifest
      cutoff = Time.now - (MAX_TRASH_AGE_DAYS * 24 * 60 * 60)
      cleaned_count = 0
      
      manifest.each do |trash_name, data|
        deleted_time = Time.parse(data['timestamp'])
        if deleted_time < cutoff
          trash_file = File.join(trash_dir, trash_name)
          File.delete(trash_file) if File.exist?(trash_file)
          manifest.delete(trash_name)
          cleaned_count += 1
        end
      end
      
      save_manifest(manifest)
      { cleaned: cleaned_count }
    rescue => e
      { error: "Cleanup failed: #{e.message}" }
    end

    # Empty trash completely (destructive!)
    def empty_trash
      return { error: 'No trash to empty' } unless File.exist?(trash_dir)
      
      manifest = load_manifest
      count = manifest.size
      
      FileUtils.rm_rf(trash_dir)
      ensure_trash_exists
      
      { 
        ok: true, 
        message: "Hermetic void emptied", 
        files_destroyed: count 
      }
    rescue => e
      { error: "Failed to empty trash: #{e.message}" }
    end

    private

    def project_root
      # Assuming same pattern as Argonaut
      ENV['PROJECT_ROOT'] || Dir.pwd
    end

    def full_path(path)
      File.join(project_root, path)
    end

    def trash_dir
      File.join(project_root, TRASH_DIR)
    end

    def manifest_path
      File.join(trash_dir, MANIFEST_FILE)
    end

    def ensure_trash_exists
      FileUtils.mkdir_p(trash_dir) unless File.exist?(trash_dir)
    end

    def load_manifest
      return {} unless File.exist?(manifest_path)
      JSON.parse(File.read(manifest_path))
    rescue JSON::ParserError
      {}
    end

    def save_manifest(manifest)
      File.write(manifest_path, JSON.pretty_generate(manifest))
    end

    def update_manifest(trash_name, original_path, timestamp)
      manifest = load_manifest
      manifest[trash_name] = {
        'original_path' => original_path,
        'timestamp' => timestamp,
        'deleted_at' => Time.now.iso8601
      }
      save_manifest(manifest)
    end
  end
end
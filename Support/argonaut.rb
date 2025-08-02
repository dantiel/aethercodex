require 'json'
require 'open3'
require 'tempfile'
require_relative 'diff_crepusculum'


class Argonaut
  @diff_crepusculum ||= DiffCrepusculum::ChrysopoeiaDiff.new
  
  
  def self.read(path)
    base = project_root
    File.read(File.join(base, path))
  end
  

  def self.write(path, text)
    base = project_root
    full = File.join(base, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, text)
  end
  
  
  def self.multi_patch(patches:)
    patches.each { |h| patch(h[:path], h[:diff]) }
    { ok: true, count: patches.size }
  end
  
  
  def self.rename(from, to)
    root = project_root
    FileUtils.mkdir_p(File.dirname(File.join(root, to)))
    FileUtils.mv(File.join(root, from), File.join(root, to))
  end


  # patch as unified diff string
  def self.patch(path, patch_text)
    base = project_root
    full = File.join(base, path)
    
    # Read the original content
    original_content = File.read full
    
    # Apply the converted diff
    puts "TRY PATCH======="
    result = @diff_crepusculum.apply_diff original_content, patch_text
    puts "PATCH======="
    puts result.inspect
    raise "Patch failed: #{result[:fail_parts].to_json}" unless result[:success]
    File.write(full, result[:content])
  end

  def self.project_root
    if ENV['TM_DEBUG_PATHS']
      puts "🔮 Dimensional Diagnostics:"
      puts "TM_PROJECT_DIRECTORY: #{ENV['TM_PROJECT_DIRECTORY'].inspect}"
      puts "TM_DIRECTORY: #{ENV['TM_DIRECTORY'].inspect}"      
      puts "TM_FILEPATH: #{ENV['TM_FILEPATH'].inspect}"
      puts "TM_SELECTED_FILE: #{ENV['TM_SELECTED_FILE'].inspect}"
      puts "Current directory: #{Dir.pwd}"
    end
    
    root = ENV['TM_PROJECT_DIRECTORY'] || ENV['TM_DIRECTORY'] || Dir.pwd
    
    if root && File.file?(root)
      root = File.dirname(root)
    end
    
    root
  end


  def self.includeFiles
    ["*", ".tm_properties", ".htaccess"] + 
    `#{ENV['TM_QUERY']}`.scan(/includeInFileChooser=\{(.*?)\}/).flatten.first.to_s.split(',').reject { |f| f.empty? || f == '{}' }
  end


  def self.excludeFiles
    ["*.{o", "pyc"] +
    `#{ENV['TM_QUERY']}`.scan(/excludeInFileChooser=\{(.*?)\}/).flatten.first.to_s.split(',').reject { |f| f.empty? || f == '{}' }
  end
  
  
  def self.list_files(glob) 
    Dir.chdir(project_root) { Dir.glob(glob) }
  end
    

  def self.list_project_files
    root = project_root
    includes = includeFiles
    excludes = excludeFiles

    if ENV['TM_DEBUG_PATHS']
      puts "list_project_files"
      puts `#{ENV['TM_QUERY']}`
      puts root
      puts includes
      puts excludes
    end
    
    Dir.chdir(root) { 
      Dir.glob(if includes.empty? 
        then '**/*.{rb,js,ts,coffee,css,html,md}' 
        else  "**/{#{includes.join ','}}" end
      ).reject { |f| excludes.any? { |ex| 
        File.fnmatch(ex, File.basename(f)) } } }
  end
  
  
  def self.file_overview(path:)
    puts "[ARGONAUT]: file_overview(path: #{path})"
    notes = Mnemosyne.fetch_notes_by_links(path)
    puts "[ARGONAUT]: notes=#{notes}"

    fullpath = File.join project_root, path 
    file_info = {
      size: File.size(fullpath),
      last_modified: File.mtime(fullpath) 
    }
    puts "[ARGONAUT]: file_info=#{file_info}"
    { notes: notes, file_info: file_info }
  rescue => e
    { error: e.inspect }
  end
end


require 'open3'
require 'tempfile'


class FileManager
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
  def self.patch(path, patch_text, dry:)
    base = project_root
    full = File.join(base, path)
    Tempfile.create(['patch', '.diff']) do |f|
      f.write(patch_text)
      f.flush
      stdout, stderr, status = Open3.capture3('patch', full, f.path)
      raise "patch failed: #{stderr}\n#{stdout}" unless status.success?
    end
  end
  

  def self.project_root
    # Debug environment variables for cosmic alignment
    if ENV['TM_DEBUG_PATHS']
      puts "🔮 Dimensional Diagnostics:"
      puts "TM_PROJECT_DIRECTORY: #{ENV['TM_PROJECT_DIRECTORY'].inspect}"
      puts "TM_DIRECTORY: #{ENV['TM_DIRECTORY'].inspect}"
      puts "TM_FILEPATH: #{ENV['TM_FILEPATH'].inspect}"
      puts "TM_SELECTED_FILE: #{ENV['TM_SELECTED_FILE'].inspect}"
      puts "Dir.pwd: #{Dir.pwd}"
    end
    
    # Try multiple TextMate environment variables
    root = ENV['TM_PROJECT_DIRECTORY'] || ENV['TM_DIRECTORY'] || Dir.pwd
    
    # If we get a file path instead of directory, extract directory
    if root && File.file?(root)
      root = File.dirname(root)
    end
    
    root
  end

  def self.includeFiles
    ["*", ".tm_properties", ".htaccess"] + 
    `#{ENV['TM_QUERY']}`.scan(/includeFiles=\{(.*?)\}/).flatten.first.to_s.split(',').reject { |f| f.empty? || f == '{}' }
  end

  def self.excludeFiles
    ["*.{o", "pyc"] +
    `#{ENV['TM_QUERY']}`.scan(/excludeFiles=\{(.*?)\}/).flatten.first.to_s.split(',').reject { |f| f.empty? || f == '{}' }
  end
  
  
  def self.list_files(glob) 
    Dir.chdir(project_root) { Dir.glob(glob) }
  end
    

  def self.list_project_files
    root = project_root
    includes = includeFiles
    excludes = excludeFiles
    puts "list_project_files"
    puts `#{ENV['TM_QUERY']}`
    puts root
    puts includes
    puts excludes

    Dir.chdir(root) { 
      Dir.glob(if includes.empty? 
        then '**/*.{rb,js,ts,coffee,css,html,md}' 
        else  "**/{#{includes.join ','}}" end
      ).reject { |f| excludes.any? { |ex| 
        File.fnmatch(ex, File.basename(f)) } } }
  end
end

# FileManager.project_list_files

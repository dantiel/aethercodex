require 'json'
require 'open3'
require 'tempfile'
require_relative 'diff_crepusculum'
require 'pathname'
require_relative 'simple_scopes'
require_relative 'aether_scopes_enhanced'
require_relative 'mnemosyne'



class Argonaut
  @diff_crepusculum ||= DiffCrepusculum::ChrysopoeiaDiff.new
  
  
  def self.relative_path(path)
    path = if path.start_with? '/'
      absolute_path = Pathname.new path
      relative_path = absolute_path.relative_path_from project_root
      relative_path.to_s
    else
      path
    end
  end
  

  def self.read(path, range = nil)
    base = project_root
    src = File.read(File.join base, path)
    
    result = if range && range.size == 2
      l0, l1 = range
      
      if l0 > src.lines.count
        { error: "line range #{l0}-#{l1} exceeds lines in file = #{src.lines.count}" }
      else
        lines = src.lines[l0..l1] || []
      
        { content: lines.join, range: [l0, l1] }
      end
    else
      { content: src }
    end
  end
  

  def self.write(path, text)
    base = project_root
    full = File.join base, path
    FileUtils.mkdir_p(File.dirname full)
    File.write full, text
  end
  
  
  def self.multi_patch(patches:)
    patches.each { |h| patch(h[:path], h[:diff]) }
    { ok: true, count: patches.size }
  end
  
  
  def self.rename(from, to)
    root = project_root
    FileUtils.mkdir_p(File.dirname(File.join root, to))
    FileUtils.mv File.join(root, from), File.join(root, to)
  end


  # patch as unified diff string
  def self.patch(path, patch_text)
    base = project_root
    full = File.join(base, path)
    
    # Read the original content
    original_content = File.read full
    
    # Apply the converted diff
    result = @diff_crepusculum.apply_diff original_content, patch_text
    result => { success:, fail_parts: }
    
    raise "Patch failed: #{fail_parts.to_json}" unless success

    content = result[:content]
    File.write full, content
    [original_content, content]
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
    (`#{ENV['TM_QUERY']}`.scan(/includeInArgonaut=\{\{?([^\n]*?)\}\}?/).flatten.first.to_s.split(',').reject { |f| f.empty? || f == '{}' })
  end


  def self.excludeFiles
    ["*.{o", "pyc"] +
    `#{ENV['TM_QUERY']}`.scan(/excludeInArgonaut=\{\{?([^\n]*?)\}\}?/).flatten.first.to_s.split(',').reject { |f| f.empty? || f == '{}' }
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
  
  
  def self.file_overview(path:, max_notes: 3, max_content_length: 150)
    fullpath = File.join(project_root, path)
    
    # Get notes count and tags only - no full content to prevent context bloat
    notes_info = Mnemosyne.fetch_notes_by_links(path).map do |note|
      note.transform_keys!(&:to_sym)
      {
        id: note[:id],
        tags: note[:tags]&.split(',') || [],
        excerpt: note[:content] ? Mnemosyne.truncate_note_content(note[:content], max_length: 50) : nil
      }
    end.take(max_notes)
    
    # Handle nil notes gracefully
    notes_info ||= []
    notes_info = notes_info.take(max_notes)
    
    line_count = 0
    File.foreach(fullpath) { |line| line_count += 1 }
    
    file_info = {
      lines: line_count,
      size: File.size(fullpath),
      last_modified: File.mtime(fullpath),
      path: path
    }

    # Add enhanced symbolic structural overview using AetherScopesEnhanced
    symbolic_overview = if File.exist?(fullpath) && File.readable?(fullpath)
      begin
        AetherScopesEnhanced.for_file_overview(fullpath, max_notes: max_notes, max_content_length: max_content_length)
      rescue => e
        { error: "Enhanced symbolic parsing failed: #{e.message}" }
      end
    else
      { error: "File not readable" }
    end

    {
      notes_count: notes_info.size,
      notes_preview: notes_info,
      file_info: file_info,
      symbolic_overview: symbolic_overview
    }
  rescue => e
    { error: e.inspect }
  end
end
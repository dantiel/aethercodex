# frozen_string_literal: true

require 'json'
require 'open3'
require 'tempfile'
require 'pathname'
require_relative '../mnemosyne/mnemosyne'
require_relative '../instrumentarium/diff_crepusculum'
require_relative '../instrumentarium/semantic_patch'
require_relative 'simple_scopes'
require_relative 'aether_scopes_enhanced'
require_relative 'aether_scopes_hierarchical'
require_relative 'lexicon_resonantia'
# require_relative 'temp_create_file'  # Moved to instrumentarium domain system



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


  # Reads a file relative to base of project folder.
  def self.read(path, range = nil)
    base = project_root
    src = File.read File.join base, path

    result = if range && 2 == range.size
               l0, l1 = range
               l0 -= 1
               l0 = [0, l0].max

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
    FileUtils.mkdir_p File.dirname full
    File.write full, text
  end


  def self.file_exists?(path)
    fullpath = File.join project_root, path
    File.exist?(fullpath) && File.readable?(fullpath)
  end


  def self.multi_patch(patches:)
    patches.each { |h| patch h[:path], h[:diff] }
    { ok: true, count: patches.size }
  end


  def self.rename(from, to)
    root = project_root
    FileUtils.mkdir_p File.dirname(File.join(root, to))
    FileUtils.mv File.join(root, from), File.join(root, to)
  end


  # TODO: doesnt work
  # patch as unified diff string
  def self.new_patch(path, patch_text)
    base = project_root
    full = File.join base, path

    # Use hybrid patching - semantic first, fallback to line-based
    result = SemanticPatch.apply_hybrid_patch full, patch_text

    # Maintain backward compatibility with existing return format
    if result[:ok] || result[:success]
      # For semantic patches, we need to read the file to get original content
      original_content = result[:original_content] || File.read(full)
      modified_content = File.read full
      { ok: true, result: [original_content, modified_content] }
    else
      { error: result[:error] || result[:fail_parts] }
    end
  end


  # patch as unified diff string
  def self.patch(path, patch_text)
    base = project_root
    full = File.join base, path

    # Read the original content
    original_content = File.read full

    # Apply the converted diff
    result = @diff_crepusculum.apply_diff original_content, patch_text
    result => { success: }

    if success
      content = result[:content]
      File.write full, content
      { ok: true, result: [original_content, content] }
    else
      { error: result[:fail_parts] || result[:error] }
    end
  end


  def self.project_root
    if ENV['TM_DEBUG_PATHS']
      puts '🔮 Dimensional Diagnostics:'
      puts "TM_PROJECT_DIRECTORY: #{ENV['TM_PROJECT_DIRECTORY'].inspect}"
      puts "TM_DIRECTORY: #{ENV['TM_DIRECTORY'].inspect}"
      puts "TM_FILEPATH: #{ENV['TM_FILEPATH'].inspect}"
      puts "TM_SELECTED_FILE: #{ENV['TM_SELECTED_FILE'].inspect}"
      puts "Current directory: #{Dir.pwd}"
      puts "TM_QUERY: #{`#{ENV.fetch 'TM_QUERY', nil}`}"
    end

    root = ENV['TM_PROJECT_DIRECTORY'] || ENV['TM_DIRECTORY'] || Dir.pwd

    root = File.dirname root if root && File.file?(root)

    root
  end


  def self.include_files
    ['*', '.tm_properties', '.htaccess'] +
      `#{ENV.fetch 'TM_QUERY', nil}`
      .scan(/includeInArgonaut=\{([^\n]*)\}/).flatten.first.to_s.gsub(/\{|\}/,'').split(',')
      .reject do |f|
        f.empty? || '{}' == f
      end
  end
  "excludeInArgonaut={{,*.orig,*.rej,*.js},*/target/debug,debug}"

  def self.exclude_files
    ['*.{o}', 'pyc'] +
      `#{ENV.fetch 'TM_QUERY', nil}`
      .scan(/excludeInArgonaut=\{([^\n]*)\}/).flatten.first.to_s.gsub(/\{|\}/,'').split(',')
      .reject do |f|
        f.empty? || '{}' == f
      end
  end


  def self.list_files(glob)
    Dir.chdir(project_root) { Dir.glob glob }
  end


  def self.list_project_files
    root = project_root
    includes = include_files
    excludes = exclude_files

    if ENV['TM_DEBUG_PATHS']
      puts 'list_project_files'
      puts `#{ENV.fetch 'TM_QUERY', nil}`
      puts root
      puts includes
      puts excludes
    end

    Dir.chdir root do
      Dir.glob(if includes.empty? then '**/*.{rb,js,ts,coffee,css,html,md}'
               else
                 "**/{#{includes.join ','}}"
               end).reject do |f|
        excludes.any? do |ex|
          argonaut_match? ex, f
        end
      end
    end
  end


  def self.argonaut_match?(pattern, path)
    clean_path = Pathname.new(path).cleanpath.to_s

    rooted_pattern = pattern.start_with?('/') ? pattern.sub('/', '') : "**/#{pattern}"

    rest_pattern = rooted_pattern.sub '**/', ''

    if rest_pattern.end_with? '/**'
      dir_pattern = rest_pattern.sub '/**', ''
      return clean_path.start_with? dir_pattern
    end

    pattern_segments = rest_pattern.split '/'
    path_segments = clean_path.split '/'

    (0..path_segments.size).each do |i|
      sub_path_segments = path_segments[i..]
      next if pattern_segments.size > sub_path_segments.size

      match = true
      pattern_segments.each_with_index do |p_seg, j|
        unless File.fnmatch? p_seg, sub_path_segments[j].to_s, File::FNM_DOTMATCH
          match = false
          break
        end
      end
      return true if match
    end

    false
  end


  def self.file_overview(path:, max_notes: 3, max_content_length: 555, max_depth: nil)
    fullpath = File.join project_root, path

    # Get notes count for statistics only
    notes_count = Mnemosyne.fetch_notes_by_links(path).size

    line_count = 0
    File.foreach(fullpath) { |_line| line_count += 1 }

    file_info = {
      lines:         line_count,
      size:          File.size(fullpath),
      last_modified: File.mtime(fullpath),
      path:          path
    }

    # Add enhanced symbolic structural overview using AetherScopesEnhanced
    symbolic_overview = if File.exist?(fullpath) && File.readable?(fullpath)
                          # puts "DEBUG: File exists and is readable: #{fullpath}"
                          begin
                            # puts "DEBUG: Calling AetherScopesHierarchical.for_file_overview with max_depth: #{max_depth}"
                            result = AetherScopesHierarchical.for_file_overview \
                              project_root, path, max_notes: max_notes,
                                                  max_content_length: max_content_length,
                                                  max_depth: max_depth
                            # puts "DEBUG: AetherScopesHierarchical.for_file_overview returned: #{result.inspect}"
                            result
                          rescue StandardError => e
                            # puts "DEBUG: AetherScopesHierarchical.for_file_overview failed: #{e.message} #{max_notes}, #{max_content_length} #{max_depth}"
                            { error: "Enhanced symbolic parsing failed: #{e.message}" }
                          end
                        else
                          # puts "DEBUG: File does not exist or is not readable: #{fullpath}"
                          { error: 'File not readable' }
                        end

    # Generate hermetic symbolic overview from Mnemosyne notes
    hermetic_overview = begin
      notes = Mnemosyne.fetch_notes_by_links path
      LexiconResonantia.generate_from_notes notes, min_count: 1, top_k: 5
    rescue StandardError => e
      { error: "Hermetic overview failed: #{e.message}" }
    end

    {
      notes_count:       notes_count,
      file_info:,
      symbolic_overview:,
      hermetic_overview:
    }
  rescue StandardError => e
    { error: e.inspect }
  end
end

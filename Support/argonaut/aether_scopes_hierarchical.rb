# frozen_string_literal: true

# AETHER SCOPES HIERARCHICAL - Enhanced Symbolic Analysis Engine
# Language-agnostic hierarchical parsing with import/export tracking

# Language-agnostic hierarchical symbolic analysis

require_relative '../mnemosyne/mnemosyne'
# require_relative '../argonaut/argonaut'



module AetherScopesHierarchical
  # Language-specific patterns for hierarchical analysis
  LANGUAGE_PATTERNS = {
    # Ruby patterns
    ruby:         {
      hierarchy: [
        { type: :module, pattern: /^\s*module\s+(\w+)/, level: :container },
        { type: :class, pattern: /^\s*class\s+(\w+)/, level: :container },
        { type: :singleton_method, pattern: /^\s*def\s+self\.(\w+)/, level: :member },
        { type: :class_method, pattern: /^\s*def\s+([A-Z]\w*\.\w+)/, level: :member },
        { type: :method, pattern: /^\s*def\s+(\w+)/, level: :member },
        { type: :constant, pattern: /^\s*([A-Z][A-Z0-9_]*)\s*=/, level: :member },
        { type:         :instance_variable,
          pattern:      /^\s*@(\w+)\s*=/,
          level:        :variable,
          parent_scope: true },
        { type: :class_variable, pattern: /^\s*@@(\w+)\s*=/, level: :variable, parent_scope: true },
        { type:         :global_variable,
          pattern:      /^\s*\$(\w+)\s*=/,
          level:        :variable,
          parent_scope: true },
        { type:         :local_variable,
          pattern:      /^\s*(\w+)\s*=[^=>]*$/,
          level:        :variable,
          parent_scope: true }
      ],
      imports:   [
        { type: :require, pattern: /^\s*require\s+['"]([^'"]+)['"]/ },
        { type: :require_relative, pattern: /^\s*require_relative\s+['"]([^'"]+)['"]/ },
        { type: :load, pattern: /^\s*load\s+['"]([^'"]+)['"]/ }
      ],
      exports:   [
        { type: :module_function, pattern: /^\s*module_function/ },
        { type: :public, pattern: /^\s*public/ },
        { type: :private, pattern: /^\s*private/ },
        { type: :protected, pattern: /^\s*protected/ }
      ]
    },

    # JavaScript patterns
    javascript:   {
      hierarchy: [
        { type: :class, pattern: /^\s*class\s+(\w+)/, level: :container },
        { type: :function, pattern: /^\s*function\s+(\w+)/, level: :member },
        { type:    :arrow_function,
          pattern: /^\s*const\s+(\w+)\s*=\s*\([^)]*\)\s*=>/,
          level:   :member },
        { type: :const, pattern: /^\s*const\s+(\w+)\s*=/, level: :member },
        { type: :let, pattern: /^\s*let\s+(\w+)\s*=/, level: :member },
        { type: :var, pattern: /^\s*var\s+(\w+)\s*=/, level: :member }
      ],
      imports:   [
        { type: :import, pattern: /^\s*import\s+(?:[^'"\n]+from\s+)?['"]([^'"]+)['"]/ },
        { type: :require, pattern: /^\s*const\s+\w+\s*=\s*require\(['"]([^'"]+)['"]\)/ }
      ],
      exports:   [
        { type: :export, pattern: /^\s*export\s+(?:default\s+)?(?:class|function|const|let|var)/ },
        { type: :module_exports, pattern: /^\s*module\.exports\s*=/ }
      ]
    },

    # Python patterns
    python:       {
      hierarchy: [
        { type: :class, pattern: /^\s*class\s+(\w+)/, level: :container },
        { type: :function, pattern: /^\s*def\s+(\w+)/, level: :member },
        { type: :async_function, pattern: /^\s*async\s+def\s+(\w+)/, level: :member }
      ],
      imports:   [
        { type: :import, pattern: /^\s*import\s+(\w+)/ },
        { type: :from_import, pattern: /^\s*from\s+(\w+)\s+import/ }
      ],
      exports:   [
        { type: :__all__, pattern: /^\s*__all__\s*=/ }
      ]
    },

    # HTML patterns
    html:         {
      hierarchy: [
        { type: :element, pattern: /<([\w:-]+)/, level: :container },
        { type: :id, pattern: /id=['"]([^'"]+)['"]/, level: :attribute },
        { type: :class, pattern: /class=['"]([^'"]+)['"]/, level: :attribute }
      ],
      imports:   [
        { type: :link, pattern: /<link[^>]*href=['"]([^'"]+)['"]/ },
        { type: :script, pattern: /<script[^>]*src=['"]([^'"]+)['"]/ }
      ],
      exports:   []
    },

    # CSS patterns
    css:          {
      hierarchy: [
        { type: :selector, pattern: /^([^{]+)\{/, level: :container },
        { type: :at_rule, pattern: /^@(\w+)/, level: :directive }
      ],
      imports:   [
        { type: :import, pattern: /@import\s+(?:url\()?['"]([^'"]+)['"]/ }
      ],
      exports:   []
    },

    # CoffeeScript patterns
    coffeescript: {
      hierarchy: [
        { type: :class, pattern: /^\s*class\s+(\w+)/, level: :container },
        { type: :function, pattern: /^\s*(\w+)\s*[:=]\s*\([^)]*\)\s*->/, level: :member },
        { type: :function, pattern: /^\s*(\w+)\s*=\s*\([^)]*\)\s*->/, level: :member },
        { type: :variable, pattern: /^\s*(\w+)\s*=\s*[^->]/, level: :member },
        { type: :constant, pattern: /^\s*([A-Z][A-Z0-9_]*)\s*=/, level: :member }
      ],
      imports:   [
        { type: :require, pattern: /^\s*require\s+['"]([^'"]+)['"]/ },
        { type: :require_relative, pattern: /^\s*require_relative\s+['"]([^'"]+)['"]/ },
        { type: :import, pattern: /^\s*import\s+['"]([^'"]+)['"]/ }
      ],
      exports:   [
        { type: :module_export, pattern: /^\s*module\.exports\s*=/ },
        { type: :export, pattern: /^\s*export\s+default/ }
      ]
    }
  }.freeze

  # Scope levels for hierarchical organization
  SCOPE_LEVELS = {
    container: 1, # Modules, classes, functions that contain other elements
    member:    2, # Methods, constants within containers
    variable:  3, # Variables (instance, class, local, global)
    attribute: 4,  # HTML attributes, CSS properties
    directive: 5   # Import/export directives, at-rules
  }.freeze



  class HierarchicalParser
    def initialize(content, language = nil, file_path = nil)
      @content = content
      @file_path = file_path
      @language = language || detect_language(content)
      @lines = content.lines
      @hierarchy = []
      @imports = []
      @exports = []
      @current_scope = []
    end


    def parse
      @lines.each_with_index do |line, index|
        line_number = index + 1

        # Parse hierarchy elements
        parse_hierarchy line, line_number

        # Parse imports and exports
        parse_imports line, line_number
        parse_exports line, line_number
      end

      {
        language:  @language,
        hierarchy: @hierarchy,
        imports:   @imports,
        exports:   @exports,
        structure: analyze_structure
      }
    end

    private


    def detect_language(content)
      # Enhanced language detection with file extension support and CoffeeScript detection
      lines = content.lines

      # Check first 20 lines for language signatures
      sample = lines[0..19].join

      # First, check for CoffeeScript patterns (function definitions, -> arrows)
      if sample =~ /^\s*\w+\s*[:=]\s*\([^)]*\)\s*->/ ||
         (sample =~ /^\s*class\s+\w+/ && sample =~ /\bconstructor:\s*->/) ||
         sample =~ /^\s*\w+\s*=\s*\([^)]*\)\s*->/

        return :coffeescript
      end

      # Then check other languages
      case sample
      when /^\s*class\s+\w+.*:\s*$/ then :python
      when /^\s*function\s+\w+|^\s*const\s+\w+\s*=|^\s*let\s+\w+\s*=/ then :javascript
      when /^\s*def\s+\w+|^\s*class\s+\w+|^\s*module\s+\w+/ then :ruby
      when /@import|^[^{]*\{[^}]*\}/ then :css
      when /<html|<!DOCTYPE/i then :html
      else
        # Fallback: check file extension if available
        if @file_path
          case File.extname(@file_path).downcase
          when '.coffee', '.litcoffee' then :coffeescript
          when '.js', '.jsx', '.mjs' then :javascript
          when '.rb' then :ruby
          when '.py' then :python
          when '.html', '.htm' then :html
          when '.css', '.scss', '.sass', '.less' then :css
          else
            :ruby # Default to Ruby for this codebase
          end
        else
          :ruby # Default to Ruby for this codebase
        end
      end
    end


    def parse_hierarchy(line, line_number)
      patterns = LANGUAGE_PATTERNS[@language]&.[](:hierarchy) || []

      patterns.each do |pattern|
        # puts "    Testing pattern: #{pattern[:type]} - #{pattern[:pattern].source}"
        next unless (match = line.match pattern[:pattern])

        # puts "    Pattern #{pattern[:type]} matched! Captured: #{match[1]}"

        # Handle special cases for naming
        name = match[1]

        # puts "    Raw captured name: #{name.inspect}, pattern type: #{pattern[:type]}"

        # Fix class method names (extract just the method name from "ClassName.method_name")
        if :class_method == pattern[:type] && name.include?('.')
          name = name.split('.').last
          # puts "    After class method fix: #{name}"
        end

        # Fix singleton method names (extract just the method name from "self.method_name")
        if :singleton_method == pattern[:type] && name.start_with?('self.')
          name = name.sub('self.', '')
          # puts "    After singleton method fix: #{name}"
        end

        element = {
          type:         pattern[:type],
          name:         name,
          line:         line_number,
          level:        pattern[:level],
          children:     [],
          parent_scope: pattern[:parent_scope] || false
        }

        # Add to hierarchy with proper nesting
        add_to_hierarchy element
        break
      end
    end


    def add_to_hierarchy(element)
      level_weight = SCOPE_LEVELS[element[:level]] || 99

      # Variables should be children of the current method/scope
      if element[:parent_scope] && !@current_scope.empty?
        # Add variable as child of current scope
        @current_scope.last[:children] << element
        return
      end

      # Find appropriate parent based on scope level
      while !@current_scope.empty? &&
            SCOPE_LEVELS[@current_scope.last[:level]] >= level_weight

        @current_scope.pop
      end

      if @current_scope.empty?
        @hierarchy << element
      else
        @current_scope.last[:children] << element
      end

      # Push to current scope if it's a container or member (methods)
      return unless %i[container member].include? element[:level]

      @current_scope << element
    end


    def parse_imports(line, line_number)
      patterns = LANGUAGE_PATTERNS[@language]&.[](:imports) || []

      patterns.each do |pattern|
        next unless (match = line.match pattern[:pattern])

        @imports << {
          type:   pattern[:type],
          target: match[1],
          line:   line_number
        }
        break
      end
    end


    def parse_exports(line, line_number)
      patterns = LANGUAGE_PATTERNS[@language]&.[](:exports) || []

      patterns.each do |pattern|
        next unless (match = line.match pattern[:pattern])

        @exports << {
          type: pattern[:type],
          line: line_number
        }
        break
      end
    end


    def analyze_structure
      {
        total_lines:       @lines.size,
        significant_lines: @hierarchy.size + @imports.size + @exports.size,
        import_count:      @imports.size,
        export_count:      @exports.size,
        symbol_count:      count_symbols(@hierarchy)
      }
    end


    def count_symbols(hierarchy)
      count = hierarchy.size
      hierarchy.each { |item| count += count_symbols item[:children] }
      count
    end
  end


  # Main API for file overview integration - hierarchical and language-aware
  def self.structural_overview(project_root, file_path, content = nil, max_depth: nil)
    full_path = File.join project_root, file_path
    content ||= (File.read full_path if File.exist? full_path)
    return empty_analysis unless content

    parser = HierarchicalParser.new content, nil, full_path
    analysis = parser.parse

    # Apply depth reduction if specified
    analysis[:hierarchy] = reduce_hierarchy_depth(analysis[:hierarchy], max_depth) if max_depth

    # Debug: check what the parser returns
    # puts "DEBUG: analysis[:hierarchy] = #{analysis[:hierarchy].inspect}"
    # puts "DEBUG: analysis[:imports] = #{analysis[:imports].inspect}"
    # puts "DEBUG: analysis[:exports] = #{analysis[:exports].inspect}"

    line_hints = generate_line_hints analysis
    navigation_hints = generate_navigation_hints analysis

    # puts "DEBUG: line_hints = #{line_hints.inspect}"
    # puts "DEBUG: navigation_hints = #{navigation_hints.inspect}"

    {
      file:             file_path,
      language:         analysis[:language],
      hierarchy:        analysis[:hierarchy],
      imports:          analysis[:imports],
      exports:          analysis[:exports],
      structure:        analysis[:structure],
      summary:          generate_summary(analysis),
      line_hints:       line_hints,
      navigation_hints: navigation_hints
    }
  end


  def self.generate_summary(analysis)
    {
      language:      analysis[:language],
      containers:    count_by_type(analysis[:hierarchy], [:container]),
      members:       count_by_type(analysis[:hierarchy], %i[member attribute directive]),
      imports:       analysis[:imports].size,
      exports:       analysis[:exports].size,
      total_symbols: analysis[:structure][:symbol_count]
    }
  end


  def self.count_by_type(hierarchy, types)
    count = 0
    hierarchy.each do |item|
      count += 1 if types.include? item[:level]
      count += count_by_type item[:children], types
    end
    count
  end


  def self.generate_line_hints(analysis)
    hints = Hash.new { |h, k| h[k] = [] }

    # Add hierarchy elements
    extract_all_elements(analysis[:hierarchy]).each do |element|
      line_key = element[:line].to_s
      hints[line_key] << "#{element[:type]}: #{element[:name]}"
    end

    # Add imports and exports
    (analysis[:imports] + analysis[:exports]).each do |item|
      line_key = item[:line].to_s
      desc = item[:target] ? "#{item[:type]} -> #{item[:target]}" : item[:type]
      hints[line_key] << desc
    end

    # Convert to sorted hash with guaranteed arrays
    hints.sort.to_h
  end


  def self.generate_navigation_hints(analysis)
    # Hierarchy navigation
    hints = extract_all_elements(analysis[:hierarchy]).map do |element|
      {
        type:        :structure,
        target:      "#{element[:type]}:#{element[:name]}",
        line:        element[:line],
        level:       element[:level],
        description: "Navigate to #{element[:type]} #{element[:name]}"
      }
    end

    # Import navigation
    analysis[:imports].each do |import|
      hints << {
        type:        :dependency,
        target:      import[:target],
        line:        import[:line],
        description: "Import: #{import[:type]} -> #{import[:target]}"
      }
    end

    # Export navigation
    analysis[:exports].each do |export|
      hints << {
        type:        :export,
        target:      'export',
        line:        export[:line],
        description: "Export: #{export[:type]}"
      }
    end

    hints.sort_by { |h| h[:line] }
  end


  def self.extract_all_elements(hierarchy, depth = 0)
    elements = []
    hierarchy.each do |item|
      new_item = item.clone
      new_item[:depth] = depth
      elements << new_item
      elements.concat extract_all_elements(item[:children], depth + 1)
    end
    elements
  end


  def self.empty_analysis
    {
      language:  :unknown,
      hierarchy: [],
      imports:   [],
      exports:   [],
      structure: {
        total_lines:       0,
        significant_lines: 0,
        import_count:      0,
        export_count:      0,
        symbol_count:      0
      }
    }
  end


  # Enhanced integration with file_overview tool - hierarchical and language-aware
  def self.for_file_overview(project_root,
                             file_path,
                             max_notes: 3,
                             max_content_length: 150,
                             max_depth: nil)
    overview = structural_overview project_root, file_path, nil, max_depth: max_depth

    # Get all notes related to this file
    notes = Mnemosyne.recall_notes file_path, limit: 50

    # Generate tag cloud and file cloud from notes instead of full note content
    tag_cloud = generate_tag_cloud notes
    file_cloud = generate_file_cloud notes
    
    # Generate hermetic symbolic overview using LexiconResonantia
    symbolic_overview = LexiconResonantia.generate_from_notes(notes)

    # Format for AI consumption - enhanced with hierarchical data
    {
      language:               overview[:language],
      structural_summary:     overview[:summary],
      hierarchy:              overview[:hierarchy],
      imports:                overview[:imports],
      exports:                overview[:exports],
      navigation_hints:       overview[:navigation_hints],
      significant_lines:      (overview[:line_hints] || {}).keys.map(&:to_i).sort,
      tag_cloud:,
      file_cloud:,
      tag_cloud_text:         tag_cloud.map { |tag| "#{tag[0]}: #{tag[1]}" }.join('\n'),
      file_cloud_text:        file_cloud.map { |tag| "#{tag[0]}: #{tag[1]}" }.join('\n'),
      symbolic_overview_text: generate_symbolic_overview_text(overview),
      hermetic_overview:      symbolic_overview.join("\n")
    }
  end


  def self.extract_symbol_names(hierarchy)
    names = []
    hierarchy.each do |item|
      names << item[:name] if item[:name]
      names.concat extract_symbol_names(item[:children])
    end
    names
  end


  def self.generate_symbolic_overview_text(overview)
    # Add hierarchy elements in compact format
    lines = extract_all_elements(overview[:hierarchy]).map do |element|
      "#{'  ' * element[:depth]}#{element[:line]}: #{element[:type][..2]} #{element[:name]}"
    end

    # Add imports
    overview[:imports].each do |import|
      lines << "#{import[:line]}: import #{import[:type]} -> #{import[:target]}"
    end

    # Add exports
    overview[:exports].each do |export|
      lines << "#{export[:line]}: export #{export[:type]}"
    end

    lines.join "\n"
  end


  # Generate tag cloud from notes related to this file
  def self.generate_tag_cloud(notes)
    # Extract and count tags
    tag_counts = Hash.new 0
    notes.each do |note|
      next unless note[:tags]

      tags = note[:tags].is_a?(String) ? note[:tags].split(',') : note[:tags]
      tags.each { |tag| tag_counts[tag.strip] += 1 }
    end

    # Convert to array of [tag, count] sorted by frequency
    tag_counts.sort_by { |_tag, count| -count }
  end


  # Generate file cloud showing related files based on note links
  def self.generate_file_cloud(notes)
    # Extract file links from notes
    file_counts = Hash.new 0
    notes.each do |note|
      next unless note[:links]

      links = note[:links].is_a?(String) ? note[:links].split(',') : note[:links]
      links.each do |link|
        # Only count files, not other types of links
        # if link.include?('/') || link.include?('.') || link.include?('_') || link.include?('-') || link.include?(' ')
          file_counts[link.strip] += 1
        # end
      end
    end

    # Convert to array of [file, count] sorted by frequency
    file_counts.sort_by { |_file, count| -count }
  end


  # Reduce hierarchy depth by truncating nested children beyond max_depth
  def self.reduce_hierarchy_depth(hierarchy, max_depth, current_depth = 1)
    return [] if hierarchy.empty? || current_depth > max_depth

    hierarchy.map do |item|
      if current_depth == max_depth
        # At max depth, remove children but keep the item
        { **item, children: [] }
      else
        # Recursively reduce children depth
        {
          **item,
          children: reduce_hierarchy_depth(item[:children], max_depth, current_depth + 1)
        }
      end
    end
  end
end

# Test the enhanced hierarchical implementation
if __FILE__ == $PROGRAM_NAME
  test_file = __FILE__
  overview = AetherScopesHierarchical.structural_overview test_file

  puts '=== AetherScopesHierarchical Test ==='
  puts "File: #{overview[:file]}"
  puts "Language: #{overview[:language]}"
  puts "Summary: #{overview[:summary]}"

  puts "\nHierarchical Structure:"
  def print_hierarchy(hierarchy, indent = 0)
    hierarchy.each do |item|
      puts ('  ' * indent) + "#{item[:type]} #{item[:name]} @ line #{item[:line]} (#{item[:level]})"
      print_hierarchy item[:children], indent + 1
    end
  end
  print_hierarchy overview[:hierarchy]

  puts "\nImports:"
  overview[:imports].each { |imp| puts "  #{imp[:type]} -> #{imp[:target]} @ line #{imp[:line]}" }

  puts "\nExports:"
  overview[:exports].each { |exp| puts "  #{exp[:type]} @ line #{exp[:line]}" }

  puts "\nNavigation Hints:"
  overview[:navigation_hints].each do |hint|
    puts "  Line #{hint[:line]}: #{hint[:description]}"
  end
end
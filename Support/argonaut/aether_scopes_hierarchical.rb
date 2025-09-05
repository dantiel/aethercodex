# AETHER SCOPES HIERARCHICAL - Enhanced Symbolic Analysis Engine
# Language-agnostic hierarchical parsing with import/export tracking

# Language-agnostic hierarchical symbolic analysis

module AetherScopesHierarchical
  # Language-specific patterns for hierarchical analysis
  LANGUAGE_PATTERNS = {
    # Ruby patterns
    ruby: {
      hierarchy: [
        {type: :module, pattern: /^\s*module\s+(\w+)/, level: :container},
        {type: :class, pattern: /^\s*class\s+(\w+)/, level: :container},
        {type: :method, pattern: /^\s*def\s+(\w+)/, level: :member},
        {type: :singleton_method, pattern: /^\s*def\s+self\.(\w+)/, level: :member},
        {type: :constant, pattern: /^\s*([A-Z][A-Z0-9_]*)\s*=/, level: :member}
      ],
      imports: [
        {type: :require, pattern: /^\s*require\s+['"]([^'"]+)['"]/},
        {type: :require_relative, pattern: /^\s*require_relative\s+['"]([^'"]+)['"]/},
        {type: :load, pattern: /^\s*load\s+['"]([^'"]+)['"]/}
      ],
      exports: [
        {type: :module_function, pattern: /^\s*module_function/},
        {type: :public, pattern: /^\s*public/},
        {type: :private, pattern: /^\s*private/}
      ]
    },
    
    # JavaScript patterns
    javascript: {
      hierarchy: [
        {type: :class, pattern: /^\s*class\s+(\w+)/, level: :container},
        {type: :function, pattern: /^\s*function\s+(\w+)/, level: :member},
        {type: :arrow_function, pattern: /^\s*const\s+(\w+)\s*=\s*\([^)]*\)\s*=>/, level: :member},
        {type: :const, pattern: /^\s*const\s+(\w+)\s*=/, level: :member},
        {type: :let, pattern: /^\s*let\s+(\w+)\s*=/, level: :member},
        {type: :var, pattern: /^\s*var\s+(\w+)\s*=/, level: :member}
      ],
      imports: [
        {type: :import, pattern: /^\s*import\s+(?:[^'"\n]+from\s+)?['"]([^'"]+)['"]/},
        {type: :require, pattern: /^\s*const\s+\w+\s*=\s*require\(['"]([^'"]+)['"]\)/}
      ],
      exports: [
        {type: :export, pattern: /^\s*export\s+(?:default\s+)?(?:class|function|const|let|var)/},
        {type: :module_exports, pattern: /^\s*module\.exports\s*=/}
      ]
    },
    
    # Python patterns
    python: {
      hierarchy: [
        {type: :class, pattern: /^\s*class\s+(\w+)/, level: :container},
        {type: :function, pattern: /^\s*def\s+(\w+)/, level: :member},
        {type: :async_function, pattern: /^\s*async\s+def\s+(\w+)/, level: :member}
      ],
      imports: [
        {type: :import, pattern: /^\s*import\s+(\w+)/},
        {type: :from_import, pattern: /^\s*from\s+(\w+)\s+import/}
      ],
      exports: [
        {type: :__all__, pattern: /^\s*__all__\s*=/}
      ]
    },
    
    # HTML patterns
    html: {
      hierarchy: [
        {type: :element, pattern: /<([\w:-]+)/, level: :container},
        {type: :id, pattern: /id=['"]([^'"]+)['"]/, level: :attribute},
        {type: :class, pattern: /class=['"]([^'"]+)['"]/, level: :attribute}
      ],
      imports: [
        {type: :link, pattern: /<link[^>]*href=['"]([^'"]+)['"]/},
        {type: :script, pattern: /<script[^>]*src=['"]([^'"]+)['"]/}
      ],
      exports: []
    },
    
    # CSS patterns
    css: {
      hierarchy: [
        {type: :selector, pattern: /^([^{]+)\{/, level: :container},
        {type: :at_rule, pattern: /^@(\w+)/, level: :directive}
      ],
      imports: [
        {type: :import, pattern: /@import\s+(?:url\()?['"]([^'"]+)['"]/}
      ],
      exports: []
    }
  }.freeze

  # Scope levels for hierarchical organization
  SCOPE_LEVELS = {
    container: 1,  # Modules, classes, functions that contain other elements
    member: 2,     # Methods, constants, variables within containers
    attribute: 3,  # HTML attributes, CSS properties
    directive: 4   # Import/export directives, at-rules
  }.freeze

  class HierarchicalParser
    def initialize(content, language = nil)
      @content = content
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
        parse_hierarchy(line, line_number)
        
        # Parse imports and exports
        parse_imports(line, line_number)
        parse_exports(line, line_number)
      end
      
      {
        language: @language,
        hierarchy: @hierarchy,
        imports: @imports,
        exports: @exports,
        structure: analyze_structure
      }
    end

    private

    def detect_language(content)
      # Enhanced language detection - prioritize programming languages over HTML in comments
      lines = content.lines
      
      # Check first 20 lines for language signatures
      sample = lines[0..19].join
      
      case sample
      when /^\s*class\s+\w+.*:\s*$/ then :python
      when /^\s*function\s+\w+|^\s*const\s+\w+\s*=|^\s*let\s+\w+\s*=/ then :javascript
      when /^\s*def\s+\w+|^\s*class\s+\w+|^\s*module\s+\w+/ then :ruby
      when /@import|^[^{]*\{[^}]*\}/ then :css
      when /<html|<!DOCTYPE/i then :html
      else
        # Fallback: check file extension or overall content
        :ruby # Default to Ruby for this codebase
      end
    end

    def parse_hierarchy(line, line_number)
      patterns = LANGUAGE_PATTERNS[@language]&.[](:hierarchy) || []
      
      patterns.each do |pattern|
        if match = line.match(pattern[:pattern])
          element = {
            type: pattern[:type],
            name: match[1],
            line: line_number,
            level: pattern[:level],
            children: []
          }
          
          # Add to hierarchy with proper nesting
          add_to_hierarchy(element)
          break
        end
      end
    end

    def add_to_hierarchy(element)
      level_weight = SCOPE_LEVELS[element[:level]] || 99
      
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
      
      # Push to current scope if it's a container
      @current_scope << element if element[:level] == :container
    end

    def parse_imports(line, line_number)
      patterns = LANGUAGE_PATTERNS[@language]&.[](:imports) || []
      
      patterns.each do |pattern|
        if match = line.match(pattern[:pattern])
          @imports << {
            type: pattern[:type],
            target: match[1],
            line: line_number
          }
          break
        end
      end
    end

    def parse_exports(line, line_number)
      patterns = LANGUAGE_PATTERNS[@language]&.[](:exports) || []
      
      patterns.each do |pattern|
        if match = line.match(pattern[:pattern])
          @exports << {
            type: pattern[:type],
            line: line_number
          }
          break
        end
      end
    end

    def analyze_structure
      {
        total_lines: @lines.size,
        significant_lines: @hierarchy.size + @imports.size + @exports.size,
        import_count: @imports.size,
        export_count: @exports.size,
        symbol_count: count_symbols(@hierarchy)
      }
    end

    def count_symbols(hierarchy)
      count = hierarchy.size
      hierarchy.each { |item| count += count_symbols(item[:children]) }
      count
    end
  end

  # Main API for file overview integration - hierarchical and language-aware
  def self.structural_overview(file_path, content = nil)
    content ||= (File.read(file_path) if file_path && File.exist?(file_path))
    return empty_analysis unless content
    
    parser = HierarchicalParser.new(content)
    analysis = parser.parse
    
    {
      file: file_path,
      language: analysis[:language],
      hierarchy: analysis[:hierarchy],
      imports: analysis[:imports],
      exports: analysis[:exports],
      structure: analysis[:structure],
      summary: generate_summary(analysis),
      line_hints: generate_line_hints(analysis),
      navigation_hints: generate_navigation_hints(analysis)
    }
  end

  def self.generate_summary(analysis)
    {
      language: analysis[:language],
      containers: count_by_type(analysis[:hierarchy], [:container]),
      members: count_by_type(analysis[:hierarchy], [:member, :attribute, :directive]),
      imports: analysis[:imports].size,
      exports: analysis[:exports].size,
      total_symbols: analysis[:structure][:symbol_count]
    }
  end

  def self.count_by_type(hierarchy, types)
    count = 0
    hierarchy.each do |item|
      count += 1 if types.include?(item[:level])
      count += count_by_type(item[:children], types)
    end
    count
  end

  def self.generate_line_hints(analysis)
    hints = {}
    
    # Add hierarchy elements
    extract_all_elements(analysis[:hierarchy]).each do |element|
      hints[element[:line].to_s] ||= []
      hints[element[:line].to_s] << "#{element[:type]}: #{element[:name]}"
    end
    
    # Add imports and exports
    (analysis[:imports] + analysis[:exports]).each do |item|
      hints[item[:line].to_s] ||= []
      desc = item[:target] ? "#{item[:type]} -> #{item[:target]}" : item[:type]
      hints[item[:line].to_s] << desc
    end
    
    hints.sort.to_h
  end

  def self.generate_navigation_hints(analysis)
    hints = []
    
    # Hierarchy navigation
    extract_all_elements(analysis[:hierarchy]).each do |element|
      hints << {
        type: :structure,
        target: "#{element[:type]}:#{element[:name]}",
        line: element[:line],
        level: element[:level],
        description: "Navigate to #{element[:type]} #{element[:name]}"
      }
    end
    
    # Import navigation
    analysis[:imports].each do |import|
      hints << {
        type: :dependency,
        target: import[:target],
        line: import[:line],
        description: "Import: #{import[:type]} -> #{import[:target]}"
      }
    end
    
    # Export navigation
    analysis[:exports].each do |export|
      hints << {
        type: :export,
        target: "export",
        line: export[:line],
        description: "Export: #{export[:type]}"
      }
    end
    
    hints.sort_by { |h| h[:line] }
  end

  def self.extract_all_elements(hierarchy)
    elements = []
    hierarchy.each do |item|
      elements << item
      elements.concat(extract_all_elements(item[:children]))
    end
    elements
  end

  def self.empty_analysis
    {
      language: :unknown,
      hierarchy: [],
      imports: [],
      exports: [],
      structure: {
        total_lines: 0,
        significant_lines: 0,
        import_count: 0,
        export_count: 0,
        symbol_count: 0
      }
    }
  end

  # Enhanced integration with file_overview tool - hierarchical and language-aware
  def self.for_file_overview(file_path, max_notes: 3, max_content_length: 150)
    overview = structural_overview(file_path)
    
    # Get relevant notes based on hierarchical structure
    symbol_names = extract_symbol_names(overview[:hierarchy])
    
    # Get relevant notes with content length limits
    notes = if symbol_names.any?
              # Search for notes related to symbols found in the file
              symbol_names.flat_map do |symbol|
                Mnemosyne.recall_notes(symbol, limit: 2, max_content_length: max_content_length)
              end.uniq { |note| note[:id] }
            else
              # Fallback to file-based notes
              Mnemosyne.recall_notes(file_path, limit: max_notes, max_content_length: max_content_length)
            end
    
    # Format for AI consumption - enhanced with hierarchical data
    {
      language: overview[:language],
      structural_summary: overview[:summary],
      hierarchy: overview[:hierarchy],
      imports: overview[:imports],
      exports: overview[:exports],
      navigation_hints: overview[:navigation_hints],
      significant_lines: overview[:line_hints].keys.map(&:to_i).sort,
      relevant_notes: notes.map { |note|
        {
          id: note[:id],
          content: note[:content],
          tags: note[:tags]
        }
      }
    }
  end

  def self.extract_symbol_names(hierarchy)
    names = []
    hierarchy.each do |item|
      names << item[:name] if item[:name]
      names.concat(extract_symbol_names(item[:children]))
    end
    names
  end
end

# Test the enhanced hierarchical implementation
if $0 == __FILE__ 
  test_file = __FILE__
  overview = AetherScopesHierarchical.structural_overview(test_file)
  
  puts "=== AetherScopesHierarchical Test ==="
  puts "File: #{overview[:file]}"
  puts "Language: #{overview[:language]}"
  puts "Summary: #{overview[:summary]}"
  
  puts "\nHierarchical Structure:"
  def print_hierarchy(hierarchy, indent = 0)
    hierarchy.each do |item|
      puts "  " * indent + "#{item[:type]} #{item[:name]} @ line #{item[:line]} (#{item[:level]})"
      print_hierarchy(item[:children], indent + 1)
    end
  end
  print_hierarchy(overview[:hierarchy])
  
  puts "\nImports:"
  overview[:imports].each { |imp| puts "  #{imp[:type]} -> #{imp[:target]} @ line #{imp[:line]}" }
  
  puts "\nExports:"
  overview[:exports].each { |exp| puts "  #{exp[:type]} @ line #{exp[:line]}" }
  
  puts "\nNavigation Hints:"
  overview[:navigation_hints].each do |hint|
    puts "  Line #{hint[:line]}: #{hint[:description]}"
  end
end
# AETHER SCOPES - Hierarchical Symbolic Analysis Engine
# Language-agnostic structural parsing with import/export tracking

require 'textpow'
require 'json'

module AetherScopes
  class SymbolicAnalyzer
    # Scope levels for hierarchical organization
    SCOPE_LEVELS = {
      container: 1, # Modules, classes, functions that contain other elements
      member:    2, # Methods, constants within containers
      variable:  3, # Variables (instance, class, local, global)
      attribute: 4,  # HTML attributes, CSS properties
      directive: 5   # Import/export directives, at-rules
    }.freeze

    def initialize
      @grammar_cache = {}
      @language_patterns = load_language_patterns
    end

    # Main analysis method - returns hierarchical structure
    def analyze_file_content(content, language = nil)
      return empty_analysis unless content
      
      language ||= detect_language(content)
      parse_tree = build_parse_tree(content, language)
      
      {
        language: language,
        hierarchy: extract_hierarchy(parse_tree, language),
        imports: extract_imports(parse_tree, language),
        exports: extract_exports(parse_tree, language),
        symbols: extract_symbols(parse_tree, language),
        structure: analyze_structure(parse_tree, language)
      }
    end

    private

    def load_language_patterns
      {
        # Ruby patterns
        ruby: {
          hierarchy: [
            {type: :module, pattern: /^\s*module\s+(\w+)/, level: :container},
            {type: :class, pattern: /^\s*class\s+(\w+)/, level: :container},
            {type: :singleton_method, pattern: /^\s*def\s+self\.(\w+)/, level: :member},
            {type: :method, pattern: /^\s*def\s+(\w+)/, level: :member},
            {type: :constant, pattern: /^\s*([A-Z][A-Z0-9_]*)\s*=/, level: :member},
            {type: :instance_variable, pattern: /^\s*@(\w+)\s*=/, level: :variable, parent_scope: true},
            {type: :class_variable, pattern: /^\s*@@(\w+)\s*=/, level: :variable, parent_scope: true},
            {type: :global_variable, pattern: /^\s*\$(\w+)\s*=/, level: :variable, parent_scope: true},
            {type: :local_variable, pattern: /^\s*(\w+)\s*=[^=>]*$/, level: :variable, parent_scope: true}
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
            {type: :class, pattern: /^\s*class\s+(\w+)/},
            {type: :function, pattern: /^\s*function\s+(\w+)/},
            {type: :const, pattern: /^\s*const\s+(\w+)\s*=/},
            {type: :let, pattern: /^\s*let\s+(\w+)\s*=/},
            {type: :var, pattern: /^\s*var\s+(\w+)\s*=/}
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
            {type: :class, pattern: /^\s*class\s+(\w+)/},
            {type: :function, pattern: /^\s*def\s+(\w+)/},
            {type: :async_function, pattern: /^\s*async\s+def\s+(\w+)/}
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
            {type: :element, pattern: /<([\w:-]+)/},
            {type: :id, pattern: /id=['"]([^'"]+)['"]/},
            {type: :class, pattern: /class=['"]([^'"]+)['"]/}
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
            {type: :selector, pattern: /^([^{]+)\{/},
            {type: :at_rule, pattern: /^@(\w+)/}
          ],
          imports: [
            {type: :import, pattern: /@import\s+(?:url\()?['"]([^'"]+)['"]/}
          ],
          exports: []
        }
      }
    end

    def detect_language(content)
      # Simple language detection based on content patterns
      case content
      when /<html|<!DOCTYPE/i then :html
      when /^\s*class\s+\w+.*:\s*$/ then :python
      when /^\s*function\s+\w+|^\s*const\s+\w+\s*=|^\s*let\s+\w+\s*=/ then :javascript
      when /^\s*def\s+\w+|^\s*class\s+\w+|^\s*module\s+\w+/ then :ruby
      when /@import|^[^{]*\{[^}]*\}/ then :css
      else :unknown
      end
    end

    def build_parse_tree(content, language)
      # Use TextMate grammar parsing for detailed analysis
      grammar = load_grammar(language)
      return simple_line_analysis(content, language) unless grammar
      
      # Detailed parsing with TextMate grammar
      parse_tree = []
      processor = TextPow::RecordingProcessor.new
      
      begin
        grammar.parse(content, processor)
        parse_tree = processor.recorded
      rescue => e
        # Fallback to simple analysis
        parse_tree = simple_line_analysis(content, language)
      end
      
      parse_tree
    end

    def load_grammar(language)
      return nil unless @grammar_cache[language]
      # Load appropriate TextMate grammar for language
      # Implementation would load from TextMate bundle grammars
      nil # Placeholder - actual implementation would return grammar
    end

    def simple_line_analysis(content, language)
      # Fallback line-based analysis
      lines = content.lines
      patterns = @language_patterns[language] || {}
      
      lines.map.with_index do |line, index|
        analyze_line(line, index + 1, patterns)
      end.compact
    end

    def analyze_line(line, line_number, patterns)
      result = {line: line_number, content: line.chomp}
      
      # Check for hierarchy patterns
      patterns[:hierarchy]&.each do |pattern|
        next unless (match = line.match pattern[:pattern])
        
        # Handle special cases for naming
        name = match[1]
        
        # Fix singleton method names (extract just the method name from "self.method_name")
        if pattern[:type] == :singleton_method && name.start_with?('self.')
          name = name.sub('self.', '')
        end
        
        # Fix method names that capture "self" instead of actual method name
        if pattern[:type] == :method && name == "self"
          # This happens when we match "def self.class_method" as a regular method
          # Try to extract the actual method name from the line
          if (method_match = line.match(/^\s*def\s+self\.(\w+)/))
            name = method_match[1]
            result[:type] = :singleton_method
          else
            result[:type] = pattern[:type]
          end
        else
          result[:type] = pattern[:type]
        end
        
        result[:name] = name if name
        break
      end
      
      # Check for import patterns
      patterns[:imports]&.each do |pattern|
        if match = line.match(pattern[:pattern])
          result[:import] = {type: pattern[:type], target: match[1]}
          break
        end
      end
      
      # Check for export patterns
      patterns[:exports]&.each do |pattern|
        if match = line.match(pattern[:pattern])
          result[:export] = {type: pattern[:type]}
          break
        end
      end
      
      result if result.key?(:type) || result.key?(:import) || result.key?(:export)
    end

    def extract_hierarchy(parse_tree, language)
      # Build hierarchical structure from parse tree with proper nesting
      hierarchy = []
      current_scope = []
      
      parse_tree.each do |node|
        next unless node[:type]
        
        # Get level weight for this element
        pattern = @language_patterns[language]&.[](:hierarchy)&.find { |p| p[:type] == node[:type] }
        level_weight = pattern ? SCOPE_LEVELS[pattern[:level]] || 99 : 99
        
        hierarchy_node = {
          type: node[:type],
          name: node[:name],
          line: node[:line],
          children: []
        }
        
        # Add level and parent_scope if pattern exists
        if pattern
          hierarchy_node[:level] = pattern[:level]
          hierarchy_node[:parent_scope] = pattern[:parent_scope] if pattern.key?(:parent_scope)
        end

        # Variables should be children of the current method/scope
        if pattern && pattern[:parent_scope] && !current_scope.empty?
          current_scope.last[:children] << hierarchy_node
          next
        end

        # Find appropriate parent based on scope level
        while !current_scope.empty? &&
              SCOPE_LEVELS[current_scope.last[:level]] >= level_weight
          current_scope.pop
        end

        if current_scope.empty?
          hierarchy << hierarchy_node
        else
          current_scope.last[:children] << hierarchy_node
        end

        # Push to current scope if it's a container or member (methods)
        if [:container, :member].include?(pattern[:level])
          current_scope << hierarchy_node
        end
      end
      
      hierarchy
    end

    def extract_imports(parse_tree, language)
      parse_tree.select { |node| node[:import] }
                .map { |node| node[:import].merge(line: node[:line]) }
    end

    def extract_exports(parse_tree, language)
      parse_tree.select { |node| node[:export] }
                .map { |node| node[:export].merge(line: node[:line]) }
    end

    def extract_symbols(parse_tree, language)
      parse_tree.select { |node| node[:type] && node[:name] }
                .map { |node| {type: node[:type], name: node[:name], line: node[:line]} }
    end

    def analyze_structure(parse_tree, language)
      {
        total_lines: parse_tree.map { |n| n[:line] }.max || 0,
        significant_lines: parse_tree.size,
        import_count: extract_imports(parse_tree, language).size,
        export_count: extract_exports(parse_tree, language).size,
        symbol_count: extract_symbols(parse_tree, language).size,
        containers: extract_symbols(parse_tree, language).count { |s| s[:type].to_s.end_with?('class', 'module') },
        members: extract_symbols(parse_tree, language).count { |s| s[:type].to_s.end_with?('method', 'function', 'constant') },
        variables: extract_symbols(parse_tree, language).count { |s| s[:type].to_s.end_with?('variable') }
      }
    end

    def empty_analysis
      {
        language: :unknown,
        hierarchy: [],
        imports: [],
        exports: [],
        symbols: [],
        structure: {
          total_lines: 0,
          significant_lines: 0,
          import_count: 0,
          export_count: 0,
          symbol_count: 0
        }
      }
    end
  end

  # Singleton instance
  def self.analyzer
    @analyzer ||= SymbolicAnalyzer.new
  end

  def self.analyze(content, language = nil)
    analyzer.analyze_file_content(content, language)
  end
end
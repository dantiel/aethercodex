# Enhanced AetherScopes for practical file overview integration
# Focuses on extracting meaningful structural information without full parsing

require 'textpow'
require 'plist'
require 'yaml'

module AetherScopesEnhanced
  # Focus on high-level structural elements
  STRUCTURAL_SCOPES = {
    class: ['entity.name.class', 'entity.name.type.definition'],
    module: ['entity.name.module', 'entity.name.namespace'],
    function: ['entity.name.function', 'entity.name.function.definition'],
    method: ['entity.name.method', 'entity.name.method.definition'],
    constant: ['constant.other', 'constant.language'],
    variable: ['variable.other', 'variable.parameter', 'variable.function']
  }.freeze

  CONTAINER_SCOPES = [
    'meta.class', 'meta.module', 'meta.function', 'meta.method',
    'meta.block', 'meta.definition'
  ].freeze

  class SimpleParser
    def initialize(text, grammar_path = nil)
      @text = text
      @grammar = grammar_path ? Textpow::SyntaxNode.load(grammar_path) : Textpow.syntax('source.ruby')
      @lines = text.split("\n")
      @symbols = {}
    end

    def parse
      # Simple line-by-line scanning for structural patterns
      # This avoids complex grammar parsing issues
      
      @lines.each_with_index do |line, index|
        line_number = index + 1
        
        # Look for class definitions
        if line.match(/^\s*class\s+([A-Z]\w*)/)
          add_symbol(:class, $1, line_number, 1)
        
        # Look for module definitions
        elsif line.match(/^\s*module\s+([A-Z]\w*)/)
          add_symbol(:module, $1, line_number, 1)
        
        # Look for method definitions
        elsif line.match(/^\s*def\s+(?:self\.)?([a-z_]\w*)/)
          add_symbol(:method, $1, line_number, 1)
        
        # Look for constants
        elsif line.match(/^\s*([A-Z][A-Z0-9_]*)\s*=/)
          add_symbol(:constant, $1, line_number, 1)
        
        # Look for instance variables
        elsif line.match(/@[a-z_]\w*/)
          matches = line.scan(/@[a-z_]\w*/)
          matches.each { |var| add_symbol(:variable, var, line_number, line.index(var) || 1) }
        end
      end
      
      @symbols
    end

    private

    def add_symbol(type, name, line, column)
      @symbols[type] ||= []
      @symbols[type] << {
        name: name,
        line: line,
        column: column,
        type: type
      }
    end
  end

  # Main API for file overview integration
  def self.structural_overview(file_path, content = nil)
    content ||= File.read(file_path) if File.exist?(file_path)
    return {} unless content
    
    parser = SimpleParser.new(content)
    symbols = parser.parse
    
    {
      file: file_path,
      summary: generate_summary(symbols),
      symbols: symbols,
      line_hints: generate_line_hints(symbols),
      structural_map: generate_structural_map(symbols)
    }
  end

  def self.generate_summary(symbols)
    {
      classes: symbols[:class]&.size || 0,
      modules: symbols[:module]&.size || 0,
      methods: symbols[:method]&.size || 0,
      constants: symbols[:constant]&.size || 0,
      variables: symbols[:variable]&.size || 0
    }
  end

  def self.generate_line_hints(symbols)
    hints = {}
    
    symbols.each do |type, symbol_list|
      symbol_list.each do |symbol|
        hints[symbol[:line].to_s] ||= []
        hints[symbol[:line].to_s] << "#{type}: #{symbol[:name]}"
      end
    end
    
    hints.sort.to_h
  end

  def self.generate_structural_map(symbols)
    # Group by type for easy navigation
    structural_map = {}
    
    symbols.each do |type, symbol_list|
      structural_map[type] = symbol_list.map do |symbol|
        {
          name: symbol[:name],
          line: symbol[:line],
          column: symbol[:column]
        }
      end
    end
    
    structural_map
  end

  # Integration with file_overview tool - optimized for minimal context usage
  def self.for_file_overview(file_path, max_notes: 3, max_content_length: 150)
    overview = structural_overview(file_path)
    
    # Get relevant notes with content length limits
    notes = Mnemosyne.recall_notes(file_path, limit: max_notes, max_content_length: max_content_length)
    
    # Format for AI consumption - minimal, focused data
    {
      structural_summary: overview[:summary],
      navigation_hints: overview[:line_hints],
      significant_lines: overview[:line_hints].keys.sort,
      symbols_by_type: overview[:structural_map],
      relevant_notes: notes.map { |note|
        {
          id: note[:id],
          content: note[:content],
          tags: note[:tags]
        }
      }
    }
  end
end

# Test the enhanced implementation
if __FILE__ == $0
  test_file = __FILE__
  overview = AetherScopesEnhanced.structural_overview(test_file)
  
  puts "=== AetherScopesEnhanced Test ==="
  puts "File: #{overview[:file]}"
  puts "Summary: #{overview[:summary]}"
  
  puts "\nStructural Map:"
  overview[:structural_map].each do |type, symbols|
    next if symbols.empty?
    puts "  #{type.capitalize}:"
    symbols.each { |s| puts "    #{s[:name]} @ line #{s[:line]}" }
  end
  
  puts "\nLine Hints:"
  overview[:line_hints].each do |line, hints|
    puts "  Line #{line}: #{hints.join(', ')}"
  end
end
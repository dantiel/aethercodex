# Simple symbolic parser for file overview - no external dependencies

module SimpleScopes
  # Main API for file overview integration
  def self.structural_overview(file_path, content = nil)
    content ||= File.read(file_path) if File.exist?(file_path)
    return {} unless content
    
    lines = content.split("\n")
    symbols = extract_symbols(lines)
    
    {
      file: file_path,
      summary: generate_summary(symbols),
      symbols: symbols,
      line_hints: generate_line_hints(symbols),
      structural_map: generate_structural_map(symbols)
    }
  end

  def self.extract_symbols(lines)
    symbols = {classes: [], modules: [], methods: [], constants: [], variables: []}
    
    lines.each_with_index do |line, index|
      line_number = index + 1
      
      # Look for class definitions (Ruby)
      if line.match(/^\s*class\s+([A-Z]\w*)/)
        symbols[:classes] << {name: $1, line: line_number, column: line.index($1) || 1}
      
      # Look for module definitions (Ruby)
      elsif line.match(/^\s*module\s+([A-Z]\w*)/)
        symbols[:modules] << {name: $1, line: line_number, column: line.index($1) || 1}
      
      # Look for method definitions (Ruby)
      elsif line.match(/^\s*def\s+(?:self\.)?([a-z_]\w*)/)
        symbols[:methods] << {name: $1, line: line_number, column: line.index($1) || 1}
      
      # Look for constants (Ruby)
      elsif line.match(/^\s*([A-Z][A-Z0-9_]*)\s*=/)
        symbols[:constants] << {name: $1, line: line_number, column: line.index($1) || 1}
      
      # Look for instance variables (Ruby)
      elsif line.match(/@[a-z_]\w*/)
        matches = line.scan(/@[a-z_]\w*/)
        matches.each { |var| symbols[:variables] << {name: var, line: line_number, column: line.index(var) || 1} }
      
      # Look for function definitions (JavaScript/CoffeeScript)
      elsif line.match(/^\s*function\s+([a-zA-Z_$][\w$]*)/)
        symbols[:methods] << {name: $1, line: line_number, column: line.index($1) || 1}
      
      # Look for const/let/var declarations (JavaScript)
      elsif line.match(/^\s*(?:const|let|var)\s+([a-zA-Z_$][\w$]*)/)
        symbols[:variables] << {name: $1, line: line_number, column: line.index($1) || 1}
      
      # Look for class definitions (JavaScript)
      elsif line.match(/^\s*class\s+([A-Z][\w$]*)/)
        symbols[:classes] << {name: $1, line: line_number, column: line.index($1) || 1}
      
      # Look for Python class definitions
      elsif line.match(/^\s*class\s+([A-Za-z_][A-Za-z0-9_]*)/)
        symbols[:classes] << {name: $1, line: line_number, column: line.index($1) || 1}
      
      # Look for Python function definitions
      elsif line.match(/^\s*def\s+([a-z_][a-z0-9_]*)/)
        symbols[:methods] << {name: $1, line: line_number, column: line.index($1) || 1}
      end
    end
    
    symbols
  end

  def self.generate_summary(symbols)
    {
      classes: symbols[:classes].size,
      modules: symbols[:modules].size,
      methods: symbols[:methods].size,
      constants: symbols[:constants].size,
      variables: symbols[:variables].size
    }
  end

  def self.generate_line_hints(symbols)
    hints = {}
    
    symbols.each do |type, symbol_list|
      symbol_list.each do |symbol|
        hints["#{symbol[:line]}"] ||= []
        hints["#{symbol[:line]}"] << "#{singularize(type.to_s)}: #{symbol[:name]}"
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

  # Simple singularization
  def self.singularize(word)
    case word
    when 'classes' then 'class'
    when 'modules' then 'module' 
    when 'methods' then 'method'
    when 'constants' then 'constant'
    when 'variables' then 'variable'
    else word
    end
  end

  # Integration with file_overview tool
  def self.for_file_overview(file_path)
    overview = structural_overview(file_path)
    
    # Format for AI consumption
    {
      structural_summary: overview[:summary],
      navigation_hints: overview[:line_hints],
      significant_lines: overview[:line_hints].keys.sort,
      symbols_by_type: overview[:structural_map]
    }
  end
end

# Test the simple implementation
if __FILE__ == $0
  test_file = __FILE__
  overview = SimpleScopes.structural_overview(test_file)
  
  puts "=== SimpleScopes Test ==="
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
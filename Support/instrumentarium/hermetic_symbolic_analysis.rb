# frozen_string_literal: true

require 'open3'
require 'json'
require_relative 'hermetic_execution_domain'
require_relative '../argonaut/argonaut'

# Hermetic Symbolic Analysis Engine
# AST-GREP powered semantic analysis with hermetic symbolic patterns
module HermeticSymbolicAnalysis
  extend self

  # Elemental patterns - fundamental code transformations
  ELEMENTAL_PATTERNS = {
    fire: { description: "Transformative operations - method/class modifications", pattern: "def $METHOD; end" },
    water: { description: "Flow operations - control structures and data flow", pattern: "if $COND; $$$; else; $$$; end" },
    earth: { description: "Structural operations - class/module definitions", pattern: "class $CLASS; end" },
    air: { description: "Abstract operations - imports, requires, dependencies", pattern: "require $LIBRARY" }
  }

  # Planetary patterns - higher-level code semantics
  PLANETARY_PATTERNS = {
    solar: { description: "Core logic - main execution paths", pattern: "def $METHOD; end" },
    lunar: { description: "Reflective operations - metaprogramming, introspection", pattern: "define_method $SYMBOL; end" },
    mercurial: { description: "Communication patterns - API calls, IO operations", pattern: "$METHOD($$ARGS)" }
  }

  # Alchemical patterns - transformation stages
  ALCHEMICAL_PATTERNS = {
    nigredo: { description: "Analysis patterns - finding what needs transformation", pattern: "# TODO: $NOTE" },
    albedo: { description: "Purification patterns - cleaning and refactoring", pattern: "# FIXME: $NOTE" },
    citrinitas: { description: "Illumination patterns - documentation and clarity", pattern: "# NOTE: $NOTE" }
  }

  # Execute AST-GREP command with hermetic execution domain
  def ast_grep_execute(command_args, pattern: nil, rewrite: nil, lang: nil)
    HermeticExecutionDomain.execute do
      args = ['ast-grep', 'run']
      
      if pattern
        args += ['--pattern', pattern]
      end
      
      if rewrite
        args += ['--rewrite', rewrite]
      end
      
      if lang
        args += ['--lang', lang]
      end
      
      # Resolve file paths relative to project root like other tools
      resolved_args = command_args.map do |arg|
        if arg.end_with?('.rb') || arg.end_with?('.js') || arg.end_with?('.py') ||
           arg.end_with?('.java') || arg.end_with?('.go') || arg.end_with?('.rs') ||
           arg.end_with?('.php') || arg.end_with?('.html') || arg.end_with?('.css') ||
           arg.end_with?('.xml') || arg.end_with?('.json') || arg.end_with?('.yml') ||
           arg.end_with?('.yaml') || arg.end_with?('.md')
          File.join(Argonaut.project_root, arg)
        else
          arg
        end
      end
      
      # First get the transformation data with --json
      json_args = args.dup
      json_args << '--json'
      json_args += resolved_args
      
      stdout, stderr, status = Open3.capture3(*json_args)
      
      if status.success?
        transformation_data = parse_ast_grep_output(stdout)
        
        # If we have a rewrite operation, actually apply the changes
        if rewrite && !transformation_data.empty?
          apply_args = args.dup
          apply_args += ['--update-all']
          apply_args += resolved_args
          
          apply_stdout, apply_stderr, apply_status = Open3.capture3(*apply_args)
          
          unless apply_status.success?
            return { error: apply_stderr, status: apply_status.exitstatus }
          end
        end
        
        { success: true, result: transformation_data }
      else
        { error: stderr, status: status.exitstatus }
      end
    end
  end

  # Parse AST-GREP JSON output
  def parse_ast_grep_output(output)
    return [] if output.strip.empty?
    
    begin
      JSON.parse(output, symbolize_names: true)
    rescue JSON::ParserError
      # Fallback for non-JSON output (e.g., plain text matches)
      output.lines.map { |line| { match: line.strip } }
    end
  end

  # Find patterns in code using AST-GREP
  def find_patterns(file_path, pattern, lang: nil)
    ast_grep_execute([file_path], pattern: pattern, lang: lang)
  end

  # Find individual methods and classes with precise AST matching
  def find_methods(file_path, lang: nil)
    ast_grep_execute([file_path, '--json'], pattern: 'def $METHOD; end', lang: lang)
  end

  def find_classes(file_path, lang: nil)
    ast_grep_execute([file_path, '--json'], pattern: 'class $CLASS; end', lang: lang)
  end

  def find_modules(file_path, lang: nil)
    ast_grep_execute([file_path, '--json'], pattern: 'module $MODULE; end', lang: lang)
  end

  # Semantic search across multiple files
  def semantic_search(directory, pattern, lang: nil)
    ast_grep_execute([directory, '--json=stream'], pattern: pattern, lang: lang)
  end

  # Apply semantic rewrite
  def semantic_rewrite(file_path, pattern, rewrite, lang: nil)
    ast_grep_execute([file_path], pattern: pattern, rewrite: rewrite, lang: lang)
  end

  # Extract hermetic symbols from code
  def extract_hermetic_symbols(file_path, lang: nil)
    symbols = {}
    
    # Extract elemental patterns
    ELEMENTAL_PATTERNS.each do |element, config|
      result = find_patterns(file_path, config[:pattern], lang: lang)
      symbols[element] = result[:success] ? result[:result] : []
    end
    
    # Extract planetary patterns
    PLANETARY_PATTERNS.each do |planet, config|
      result = find_patterns(file_path, config[:pattern], lang: lang)
      symbols[planet] = result[:success] ? result[:result] : []
    end
    
    # Extract alchemical patterns
    ALCHEMICAL_PATTERNS.each do |stage, config|
      result = find_patterns(file_path, config[:pattern], lang: lang)
      symbols[stage] = result[:success] ? result[:result] : []
    end
    
    # Extract precise structural elements
    symbols[:methods] = find_methods(file_path, lang: lang)[:result] || []
    symbols[:classes] = find_classes(file_path, lang: lang)[:result] || []
    symbols[:modules] = find_modules(file_path, lang: lang)[:result] || []
    
    symbols
  end

  # Language detection based on file extension
  def detect_language(file_path)
    case File.extname(file_path)
    when '.rb' then 'ruby'
    when '.js', '.jsx', '.ts', '.tsx' then 'javascript'
    when '.py' then 'python'
    when '.java' then 'java'
    when '.go' then 'go'
    when '.rs' then 'rust'
    when '.php' then 'php'
    when '.html', '.htm' then 'html'
    when '.css' then 'css'
    when '.xml' then 'xml'
    when '.json' then 'json'
    when '.yml', '.yaml' then 'yaml'
    else 'text'
    end
  end

  # Forecast symbolic operations based on patterns found
  def forecast_operations(file_path, lang: nil)
    lang ||= detect_language(file_path)
    symbols = extract_hermetic_symbols(file_path, lang: lang)
    
    operations = []
    
    # Forecast based on elemental patterns
    symbols[:fire]&.each do |match|
      operations << {
        type: :transform,
        element: :fire,
        description: "Transform method: #{match[:method] rescue 'unknown'}",
        confidence: 0.8
      }
    end
    
    symbols[:earth]&.each do |match|
      operations << {
        type: :structure,
        element: :earth,
        description: "Modify class structure: #{match[:class] rescue 'unknown'}",
        confidence: 0.9
      }
    end
    
    symbols[:albedo]&.each do |match|
      operations << {
        type: :refactor,
        stage: :albedo,
        description: "Refactor identified issue: #{match[:text] rescue 'FIXME'}",
        confidence: 0.7
      }
    end

    # Forecast based on precise structural elements
    symbols[:methods]&.each do |method|
      method_name = method.dig(:metaVariables, :single, :METHOD, :text) rescue 'unknown'
      operations << {
        type: :method_transform,
        element: :fire,
        description: "Transform method: #{method_name}",
        confidence: 0.85,
        method: method_name,
        range: method[:range]
      }
    end

    symbols[:classes]&.each do |klass|
      class_name = klass.dig(:metaVariables, :single, :CLASS, :text) rescue 'unknown'
      operations << {
        type: :class_structure,
        element: :earth,
        description: "Modify class: #{class_name}",
        confidence: 0.9,
        class: class_name,
        range: klass[:range]
      }
    end

    symbols[:modules]&.each do |mod|
      module_name = mod.dig(:metaVariables, :single, :MODULE, :text) rescue 'unknown'
      operations << {
        type: :module_structure,
        element: :earth,
        description: "Modify module: #{module_name}",
        confidence: 0.9,
        module: module_name,
        range: mod[:range]
      }
    end
    
    operations.sort_by { |op| -op[:confidence] }
  end

  # Generate AST pattern from code snippet
  def generate_pattern_from_code(code_snippet, lang: nil)
    # Simple heuristic-based pattern generation
    # In real implementation, this would use more sophisticated AST analysis
    
    pattern = code_snippet.dup
    
    # Replace specific identifiers with pattern variables
    pattern.gsub!(/\bdef\s+(\w+)/, 'def $METHOD')
    pattern.gsub!(/\bclass\s+(\w+)/, 'class $CLASS')
    pattern.gsub!(/\bmodule\s+(\w+)/, 'module $MODULE')
    pattern.gsub!(/\brequire\s+['"]([^'"]+)['"]/, 'require $LIBRARY')
    pattern.gsub!(/\binclude\s+(\w+)/, 'include $MODULE')
    
    pattern
  end

  # Convert line-based patch to semantic pattern
  def convert_to_semantic_patch(patch_text, lang: nil)
    # Parse the patch to extract search and replace patterns
    lines = patch_text.lines
    
    search_pattern = nil
    replace_pattern = nil
    in_search_content = false
    
    lines.each do |line|
      if line.include?('<<<<<<< SEARCH')
        # Start of search section
        search_pattern = ''
        in_search_content = false
      elsif line.include?('-------')
        # Start of actual search content (after the separator)
        in_search_content = true
      elsif line.include?('=======')
        # Transition to replace pattern
        replace_pattern = ''
        in_search_content = false
      elsif line.include?('>>>>>>> REPLACE')
        # End of pattern
        break
      elsif search_pattern && !replace_pattern && in_search_content
        search_pattern += line
      elsif replace_pattern
        replace_pattern += line
      end
    end
    
    return nil unless search_pattern && replace_pattern
    
    {
      search: generate_pattern_from_code(search_pattern.strip, lang: lang),
      replace: replace_pattern.strip
    }
  end
end
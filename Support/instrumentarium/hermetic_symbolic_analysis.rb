# frozen_string_literal: true

require 'open3'
require 'json'
require 'yaml'
require 'tempfile'
require 'fileutils'
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
      # Determine if pattern is simple text or AST pattern
      is_simple_text = pattern && !pattern.match?(/\$[A-Z_]+/)
      
      args = ['ast-grep', 'run']
      
      if pattern
        args += ['--pattern', pattern]
      end
      
      if rewrite
        args += ['--rewrite', rewrite]
      end
      
      # Only add language if it's not nil and ensure it's a string
      if lang
        args += ['--lang', lang.to_s]
      end
      
      # Resolve file paths relative to project root like other tools
      resolved_args = command_args.map do |arg|
        # Skip if path is already absolute
        if File.absolute_path(arg) == arg
          arg
        elsif arg.end_with?('.rb') || arg.end_with?('.js') || arg.end_with?('.py') ||
           arg.end_with?('.java') || arg.end_with?('.go') || arg.end_with?('.rs') ||
           arg.end_with?('.php') || arg.end_with?('.html') || arg.end_with?('.css') ||
           arg.end_with?('.xml') || arg.end_with?('.json') || arg.end_with?('.yml') ||
           arg.end_with?('.yaml') || arg.end_with?('.md')
          File.join(Argonaut.project_root, arg)
        else
          arg
        end
      end
      
      # For simple text patterns, skip JSON check and apply directly
      if is_simple_text && rewrite
        apply_args = args.dup
        apply_args += ['--update-all']
        apply_args += resolved_args
        
        apply_stdout, apply_stderr, apply_status = Open3.capture3(*apply_args)
        
        if apply_status.success?
          # For simple text patterns, return success with applied changes info
          { 
            success: true, 
            result: [{ applied: true, pattern_type: :simple_text }],
            pattern_type: :simple_text
          }
        else
          { error: apply_stderr, status: apply_status.exitstatus, pattern_type: :simple_text }
        end
      else
        # For AST patterns, use the original JSON-based approach
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
          
          { success: true, result: transformation_data, pattern_type: :ast }
        else
          { error: stderr, status: status.exitstatus, pattern_type: :ast }
        end
      end
    end
  end

  # Parse AST-GREP JSON output
  def parse_ast_grep_output(output)
    parse_ast_grep_output_debug(output)
  end

  # Parse AST-GREP JSON output
  def parse_ast_grep_output_debug(output)
    return [] if output.strip.empty?
    
    begin
      # The JSON output from AST-GREP contains HTML entities that need proper handling
      # Instead of unescaping, we need to properly parse the HTML entities
      require 'cgi'
      
      # CGI.unescapeHTML will properly handle all HTML entities
      unescaped_output = CGI.unescapeHTML(output)
      
      parsed = JSON.parse(unescaped_output, symbolize_names: true)
      
      # Transform AST-GREP output format to Horologium expected format
      if parsed.is_a?(Array)
        parsed.map do |match|
          {
            text: match[:text],
            replacement: match[:replacement] || match[:text], # Use original text if no replacement
            range: match[:range],
            language: match[:language],
            file: match[:file],
            lines: match[:lines]
          }
        end
      else
        # Single match case
        [{
          text: parsed[:text],
          replacement: parsed[:replacement] || parsed[:text], # Use original text if no replacement
          range: parsed[:range],
          language: parsed[:language],
          file: parsed[:file],
          lines: parsed[:lines]
        }]
      end
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
    return nil if file_path.nil? || file_path.empty?
    
    extension = File.extname(file_path)
    return nil if extension.empty?
    
    case extension
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
    else nil
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

  # YAML Rule Parser for AST-GREP
  module YamlRuleParser
    extend self

    # Parse YAML rule file or string
    def parse_rule(rule_source)
      rule_data = if rule_source.is_a?(String) && File.exist?(rule_source)
                   YAML.load_file(rule_source)
                 else
                   YAML.safe_load(rule_source)
                 end

      validate_rule_structure(rule_data)
      build_ast_grep_command(rule_data)
    end

    # Validate YAML rule structure
    def validate_rule_structure(rule_data)
      unless rule_data.is_a?(Hash)
        raise ArgumentError, "Rule must be a YAML hash"
      end

      unless rule_data.key?('rule')
        raise ArgumentError, "Rule must contain 'rule' key"
      end

      rule = rule_data['rule']
      unless rule.key?('pattern') || rule.key?('matches')
        raise ArgumentError, "Rule must contain 'pattern' or 'matches' key"
      end

      true
    end

    # Build AST-GREP command from YAML rule
    def build_ast_grep_command(rule_data)
      command = ['ast-grep', 'run']

      rule = rule_data['rule']
      
      # Handle pattern or matches directive
      if rule.key?('pattern')
        command += ['--pattern', rule['pattern']]
      elsif rule.key?('matches')
        # Handle utility rule composition
        command += ['--pattern', build_composite_pattern(rule['matches'])]
      end

      # Handle rewrite
      if rule.key?('rewrite')
        command += ['--rewrite', rule['rewrite']]
      end

      # Handle language
      if rule.key?('language')
        command += ['--lang', rule['language']]
      end

      # Handle constraints
      if rule.key?('constraints')
        command += ['--constraints', JSON.dump(rule['constraints'])]
      end

      # Handle utility rules
      if rule_data.key?('utils')
        command += ['--utils', JSON.dump(rule_data['utils'])]
      end

      # Handle strictness
      if rule.key?('strictness')
        command += ['--strictness', rule['strictness']]
      end

      command
    end

    # Build composite pattern from matches directive
    def build_composite_pattern(matches_directive)
      case matches_directive
      when String
        # Simple utility reference
        matches_directive
      when Array
        # Multiple utility composition
        matches_directive.map { |util| "matches: #{util}" }.join(' AND ')
      when Hash
        # Complex composition with operators
        build_complex_composite_pattern(matches_directive)
      else
        raise ArgumentError, "Invalid matches directive: #{matches_directive}"
      end
    end

    # Build complex composite pattern with operators
    def build_complex_composite_pattern(matches_hash)
      patterns = []

      matches_hash.each do |operator, patterns_list|
        case operator.to_s
        when 'all'
          patterns << patterns_list.map { |p| "matches: #{p}" }.join(' AND ')
        when 'any'
          patterns << patterns_list.map { |p| "matches: #{p}" }.join(' OR ')
        when 'not'
          patterns << "NOT (matches: #{patterns_list})"
        else
          patterns << "matches: #{patterns_list}"
        end
      end

      patterns.join(' AND ')
    end

    # Generate YAML rule from pattern components
    def generate_rule(pattern:, rewrite: nil, language: nil, constraints: {}, utils: {}, strictness: 'smart')
      # Convert constraints to string keys and values for YAML compatibility
      string_constraints = constraints.transform_keys(&:to_s).transform_values do |value|
        if value.is_a?(Hash)
          value.transform_keys(&:to_s).transform_values(&:to_s)
        else
          value.to_s
        end
      end
      
      string_utils = utils.transform_keys(&:to_s).transform_values(&:to_s)
      
      rule = {
        'rule' => {
          'pattern' => pattern,
          'strictness' => strictness.to_s
        }
      }

      rule['rule']['rewrite'] = rewrite if rewrite
      rule['rule']['language'] = language.to_s if language
      rule['rule']['constraints'] = string_constraints unless string_constraints.empty?
      rule['utils'] = string_utils unless string_utils.empty?

      YAML.dump(rule)
    end
  end

  # Hermetic Rule Builder DSL - Phase 2 Enhanced
  module RuleBuilderDSL
    extend self

    # Level 1: Simple patterns (current interface)
    def simple_pattern(pattern, rewrite: nil)
      {
        pattern: pattern,
        rewrite: rewrite,
        level: :simple
      }
    end

    # Level 2: Enhanced rule builder DSL with method chaining
    def build_rule(&block)
      rule_context = RuleContext.new
      rule_context.instance_eval(&block)
      rule_context.to_yaml_rule
    end

    # Level 3: Full YAML integration
    def yaml_rule(yaml_content)
      YamlRuleParser.parse_rule(yaml_content)
    end

    # Fluent interface builder for complex patterns
    def pattern_builder
      PatternBuilder.new
    end

    # Advanced constraint builder
    def constraint_builder
      ConstraintBuilder.new
    end

    # DSL context class with enhanced capabilities
    class RuleContext
      def initialize
        @pattern = nil
        @rewrite = nil
        @language = nil
        @constraints = {}
        @utils = {}
        @strictness = 'smart'
        @matches = []
        @composite_pattern = nil
        @structural_navigation = []
      end

      # Basic pattern methods
      def pattern(pattern_text)
        @pattern = pattern_text
        self
      end

      def rewrite(replacement_text)
        @rewrite = replacement_text
        self
      end

      def language(lang)
        @language = lang
        self
      end

      # Advanced constraint system
      def constraint(variable, **options)
        # Convert to string keys and values for YAML compatibility
        string_options = options.transform_keys(&:to_s).transform_values(&:to_s)
        @constraints[variable.to_s] = string_options
        self
      end

      def regex_constraint(variable, regex_pattern)
        constraint(variable, regex: regex_pattern)
      end

      def kind_constraint(variable, kind_pattern)
        constraint(variable, kind: kind_pattern)
      end

      # Structural navigation
      def inside(pattern)
        @structural_navigation << { inside: pattern }
        self
      end

      def has(pattern)
        @structural_navigation << { has: pattern }
        self
      end

      def follows(pattern)
        @structural_navigation << { follows: pattern }
        self
      end

      def precedes(pattern)
        @structural_navigation << { precedes: pattern }
        self
      end

      def strictness(level)
        @strictness = level
        self
      end

      def utility(name, pattern)
        @utils[name.to_s] = pattern.to_s
        self
      end

      # Composite pattern building
      def and_pattern(*patterns)
        @composite_pattern = { all: patterns }
        self
      end

      def or_pattern(*patterns)
        @composite_pattern = { any: patterns }
        self
      end

      def not_pattern(pattern)
        @composite_pattern = { not: pattern }
        self
      end

      def logical_and
        @logical_operator = :and
        self
      end

      def logical_or
        @logical_operator = :or
        self
      end

      # Pattern composition methods
      def method_pattern(method_name = nil)
        pattern = 'def $METHOD'
        pattern = "def #{method_name}" if method_name
        @pattern = pattern
        self
      end

      def class_def(name = nil)
        pattern = 'class $CLASS'
        pattern = "class #{name}" if name
        @patterns << pattern
        self
      end

      def module_pattern(module_name = nil)
        pattern = 'module $MODULE'
        pattern = "module #{module_name}" if module_name
        @pattern = pattern
        self
      end

      def call_pattern(method_name = nil)
        pattern = '$METHOD($$ARGS)'
        pattern = "#{method_name}($$ARGS)" if method_name
        @pattern = pattern
        self
      end

      def to_yaml_rule
        rule_data = { 'rule' => {} }

        # Handle composite patterns first
        if @composite_pattern
          # Convert symbols to strings for YAML compatibility
          rule_data['rule']['matches'] = convert_symbols_to_strings(@composite_pattern)
        # Handle utility rules via matches directive
        elsif !@utils.empty?
          # If we have utility rules, use matches directive
          rule_data['rule']['matches'] = build_matches_directive_from_utils
        elsif @pattern
          rule_data['rule']['pattern'] = @pattern
        elsif !@structural_navigation.empty?
          rule_data['rule']['matches'] = build_structural_directive
        end

        rule_data['rule']['rewrite'] = @rewrite if @rewrite
        rule_data['rule']['language'] = @language.to_s if @language
        rule_data['rule']['constraints'] = @constraints unless @constraints.empty?
        rule_data['rule']['strictness'] = @strictness.to_s

        YAML.dump(rule_data)
      end

      private

      def convert_symbols_to_strings(obj)
        case obj
        when Hash
          obj.transform_keys(&:to_s).transform_values { |v| convert_symbols_to_strings(v) }
        when Array
          obj.map { |v| convert_symbols_to_strings(v) }
        when Symbol
          obj.to_s
        else
          obj
        end
      end

      # This private method should also ensure its output is correctly converted
      def build_structural_directive
        if @structural_navigation.size == 1
          convert_symbols_to_strings(@structural_navigation.first)
        else
          convert_symbols_to_strings({ all: @structural_navigation })
        end
      end

      # This private method should also ensure its output is correctly converted
      def build_matches_directive_from_utils
        if @utils.size == 1
          convert_symbols_to_strings(@utils.keys.first)
        else
          convert_symbols_to_strings({ all: @utils.keys })
        end
      end
    end

    # Pattern Builder for complex pattern composition
    class PatternBuilder
      def initialize
        @patterns = []
        @logical_operator = :and
      end

      def method_def(name = nil)
        pattern = 'def $METHOD'
        pattern = "def #{name}" if name
        @patterns << pattern
        self
      end

      def class_def(name = nil)
        pattern = 'class $CLASS'
        pattern = "class #{name}" if name
        @patterns << pattern
        self
      end

      def call_expr(method_name = nil)
        pattern = '$METHOD($$ARGS)'
        pattern = "#{method_name}($$ARGS)" if method_name
        @patterns << pattern
        self
      end

      def and_operator
        @logical_operator = :and
        self
      end

      def or_operator
        @logical_operator = :or
        self
      end

      def build
        case @logical_operator
        when :and
          { all: @patterns }
        when :or
          { any: @patterns }
        else
          @patterns.first
        end
      end
    end

    # Constraint Builder for advanced constraints
    class ConstraintBuilder
      def initialize
        @constraints = {}
      end

      def regex(variable, pattern)
        @constraints[variable] ||= {}
        @constraints[variable]['regex'] = pattern
        self
      end

      def kind(variable, kind_pattern)
        @constraints[variable] ||= {}
        @constraints[variable]['kind'] = kind_pattern
        self
      end

      def build
        @constraints
      end
    end
  end

  # Enhanced AST-GREP execution with YAML rule support
  def ast_grep_with_rule(rule_source, file_paths, apply_changes: false)
    # For YAML rules, we parse the YAML to extract pattern and rewrite
    if rule_source.is_a?(String) && (rule_source.start_with?('---') || rule_source.include?('rule:'))
      # Parse YAML to extract pattern and rewrite
      rule_data = YAML.safe_load(rule_source)
      rule = rule_data['rule']
      
      # Handle pattern or matches directive
      pattern = if rule.key?('pattern')
                  rule['pattern']
                elsif rule.key?('matches')
                  # Handle utility rule composition
                  YamlRuleParser.build_composite_pattern(rule['matches'])
                end
      
      rewrite = rule['rewrite']
      lang = rule['language']
      strictness = rule['strictness']
      
      # Build command with extracted parameters
      command = ['ast-grep', 'run']
      command += ['--pattern', pattern] if pattern
      command += ['--rewrite', rewrite] if rewrite
      command += ['--lang', lang] if lang
      command += ['--strictness', strictness] if strictness
      
      # Add file paths
      resolved_paths = file_paths.map { |path| Argonaut.relative_path(path) }
      command += resolved_paths

      # Add update flag if applying changes
      command += ['--update-all'] if apply_changes && rewrite

      # Execute command
      stdout, stderr, status = Open3.capture3(*command)

      if status.success?
        {
          success: true,
          result: parse_ast_grep_output(stdout),
          applied: apply_changes
        }
      else
        {
          success: false,
          error: stderr,
          status: status.exitstatus
        }
      end
    else
      # For simple patterns, use the original approach
      command = if rule_source.is_a?(Hash)
                  # Rule builder DSL result
                  YamlRuleParser.build_ast_grep_command(rule_source)
                else
                  # Simple pattern
                  ['ast-grep', 'run', '--pattern', rule_source]
                end

      # Add file paths
      resolved_paths = file_paths.map { |path| Argonaut.relative_path(path) }
      command += resolved_paths

      # Add update flag if applying changes
      command += ['--update-all'] if apply_changes && rule_source.is_a?(String)

      # Execute command
      stdout, stderr, status = Open3.capture3(*command)

      if status.success?
        {
          success: true,
          result: parse_ast_grep_output(stdout),
          applied: apply_changes
        }
      else
        {
          success: false,
          error: stderr,
          status: status.exitstatus
        }
      end
    end
  end

  # Progressive enhancement interface
  def apply_semantic_transformation(file_path, transformation_spec, level: :auto)
    case level
    when :simple
      # Level 1: Simple pattern matching
      semantic_rewrite(file_path, transformation_spec[:pattern], transformation_spec[:rewrite])
    when :dsl
      # Level 2: Rule builder DSL
      rule_yaml = RuleBuilderDSL.build_rule { pattern(transformation_spec[:pattern]) }
      ast_grep_with_rule(rule_yaml, [file_path], apply_changes: true)
    when :yaml
      # Level 3: Full YAML integration
      ast_grep_with_rule(transformation_spec[:yaml_rule], [file_path], apply_changes: true)
    when :auto
      # Auto-detect level based on transformation complexity
      detect_and_apply_optimal_level(file_path, transformation_spec)
    end
  end

  private

  def detect_and_apply_optimal_level(file_path, transformation_spec)
    complexity = calculate_transformation_complexity(transformation_spec)

    if complexity < 3
      apply_semantic_transformation(file_path, transformation_spec, level: :simple)
    elsif complexity < 7
      apply_semantic_transformation(file_path, transformation_spec, level: :dsl)
    else
      apply_semantic_transformation(file_path, transformation_spec, level: :yaml)
    end
  end

  def calculate_transformation_complexity(transformation_spec)
    complexity = 0

    if transformation_spec[:pattern]
      complexity += transformation_spec[:pattern].scan(/\$[A-Z_]+/).size * 2
      complexity += transformation_spec[:pattern].scan(/\$\$\$/).size * 3
      complexity += transformation_spec[:pattern].scan(/(inside|has|follows|precedes):/).size * 2
    end

    if transformation_spec[:constraints]
      complexity += transformation_spec[:constraints].size * 1
    end

    if transformation_spec[:utils]
      complexity += transformation_spec[:utils].size * 2
    end

    complexity
  end
end
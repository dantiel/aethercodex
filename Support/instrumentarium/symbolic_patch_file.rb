# frozen_string_literal: true

require_relative 'semantic_patch'
require_relative 'hermetic_execution_domain'
require_relative 'hermetic_symbolic_analysis'
require_relative 'hermetic_symbolic_oracle'
require_relative '../argonaut/argonaut'
require 'tempfile'
require 'open3'
require 'yaml'

# Enhanced Symbolic Patch File Tool
# Leverages AST-GREP's advanced capabilities for sophisticated code transformations
module SymbolicPatchFile
  extend self

  # AST-GREP advanced operation modes
  OPERATION_MODES = {
    # Basic operations
    simple_replace: 'Direct text replacement',
    pattern_match: 'AST pattern matching',
    structural_rewrite: 'Structural tree rewriting',
    
    # Advanced operations
    multi_file: 'Cross-file transformations',
    interactive: 'Interactive patch application',
    constraint_based: 'Constraint-driven transformations',
    utility_reuse: 'Rule utility composition',
    
    # Hermetic operations
    elemental: 'Elemental pattern transformations',
    planetary: 'Planetary semantic transformations',
    alchemical: 'Alchemical code purification'
  }

  # AST-GREP pattern types with examples
  PATTERN_TYPES = {
    meta_variable: '$VAR - matches any single AST node',
    multi_meta: '$$$ - matches zero or more AST nodes',
    kind_selector: 'kind: function - matches by node kind',
    relational: 'inside: { kind: class } - relational constraints',
    composite: 'all: [pattern1, pattern2] - composite patterns',
    regex_constraint: 'regex: \\w+ - regex constraints on meta variables'
  }

  # Enhanced semantic patch application with AST-GREP advanced features
  # @param file_path [String] Path to the file to patch
  # @param search_pattern [String] AST-GREP search pattern
  # @param replace_pattern [String] AST-GREP replace pattern
  # @param lang [String, nil] Language hint (auto-detected if nil)
  # @param resonance [Symbol, nil] Hermetic resonance principle to apply
  # @param operation_mode [Symbol] AST-GREP operation mode
  # @param constraints [Hash] Additional constraints for meta variables
  # @param utils [Hash] Utility rules for pattern composition
  # @param strictness [Symbol] Pattern matching strictness
  # @param rule_level [Symbol] Rule application level (:simple, :dsl, :yaml, :auto)
  # @return [Hash] Enhanced result with AST-GREP context
  def apply(file_path, search_pattern, replace_pattern, lang: nil, resonance: nil,
            operation_mode: :pattern_match, constraints: {}, utils: {}, strictness: :smart,
            rule_level: :auto)
    puts "[DEBUG] apply called with: file_path=#{file_path}, search_pattern=#{search_pattern}, replace_pattern=#{replace_pattern}"
    HermeticExecutionDomain.execute do
      # Validate inputs
      return { success: false, error: "File path cannot be empty" } if file_path.nil? || file_path.empty?
      return { success: false, error: "Search pattern cannot be empty" } if search_pattern.nil? || search_pattern.empty?
      
      # Always use absolute paths for file operations
      absolute_path = if file_path.start_with?('/')
                        file_path
                      else
                        File.join(Argonaut.project_root, file_path)
                      end
      
      # For AST-GREP operations, use path relative to Support directory
      # since commands are executed from Support directory
      ast_grep_path = if file_path.start_with?('/')
                        # Convert absolute path to relative from Support directory
                        Pathname.new(file_path).relative_path_from(Pathname.new(File.join(Argonaut.project_root, 'Support'))).to_s
                      else
                        # Already relative path - prepend ../ to go from Support to project root
                        File.join('..', file_path)
                      end
      
      puts "[DEBUG] File existence check:"
      puts "[DEBUG]   file_path: #{file_path}"
      puts "[DEBUG]   absolute_path: #{absolute_path}"
      puts "[DEBUG]   ast_grep_path: #{ast_grep_path}"
      puts "[DEBUG]   File.exist?(absolute_path): #{File.exist?(absolute_path)}"
      
      unless File.exist?(absolute_path)
        return { success: false, error: "File does not exist: #{absolute_path}" }
      end
      
      # Apply with hermetic resonance if specified
      if resonance
        result = HermeticSymbolicOracle.oracular_transform(
          absolute_path,
          {
            type: :semantic_patch,
            target: search_pattern,
            new_value: replace_pattern,
            resonance: resonance,
            operation_mode: operation_mode,
            constraints: constraints,
            strictness: strictness,
            rule_level: rule_level
          }
        )
      else
        # Enhanced semantic patch with AST-GREP advanced features
        result = apply_advanced_semantic_patch(
          absolute_path, search_pattern, replace_pattern,
          lang: lang, operation_mode: operation_mode,
          constraints: constraints, utils: utils, strictness: strictness,
          rule_level: rule_level
        )
      end
      puts "=========="
      puts result.inspect
      
      # Enrich result with pattern analysis
      enriched_result = enrich_result_with_analysis(result, search_pattern, replace_pattern, operation_mode)
      
      # Debug: check what we're returning
      puts "[DEBUG] Final result being returned: #{enriched_result.inspect}"
      
      enriched_result
    end
  end

  # Apply advanced AST-GREP features with YAML rule support
  def apply_advanced_semantic_patch(file_path, search_pattern, replace_pattern,
                                   lang: nil, operation_mode: :pattern_match,
                                   constraints: {}, utils: {}, strictness: :smart,
                                   rule_level: :auto)
    lang ||= HermeticSymbolicAnalysis.detect_language(file_path)
    # Don't pass nil language to AST-GREP - it will auto-detect
    
    # Handle different rule levels
    case rule_level
    when :yaml
      # Full YAML rule integration
      apply_yaml_rule_patch(file_path, search_pattern, replace_pattern, lang: lang,
                           constraints: constraints, utils: utils, strictness: strictness)
    when :dsl
      # Rule builder DSL
      apply_dsl_rule_patch(file_path, search_pattern, replace_pattern, lang: lang,
                          constraints: constraints, utils: utils, strictness: strictness)
    when :simple
      # Simple pattern matching (backward compatible)
      apply_simple_pattern_patch(file_path, search_pattern, replace_pattern, lang: lang,
                                strictness: strictness)
    when :auto
      # Auto-detect optimal level
      apply_auto_level_patch(file_path, search_pattern, replace_pattern, lang: lang,
                            constraints: constraints, utils: utils, strictness: strictness)
    else
      { success: false, error: "Unknown rule level: #{rule_level}" }
    end
  end

  # Parse AST-GREP advanced output with pattern context
  def parse_ast_grep_advanced_output(output)
    puts "parse_ast_grep_advanced_output #{output}"
    return { matches: [], analysis: {} } if output.strip.empty?
    
    begin
      # Clean the output by removing escaped characters that break JSON parsing
      cleaned_output = output.gsub(/\\n/, '\\\\n').gsub(/\\t/, '\\\\t')
      parsed = JSON.parse(cleaned_output, symbolize_names: true)
      {
        matches: parsed,
        analysis: analyze_matches(parsed),
        match_count: parsed.is_a?(Array) ? parsed.size : 1
      }
    rescue JSON::ParserError => e
      # Fallback for text output with better error handling
      {
        matches: output.lines.map { |line| { text: line.strip } },
        analysis: { output_type: :text, error: e.message },
        match_count: output.lines.size
      }
    end
  end

  # Enhanced hybrid patch application with intelligent strategy selection
  # @param file_path [String] Path to the file to patch
  # @param patch_text [String] Traditional patch text
  # @param lang [String, nil] Language hint
  # @param strategy_analysis [Boolean] Whether to perform strategy analysis
  # @return [Hash] Enhanced result with strategy intelligence
  def apply_hybrid(file_path, patch_text, lang: nil, strategy_analysis: true)
    HermeticExecutionDomain.execute do
      if strategy_analysis
        # Perform intelligent strategy analysis
        strategy_result = analyze_patch_strategy(file_path, patch_text, lang: lang)
        
        case strategy_result[:recommended_strategy]
        when :semantic_advanced
          apply_semantic_from_patch(file_path, patch_text, lang: lang)
        when :semantic_basic
          SemanticPatch.apply_hybrid_patch(file_path, patch_text, lang: lang)
        when :line_based
          SemanticPatch.fallback_to_line_based(file_path, patch_text)
        else
          SemanticPatch.apply_hybrid_patch(file_path, patch_text, lang: lang)
        end.merge(strategy_analysis: strategy_result)
      else
        SemanticPatch.apply_hybrid_patch(file_path, patch_text, lang: lang)
      end
    end
  end

  # Intelligent patch strategy analysis
  def analyze_patch_strategy(file_path, patch_text, lang: nil)
    lang ||= HermeticSymbolicAnalysis.detect_language(file_path)
    
    analysis = {
      complexity: analyze_patch_complexity(patch_text),
      semantic_compatibility: analyze_semantic_compatibility(patch_text, lang),
      structural_patterns: detect_structural_patterns(patch_text, lang),
      recommended_strategy: :semantic_basic,
      confidence: 0.7
    }
    
    # Determine best strategy based on analysis
    if analysis[:semantic_compatibility][:highly_compatible] && analysis[:complexity] < 5
      analysis[:recommended_strategy] = :semantic_advanced
      analysis[:confidence] = 0.9
    elsif analysis[:complexity] > 10 || analysis[:semantic_compatibility][:compatible] == false
      analysis[:recommended_strategy] = :line_based
      analysis[:confidence] = 0.8
    end
    
    analysis
  end

  # Advanced patch analysis with AST-GREP pattern intelligence
  # @param patch_text [String] Patch text to analyze
  # @param file_path [String, nil] Optional file path for language detection
  # @param analysis_depth [Symbol] Analysis depth (:basic, :advanced, :comprehensive)
  # @return [Hash] Comprehensive analysis results
  def analyze(patch_text, file_path = nil, analysis_depth: :advanced)
    basic_analysis = SemanticPatch.analyze_patch_strategy(patch_text, file_path)
    
    analysis = basic_analysis.merge({
      ast_grep_patterns: extract_ast_grep_patterns(patch_text),
      meta_variable_usage: extract_meta_variables(patch_text),
      pattern_complexity: calculate_pattern_complexity(patch_text),
      transformation_safety: { safe: true, confidence: 0.8 } # Placeholder
    })
    
    if analysis_depth == :comprehensive && file_path
      analysis[:hermetic_vibrations] = HermeticSymbolicOracle.analyze_vibrations(file_path)
      analysis[:structural_analysis] = analyze_file_structure(file_path)
      analysis[:pattern_compatibility] = assess_pattern_compatibility(patch_text, file_path)
    end
    
    analysis
  end

  # Extract AST-GREP patterns from patch text
  def extract_ast_grep_patterns(patch_text)
    patterns = []
    
    # Look for meta variable patterns
    if patch_text.match?(/\$[A-Z_]+/)
      patterns << :meta_variables
    end
    
    # Look for multi-meta patterns
    if patch_text.match?(/\$\$\$/)
      patterns << :multi_meta
    end
    
    # Look for kind selectors
    if patch_text.match?(/kind:\s*\w+/)
      patterns << :kind_selectors
    end
    
    # Look for relational patterns
    if patch_text.match?(/(inside|has|follows|precedes):/)
      patterns << :relational_patterns
    end
    
    patterns
  end

  # Enhanced batch application with parallel processing and dependency analysis
  # @param patches [Array<Hash>] Array of patch specifications
  # @param parallel_processing [Boolean] Whether to process patches in parallel
  # @param dependency_analysis [Boolean] Whether to analyze patch dependencies
  # @return [Hash] Comprehensive batch results with optimization data
  def apply_batch(patches, parallel_processing: true, dependency_analysis: true)
    HermeticExecutionDomain.execute do
      # Handle empty or nil patches
      return { success: false, error: "No patches provided" } if patches.nil? || patches.empty?
      
      # Validate patch structure
      invalid_patches = patches.reject { |patch| patch.is_a?(Hash) && patch[:path] && patch[:search_pattern] }
      unless invalid_patches.empty?
        return { success: false, error: "Invalid patch structure", invalid_patches: invalid_patches }
      end
      
      if dependency_analysis
        # Analyze patch dependencies and optimize execution order
        optimized_patches = optimize_patch_execution_order(patches)
        results = apply_optimized_batch(optimized_patches, parallel_processing: parallel_processing)
        
        {
          success: true,
          results: results,
          optimization: {
            original_count: patches.size,
            optimized_order: optimized_patches.map { |p| p[:id] rescue p.object_id },
            dependency_graph: build_dependency_graph(patches),
            parallel_processing: parallel_processing
          }
        }
      else
        SemanticPatch.apply_patches(patches)
      end
    end
  end

  # Optimize patch execution order based on dependencies
  def optimize_patch_execution_order(patches)
    # Simple dependency analysis - in practice would use more sophisticated algorithm
    patches.sort_by do |patch|
      # Prioritize simple patterns first, then complex ones
      complexity = calculate_patch_complexity(patch[:diff] || patch[:patch_text] || '')
      complexity
    end
  end

  # Advanced method transformation with AST-GREP pattern intelligence
  # @param file_path [String] Path to the file
  # @param method_name [String] Method name to transform
  # @param new_method_name [String, nil] New method name (for renaming)
  # @param new_body [String, nil] New method body
  # @param selector [String, nil] AST-GREP selector pattern
  # @param context [Hash, nil] Transformation context
  # @param transformation_type [Symbol] Type of transformation
  # @return [Hash] Enhanced transformation result
  def transform_method(file_path, method_name, new_method_name: nil, new_body: nil, selector: nil, context: nil,
                       transformation_type: :rename)
    HermeticExecutionDomain.execute do
      # Always use absolute paths for file operations
      absolute_path = if file_path.start_with?('/')
                        file_path
                      else
                        File.join(Argonaut.project_root, file_path)
                      end
      lang = HermeticSymbolicAnalysis.detect_language(absolute_path)
      
      case transformation_type
      when :rename
        transform_method_rename(absolute_path, method_name, new_method_name, lang: lang, selector: selector)
      when :body_replacement
        transform_method_body(absolute_path, method_name, new_body, lang: lang, context: context)
      when :signature_change
        transform_method_signature(absolute_path, method_name, context, lang: lang)
      when :decorator_add
        transform_method_decorator(absolute_path, method_name, context, lang: lang)
      else
        { success: false, error: "Unknown transformation type: #{transformation_type}" }
      end
    end
  end

  # Method renaming with AST-GREP precision
  def transform_method_rename(file_path, method_name, new_method_name, lang: nil, selector: nil)
    # Always use absolute paths for file operations
    absolute_path = if file_path.start_with?('/')
                      file_path
                    else
                      File.join(Argonaut.project_root, file_path)
                    end
    
    if selector
      search_pattern = selector.gsub('$METHOD', method_name)
      replace_pattern = selector.gsub('$METHOD', new_method_name)
    else
      # Use exact method name pattern for reliable matching
      search_pattern = "def #{method_name}"
      replace_pattern = "def #{new_method_name}"
      
      # Use simple pattern level for reliable AST matching
      return apply_advanced_semantic_patch(absolute_path, search_pattern, replace_pattern,
                                          lang: lang, rule_level: :simple)
    end
    
    apply_advanced_semantic_patch(absolute_path, search_pattern, replace_pattern, lang: lang)
  end

  # Advanced method body replacement using AST-GREP constraints
  def transform_method_body(file_path, method_name, new_body, lang: nil, context: nil)
    # Always use absolute paths for file operations
    absolute_path = if file_path.start_with?('/')
                      file_path
                    else
                      File.join(Argonaut.project_root, file_path)
                    end
    
    # Create constraint-based pattern for method body replacement
    search_pattern = "def #{method_name}\n  $$$BODY\nend"
    replace_pattern = "def #{method_name}\n  #{new_body}\nend"
    
    # Apply with constraints for precise matching
    apply_advanced_semantic_patch(
      absolute_path, search_pattern, replace_pattern,
      lang: lang,
      constraints: { BODY: { pattern: '$$$' } },  # Match any body content
      operation_mode: :constraint_based
    )
  end
  

  # Advanced class transformation with AST-GREP structural patterns
  # @param file_path [String] Path to the file
  # @param class_name [String] Class name to transform
  # @param new_class_name [String, nil] New class name
  # @param new_body [String, nil] New class body
  # @param selector [String, nil] AST-GREP selector pattern
  # @param context [Hash, nil] Transformation context
  # @param transformation_type [Symbol] Type of transformation
  # @return [Hash] Enhanced transformation result
  def transform_class(file_path, class_name, new_class_name: nil, new_body: nil, selector: nil, context: nil,
                      transformation_type: :rename)
    HermeticExecutionDomain.execute do
      # Always use absolute paths for file operations
      absolute_path = if file_path.start_with?('/')
                        file_path
                      else
                        File.join(Argonaut.project_root, file_path)
                      end
      lang = HermeticSymbolicAnalysis.detect_language(absolute_path)
      
      case transformation_type
      when :rename
        transform_class_rename(absolute_path, class_name, new_class_name, lang: lang, selector: selector)
      when :body_replacement
        transform_class_body(absolute_path, class_name, new_body, lang: lang, context: context)
      when :inheritance_change
        transform_class_inheritance(absolute_path, class_name, context, lang: lang)
      when :module_inclusion
        transform_class_module_inclusion(absolute_path, class_name, context, lang: lang)
      else
        { success: false, error: "Unknown transformation type: #{transformation_type}" }
      end
    end
  end

  # Class renaming with AST-GREP precision
  def transform_class_rename(file_path, class_name, new_class_name, lang: nil, selector: nil)
    # Always use absolute paths for file operations
    absolute_path = if file_path.start_with?('/')
                      file_path
                    else
                      File.join(Argonaut.project_root, file_path)
                    end
    
    if selector
      search_pattern = selector.gsub('$CLASS', class_name)
      replace_pattern = selector.gsub('$CLASS', new_class_name)
    else
      # Use exact class name pattern for reliable matching
      search_pattern = "class #{class_name}"
      replace_pattern = "class #{new_class_name}"
      
      # Use simple pattern level for reliable AST matching
      return apply_advanced_semantic_patch(absolute_path, search_pattern, replace_pattern,
                                          lang: lang, rule_level: :simple)
    end
    
    apply_advanced_semantic_patch(absolute_path, search_pattern, replace_pattern, lang: lang)
  end

  # Advanced class body replacement using AST-GREP structural constraints
  def transform_class_body(file_path, class_name, new_body, lang: nil, context: nil)
    # Always use absolute paths for file operations
    absolute_path = if file_path.start_with?('/')
                      file_path
                    else
                      File.join(Argonaut.project_root, file_path)
                    end
    
    # Create structural pattern for class body replacement
    search_pattern = "class #{class_name}\n  $$$BODY\nend"
    replace_pattern = "class #{class_name}\n  #{new_body}\nend"
    
    # Apply with structural constraints
    apply_advanced_semantic_patch(
      absolute_path, search_pattern, replace_pattern,
      lang: lang,
      constraints: { BODY: { pattern: '$$$' } },  # Match any class body content
      operation_mode: :structural_rewrite
    )
  end

  # Advanced documentation addition with AST-GREP pattern intelligence
  # @param file_path [String] Path to the file
  # @param method_name [String] Method name to document
  # @param documentation [String] Documentation text
  # @param selector [String, nil] AST-GREP selector pattern
  # @param context [Hash, nil] Documentation context
  # @param doc_type [Symbol] Documentation type (:single_line, :multi_line, :yardoc)
  # @return [Hash] Enhanced documentation result
  def document_method(file_path, method_name, documentation, selector: nil, context: nil, doc_type: :single_line)
    HermeticExecutionDomain.execute do
      # Always use absolute paths for file operations
      absolute_path = if file_path.start_with?('/')
                        file_path
                      else
                        File.join(Argonaut.project_root, file_path)
                      end
      lang = HermeticSymbolicAnalysis.detect_language(absolute_path)
      
      # Format documentation based on type
      formatted_doc = format_documentation(documentation, doc_type)
      
      if selector
        search_pattern = selector.gsub('$METHOD', method_name)
        replace_pattern = "#{formatted_doc}\n#{search_pattern}"
      else
        search_pattern = "def #{method_name}"
        replace_pattern = "#{formatted_doc}\ndef #{method_name}"
      end
      
      apply_advanced_semantic_patch(absolute_path, search_pattern, replace_pattern, lang: lang)
    end
  end

  # Format documentation based on type
  def format_documentation(doc_text, doc_type)
    case doc_type
    when :multi_line
      doc_text.lines.map { |line| "# #{line}" }.join("\n")
    when :yardoc
      "# @!method #{doc_text}"
    else
      "# #{doc_text}"
    end
  end

  # Advanced find and replace with AST-GREP context intelligence
  # @param file_path [String] Path to the file
  # @param search_text [String] Text to search for
  # @param replace_text [String] Text to replace with
  # @param context_pattern [String, nil] Optional context pattern for precision
  # @param selector [String, nil] AST-GREP selector pattern
  # @param ast_pattern [String, nil] AST pattern for semantic matching
  # @param replacement_strategy [Symbol] Replacement strategy (:exact, :semantic, :structural)
  # @return [Hash] Enhanced find and replace result
  def find_and_replace(file_path, search_text, replace_text, context_pattern: nil, selector: nil, ast_pattern: nil,
                       replacement_strategy: :semantic)
    puts "[DEBUG] find_and_replace called with: file_path=#{file_path}, search_text=#{search_text}, replace_text=#{replace_text}"
    HermeticExecutionDomain.execute do
      # Always use absolute paths for file operations
      absolute_path = if file_path.start_with?('/')
                        file_path
                      else
                        File.join(Argonaut.project_root, file_path)
                      end
      lang = HermeticSymbolicAnalysis.detect_language(absolute_path)
      puts "[DEBUG] Absolute path: #{absolute_path}, lang: #{lang}"
      
      search_pattern, replace_pattern = build_advanced_patterns(
        search_text, replace_text, context_pattern, selector, ast_pattern, replacement_strategy
      )
      
      operation_mode = case replacement_strategy
                      when :structural then :structural_rewrite
                      when :semantic then :pattern_match
                      else :simple_replace
                      end
      
      apply_advanced_semantic_patch(
        absolute_path, search_pattern, replace_pattern,
        lang: lang, operation_mode: operation_mode
      )
    end
  end

  # Build advanced AST-GREP patterns based on strategy
  def build_advanced_patterns(search_text, replace_text, context_pattern, selector, ast_pattern, strategy)
    case strategy
    when :structural
      # Use AST pattern for structural matching
      [ast_pattern || "$MATCH", replace_text]
    when :semantic
      # Use semantic patterns with context
      if context_pattern
        [context_pattern.gsub('$TEXT', search_text), context_pattern.gsub('$TEXT', replace_text)]
      elsif selector
        [selector.gsub('$MATCH', search_text), selector.gsub('$MATCH', replace_text)]
      else
        [search_text, replace_text]
      end
    else
      # Simple text replacement
      [search_text, replace_text]
    end
  end

  # Enhanced status check with AST-GREP capability analysis
  # @return [Hash] Comprehensive status information
  def status
    HermeticExecutionDomain.execute do
      # Test basic AST-GREP functionality
      ast_grep_available = system('which ast-grep > /dev/null 2>&1')
      
      if ast_grep_available
        # Test advanced AST-GREP features
        advanced_tests = test_advanced_features
        
        {
          available: true,
          ast_grep_installed: true,
          version: get_ast_grep_version,
          advanced_features: advanced_tests,
          operation_modes: OPERATION_MODES.keys,
          pattern_types: PATTERN_TYPES.keys,
          hermetic_oracle_available: true
        }
      else
        {
          available: false,
          ast_grep_installed: false,
          error: 'AST-GREP not found in PATH',
          hermetic_oracle_available: false
        }
      end
    rescue => e
      {
        available: false,
        error: e.message,
        ast_grep_installed: system('which ast-grep > /dev/null 2>&1'),
        hermetic_oracle_available: false
      }
    end
  end

  # Test advanced AST-GREP features
  def test_advanced_features
    features = {}
    
    # Test JSON output
    features[:json_output] = test_json_output
    
    # Test pattern matching
    features[:pattern_matching] = test_pattern_matching
    
    # Test language support
    features[:language_support] = test_language_support
    
    features
  end

  # Get AST-GREP version
  def get_ast_grep_version
    stdout, stderr, status = Open3.capture3('ast-grep', '--version')
    status.success? ? stdout.strip : 'unknown'
  end

  # Perform oracular analysis of file
  # @param file_path [String] Path to the file to analyze
  # @param lang [String, nil] Language hint
  # @return [Hash] Oracular analysis results
  def oracular_analysis(file_path, lang: nil)
    HermeticExecutionDomain.execute do
      HermeticSymbolicOracle.oracular_analysis(file_path, lang: lang)
    end
  end

  # Apply transformation with hermetic resonance
  # @param file_path [String] Path to the file
  # @param transformation_spec [Hash] Transformation specification
  # @return [Hash] Result with hermetic context
  def transform_with_resonance(file_path, transformation_spec)
    HermeticExecutionDomain.execute do
      HermeticSymbolicOracle.oracular_transform(file_path, transformation_spec)
    end
  end

  # Batch transform with vibrational harmony
  # @param transformations [Array<Hash>] Array of transformation specifications
  # @param harmony_strategy [Symbol] Harmony strategy (:balanced, :masculine, :feminine)
  # @return [Hash] Batch transformation results with harmonic analysis
  def batch_transform_with_harmony(transformations, harmony_strategy: :balanced)
    HermeticExecutionDomain.execute do
      HermeticSymbolicOracle.batch_transform_with_harmony(transformations, harmony_strategy: harmony_strategy)
    end
  end

  # --- Helper Methods ---
  
  # Cross-file pattern matching and transformation
  # @param file_patterns [Array<String>] File patterns to search (e.g., ['**/*.rb', 'lib/**/*.js'])
  # @param search_pattern [String] AST-GREP search pattern
  # @param replace_pattern [String, nil] AST-GREP replace pattern
  # @param lang [String, nil] Language hint
  # @param rule_level [Symbol] Rule application level
  # @param project_config [Hash] Project configuration for AST-GREP
  # @return [Hash] Cross-file transformation results
  def cross_file_transform(file_patterns, search_pattern, replace_pattern: nil, lang: nil,
                          rule_level: :auto, project_config: {})
    HermeticExecutionDomain.execute do
      # Build project configuration file if needed
      config_file = nil
      if project_config.any?
        config_file = create_ast_grep_config(project_config)
      end

      # Resolve file patterns
      resolved_patterns = file_patterns.map { |pattern| Argonaut.relative_path(pattern) }

      # Apply transformation across files
      result = case rule_level
               when :yaml
                 apply_cross_file_yaml(resolved_patterns, search_pattern, replace_pattern, lang: lang)
               when :dsl
                 apply_cross_file_dsl(resolved_patterns, search_pattern, replace_pattern, lang: lang)
               when :simple, :auto
                 apply_cross_file_simple(resolved_patterns, search_pattern, replace_pattern, lang: lang)
               end

      # Clean up config file
      File.unlink(config_file) if config_file && File.exist?(config_file)

      result.merge({
        file_patterns: resolved_patterns,
        project_config_used: project_config.any?
      })
    end
  end

  # Pattern analysis and preview
  # @param file_path [String] Path to the file
  # @param pattern [String] AST-GREP pattern to analyze
  # @param lang [String, nil] Language hint
  # @param preview_mode [Symbol] Preview mode (:matches, :context, :transformations)
  # @return [Hash] Pattern analysis results
  def analyze_pattern(file_path, pattern, lang: nil, preview_mode: :matches)
    HermeticExecutionDomain.execute do
      # Validate inputs
      return { success: false, error: "File path cannot be empty" } if file_path.nil? || file_path.empty?
      return { success: false, error: "Pattern cannot be empty" } if pattern.nil? || pattern.empty?
      
      # Validate preview mode
      valid_modes = [:matches, :context, :transformations]
      unless valid_modes.include?(preview_mode)
        return { success: false, error: "Unknown preview mode: #{preview_mode}" }
      end
      
      lang ||= HermeticSymbolicAnalysis.detect_language(file_path)

      case preview_mode
      when :matches
        analyze_pattern_matches(file_path, pattern, lang: lang)
      when :context
        analyze_pattern_context(file_path, pattern, lang: lang)
      when :transformations
        analyze_pattern_transformations(file_path, pattern, lang: lang)
      end
    end
  end

  # Analyze pattern matches
  def analyze_pattern_matches(file_path, pattern, lang: nil)
    args = ['ast-grep', 'run', '--pattern', pattern, '--json']
    args += ['--lang', lang] if lang
    args << file_path

    stdout, stderr, status = Open3.capture3(*args)

    if status.success?
      matches = parse_ast_grep_advanced_output(stdout)[:matches]
      {
        success: true,
        matches: matches,
        match_count: matches.size,
        pattern_analysis: analyze_pattern_structure(pattern)
      }
    else
      { success: false, error: stderr }
    end
  end

  # Analyze pattern context
  def analyze_pattern_context(file_path, pattern, lang: nil)
    args = ['ast-grep', 'run', '--pattern', pattern, '--context', '3']
    args += ['--lang', lang] if lang
    args << file_path

    stdout, stderr, status = Open3.capture3(*args)

    if status.success?
      {
        success: true,
        context_lines: stdout.lines,
        pattern: pattern
      }
    else
      { success: false, error: stderr }
    end
  end

  # Analyze pattern transformations
  def analyze_pattern_transformations(file_path, pattern, lang: nil)
    # First, find matches
    matches_result = analyze_pattern_matches(file_path, pattern, lang: lang)
    return matches_result unless matches_result[:success]

    # Analyze transformation safety and impact
    transformations = matches_result[:matches].map do |match|
      {
        match: match,
        safety: analyze_transformation_safety(match),
        impact: analyze_transformation_impact(match),
        suggested_rewrite: suggest_rewrite_pattern(match, pattern)
      }
    end

    matches_result.merge({
      transformations: transformations,
      safety_score: calculate_overall_safety(transformations),
      impact_level: calculate_overall_impact(transformations)
    })
  end

  # Analyze pattern structure
  def analyze_pattern_structure(pattern)
    {
      meta_variables: pattern.scan(/\$[A-Z_]+/).uniq,
      complexity: calculate_pattern_complexity(pattern),
      structural_elements: detect_structural_elements(pattern),
      hermetic_resonance: analyze_hermetic_resonance(pattern)
    }
  end

  private

  # Detect and apply optimal transformation level
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

  # Calculate transformation complexity for auto-level detection
  def calculate_transformation_complexity(transformation_spec)
    complexity = 0
    
    if transformation_spec[:pattern]
      complexity += calculate_pattern_complexity(transformation_spec[:pattern])
    end
    
    if transformation_spec[:constraints]
      complexity += transformation_spec[:constraints].size * 2
    end
    
    if transformation_spec[:utils]
      complexity += transformation_spec[:utils].size * 3
    end
    
    complexity
  end

  # Apply semantic transformation at specified level
  def apply_semantic_transformation(file_path, transformation_spec, level: :auto)
    case level
    when :simple
      # Level 1: Simple pattern matching
      semantic_rewrite(file_path, transformation_spec[:pattern], transformation_spec[:rewrite])
    when :dsl
      # Level 2: Rule builder DSL
      rule_yaml = HermeticSymbolicAnalysis::RuleBuilderDSL.build_rule { pattern(transformation_spec[:pattern]) }
      HermeticSymbolicAnalysis.ast_grep_with_rule(rule_yaml, [file_path], apply_changes: true)
    when :yaml
      # Level 3: Full YAML integration
      HermeticSymbolicAnalysis.ast_grep_with_rule(transformation_spec[:yaml_rule], [file_path], apply_changes: true)
    when :auto
      # Auto-detect level based on transformation complexity
      detect_and_apply_optimal_level(file_path, transformation_spec)
    end
  end

  # Semantic rewrite using HermeticSymbolicAnalysis
  def semantic_rewrite(file_path, pattern, rewrite)
    HermeticSymbolicAnalysis.semantic_rewrite(file_path, pattern, rewrite)
  end

  # Enrich result with pattern analysis
  def enrich_result_with_analysis(result, search_pattern, replace_pattern, operation_mode)
    return result unless result.is_a?(Hash) && result[:success]
    
    result.merge({
      pattern_analysis: {
        search_pattern: search_pattern,
        replace_pattern: replace_pattern,
        operation_mode: operation_mode,
        meta_variables: extract_meta_variables(search_pattern),
        pattern_complexity: calculate_pattern_complexity(search_pattern)
      }
    })
  end

  # Extract meta variables from pattern
  def extract_meta_variables(pattern)
    pattern.scan(/\$([A-Z_]+)/).flatten.uniq
  end

  # Calculate pattern complexity
  def calculate_pattern_complexity(pattern)
    complexity = 0
    complexity += pattern.scan(/\$[A-Z_]+/).size * 2
    complexity += pattern.scan(/\$\$\$/).size * 3
    complexity += pattern.scan(/kind:/).size * 1
    complexity += pattern.scan(/(inside|has|follows|precedes):/).size * 2
    complexity
  end

  # Analyze matches for pattern intelligence
  def analyze_matches(matches)
    return {} unless matches.is_a?(Array)
    
    {
      total_matches: matches.size,
      unique_patterns: matches.map { |m| m[:text] rescue nil }.compact.uniq.size,
      meta_variable_usage: analyze_meta_variable_usage(matches),
      structural_depth: calculate_structural_depth(matches)
    }
  end

  # Detect structural elements in pattern
  def detect_structural_elements(pattern)
    elements = []
    elements << :method if pattern.include?('def ')
    elements << :class if pattern.include?('class ')
    elements << :module if pattern.include?('module ')
    elements << :conditional if pattern.include?('if ') || pattern.include?('unless ')
    elements << :loop if pattern.include?('while ') || pattern.include?('for ')
    elements
  end

  # Analyze meta variable usage in matches
  def analyze_meta_variable_usage(matches)
    return { variables: [], count: 0 } unless matches.is_a?(Array)
    
    # AST-GREP JSON output doesn't include metaVariables in this format
    # For now, return empty analysis since we're using simple patterns
    { variables: [], count: 0 }
  end

  # Calculate structural depth of matches
  def calculate_structural_depth(matches)
    return 0 unless matches.is_a?(Array)
    
    matches.map do |match|
      match[:range] ? match[:range][:end][:line] - match[:range][:start][:line] : 0
    end.max || 0
  end

  # Test JSON output capability
  def test_json_output
    test_file = Tempfile.new(['test', '.rb'])
    test_file.write("def test_method; end")
    test_file.close
    
    stdout, stderr, status = Open3.capture3('ast-grep', 'run', '--pattern', 'def $METHOD', '--json', test_file.path)
    test_file.unlink
    
    status.success? && !stdout.strip.empty?
  rescue
    false
  end

  # Test pattern matching capability
  def test_pattern_matching
    test_file = Tempfile.new(['test', '.rb'])
    test_file.write("class TestClass; def method1; end; def method2; end; end")
    test_file.close
    
    stdout, stderr, status = Open3.capture3('ast-grep', 'run', '--pattern', 'def $METHOD', test_file.path)
    test_file.unlink
    
    status.success? && stdout.include?('method1') && stdout.include?('method2')
  rescue
    false
  end

  # Test language support
  def test_language_support
    # Test basic language detection
    ['ruby', 'javascript', 'python'].all? do |lang|
      stdout, stderr, status = Open3.capture3('ast-grep', 'run', '--lang', lang, '--pattern', '$A', '--help')
      status.success?
    end
  rescue
    false
  end

  # YAML rule-based patch application
  def apply_yaml_rule_patch(file_path, search_pattern, replace_pattern, lang: nil,
                           constraints: {}, utils: {}, strictness: :smart)
    # Check if search_pattern is already a YAML rule
    if search_pattern.is_a?(String) && (search_pattern.start_with?('---') || search_pattern.include?('rule:'))
      # Use the provided YAML rule directly
      yaml_rule = search_pattern
    else
      # Generate YAML rule from components
      yaml_rule = HermeticSymbolicAnalysis::YamlRuleParser.generate_rule(
        pattern: search_pattern,
        rewrite: replace_pattern,
        language: lang,
        constraints: constraints,
        utils: utils,
        strictness: strictness.to_s # Ensure strictness is a string
      )
    end
    
    # Apply YAML rule
    result = HermeticSymbolicAnalysis.ast_grep_with_rule(yaml_rule, [file_path], apply_changes: true)
    
    result.merge({
      rule_level: :yaml,
      yaml_rule: yaml_rule
    })
  end

  # DSL rule-based patch application
  def apply_dsl_rule_patch(file_path, search_pattern, replace_pattern, lang: nil,
                          constraints: {}, utils: {}, strictness: :smart,
                          composite_pattern: nil, structural_navigation: [])
    # Build rule using enhanced DSL
    dsl_rule = HermeticSymbolicAnalysis::RuleBuilderDSL.build_rule do
      pattern(search_pattern)
      rewrite(replace_pattern) if replace_pattern
      language(lang) if lang
      strictness(strictness.to_s) # Ensure strictness is a string
      
      # Add constraints
      constraints.each do |var, constraint_opts|
        constraint(var, **constraint_opts)
      end
      
      # Add utilities
      utils.each do |name, pattern|
        utility(name, pattern)
      end
      
      # Add composite patterns
      if composite_pattern
        case composite_pattern[:operator]
        when :and
          and_pattern(*composite_pattern[:patterns])
        when :or
          or_pattern(*composite_pattern[:patterns])
        when :not
          not_pattern(composite_pattern[:pattern])
        end
      end
      
      # Add structural navigation
      structural_navigation.each do |nav|
        case nav[:type]
        when :inside
          inside(nav[:pattern])
        when :has
          has(nav[:pattern])
        when :follows
          follows(nav[:pattern])
        when :precedes
          precedes(nav[:pattern])
        end
      end
    end
    
    # Apply DSL rule
    result = HermeticSymbolicAnalysis.ast_grep_with_rule(dsl_rule, [file_path], apply_changes: true)
    
    result.merge({
      rule_level: :dsl,
      dsl_rule: dsl_rule
    })
  end

  # Enhanced DSL methods for Phase 2
  def apply_enhanced_dsl_patch(file_path, dsl_config, apply_changes: true)
    # Build rule using enhanced DSL with method chaining
    rule_context = HermeticSymbolicAnalysis::RuleBuilderDSL::RuleContext.new
    
    # Apply DSL configuration
    dsl_config.each do |method, args|
      if rule_context.respond_to?(method)
        if args.is_a?(Array)
          rule_context.send(method, *args)
        else
          rule_context.send(method, args)
        end
      end
    end
    
    dsl_rule = rule_context.to_yaml_rule
    
    # Apply DSL rule
    result = HermeticSymbolicAnalysis.ast_grep_with_rule(dsl_rule, [file_path], apply_changes: apply_changes)
    
    result.merge({
      rule_level: :enhanced_dsl,
      dsl_rule: dsl_rule
    })
  end

  # Pattern builder interface
  def build_pattern(&block)
    builder = HermeticSymbolicAnalysis::RuleBuilderDSL::PatternBuilder.new
    builder.instance_eval(&block)
    builder.build
  end

  # Constraint builder interface
  def build_constraints(&block)
    builder = HermeticSymbolicAnalysis::RuleBuilderDSL::ConstraintBuilder.new
    builder.instance_eval(&block)
    builder.build
  end

  # Advanced pattern composition
  def apply_composite_pattern(file_path, composite_config, replace_pattern: nil, lang: nil)
    dsl_config = {
      language: [lang],
      rewrite: [replace_pattern]
    }
    
    case composite_config[:operator]
    when :and
      dsl_config[:and_pattern] = composite_config[:patterns]
    when :or
      dsl_config[:or_pattern] = composite_config[:patterns]
    when :not
      dsl_config[:not_pattern] = [composite_config[:pattern]]
    end
    
    apply_enhanced_dsl_patch(file_path, dsl_config)
  end

  # Structural navigation patterns
  def apply_structural_pattern(file_path, structural_config, replace_pattern: nil, lang: nil)
    dsl_config = {
      language: [lang],
      rewrite: [replace_pattern]
    }
    
    structural_config.each do |nav_type, pattern|
      case nav_type
      when :inside
        dsl_config[:inside] = [pattern]
      when :has
        dsl_config[:has] = [pattern]
      when :follows
        dsl_config[:follows] = [pattern]
      when :precedes
        dsl_config[:precedes] = [pattern]
      end
    end
    
    apply_enhanced_dsl_patch(file_path, dsl_config)
  end

  # Simple pattern-based patch application (backward compatible)
  def apply_simple_pattern_patch(file_path, search_pattern, replace_pattern, lang: nil, strictness: :smart)
    args = ['ast-grep', 'run']
    
    args += ['--pattern', search_pattern.to_s] if search_pattern
    args += ['--rewrite', replace_pattern.to_s] if replace_pattern
    args += ['--lang', lang.to_s] if lang
    args += ['--strictness', strictness.to_s] if strictness
    
    # Always use absolute paths for file operations
    absolute_path = if file_path.start_with?('/')
                      file_path
                    else
                      File.join(Argonaut.project_root, file_path)
                    end
    
    # For AST-GREP operations, use path relative to Support directory
    # since commands are executed from Support directory
    ast_grep_path = if file_path.start_with?('/')
                      # Convert absolute path to relative from Support directory
                      Pathname.new(file_path).relative_path_from(Pathname.new(File.join(Argonaut.project_root, 'Support'))).to_s
                    else
                      # Already relative path - prepend ../ to go from Support to project root
                      File.join('..', file_path)
                    end
    
    puts "[DEBUG] Original file_path: #{file_path}"
    puts "[DEBUG] Absolute path: #{absolute_path}"
    puts "[DEBUG] AST-GREP path: #{ast_grep_path}"
    puts "[DEBUG] File exists? #{File.exist?(absolute_path)}"
    puts "[DEBUG] Current directory: #{Dir.pwd}"
    
    args << ast_grep_path
    
    # If we have a rewrite operation, we need to run two commands:
    # 1. First get the matches without --update-all to capture transformation data
    # 2. Then apply the changes with --update-all
    if replace_pattern
      # First get the transformation data
      json_args = args.dup
      json_args << '--json'
      
      # Use shell command with proper redirection
      # The command is executed from the Support directory, so use relative path
      json_command = (json_args + ['2>/dev/null']).join(' ')
      
      # Debug: save the command and output
      File.write('/tmp/ast_grep_command.txt', json_command)
      json_stdout = `#{json_command}`
      json_success = $?.success?
      File.write('/tmp/ast_grep_output.txt', json_stdout)
      
      if json_success
        transformation_data = HermeticSymbolicAnalysis.parse_ast_grep_output(json_stdout)
        
        # Debug: check what we're getting
        puts "[DEBUG] Transformation data: #{transformation_data.inspect}"
        puts "[DEBUG] Transformation data type: #{transformation_data.class}"
        puts "[DEBUG] Transformation data empty?: #{transformation_data.empty?}"
        
        # Store transformation data for return
        
        # Then apply the changes
        apply_args = args.dup
        apply_args += ['--update-all']
        
        puts "[DEBUG] Running apply command: #{apply_args.inspect}"
        puts "[DEBUG] Current directory: #{Dir.pwd}"
        apply_stdout, apply_stderr, apply_status = Open3.capture3(*apply_args)
        
        puts "[DEBUG] Apply Status: #{apply_status.success?}"
        puts "[DEBUG] Apply Stdout: #{apply_stdout.inspect}"
        puts "[DEBUG] Apply Stderr: #{apply_stderr.inspect}"
        
        if apply_status.success?
          {
            success: true,
            result: transformation_data,
            rule_level: :simple,
            strictness: strictness,
            applied: true,
            debug_info: {
              transformation_data_type: transformation_data.class.name,
              transformation_data_inspect: transformation_data.inspect
            }
          }
        else
          {
            success: false,
            error: apply_stderr,
            status: apply_status.exitstatus,
            rule_level: :simple
          }
        end
      else
        {
          success: false,
          error: "JSON parsing failed",
          status: json_success,
          rule_level: :simple
        }
      end
    else
      # No rewrite, just search
      args << '--json'
      
      # Use shell command with proper redirection
      command = (args + ['2>/dev/null']).join ' '
      stdout = `#{command}`
      status = $?.success?
      
      if status
        transformation_data = HermeticSymbolicAnalysis.parse_ast_grep_output(stdout)
        
        {
          success: true,
          result: transformation_data || [],
          rule_level: :simple,
          strictness: strictness,
          applied: false,
          debug_info: {
            transformation_data_type: transformation_data.class.name,
            transformation_data_inspect: transformation_data.inspect
          }
        }
      else
        {
          success: false,
          error: "Command execution failed",
          status: status.exitstatus,
          rule_level: :simple
        }
      end
    end
  end

  # Auto-level patch application with intelligent detection
  def apply_auto_level_patch(file_path, search_pattern, replace_pattern, lang: nil,
                            constraints: {}, utils: {}, strictness: :smart)
    # First check if search_pattern is already a YAML rule
    if search_pattern.is_a?(String) && (search_pattern.start_with?('---') || search_pattern.include?('rule:'))
      # It's a YAML rule, use level 3
      optimal_level = :yaml
      complexity = 10 # High complexity for YAML rules
    else
      # Calculate transformation complexity
      complexity = calculate_transformation_complexity(
        pattern: search_pattern,
        constraints: constraints,
        utils: utils
      )
      
      # Select optimal level based on complexity
      optimal_level = if complexity < 3
                       :simple
                     elsif complexity < 7
                       :dsl
                     else
                       :yaml
                     end
    end
    
    # Apply with optimal level
    apply_advanced_semantic_patch(
      file_path, search_pattern, replace_pattern,
      lang: lang, operation_mode: :pattern_match,
      constraints: constraints, utils: utils, strictness: strictness,
      rule_level: optimal_level
    ).merge({
      auto_detected_level: optimal_level,
      complexity_score: complexity
    })
  end

  # Calculate transformation complexity
  def calculate_transformation_complexity(pattern: nil, constraints: {}, utils: {})
    complexity = 0

    if pattern
      complexity += pattern.scan(/\$[A-Z_]+/).size * 2
      complexity += pattern.scan(/\$\$\$/).size * 3
      complexity += pattern.scan(/(inside|has|follows|precedes):/).size * 2
    end

    complexity += constraints.size * 1
    complexity += utils.size * 2

    complexity
  end

  # Additional transformation methods for completeness
  def transform_method_signature(file_path, method_name, context, lang: nil)
    # Implement method signature transformation
    { success: false, error: "Method signature transformation not yet implemented" }
  end

  def transform_method_decorator(file_path, method_name, context, lang: nil)
    # Implement method decorator transformation
    { success: false, error: "Method decorator transformation not yet implemented" }
  end

  def transform_class_inheritance(file_path, class_name, context, lang: nil)
    # Implement class inheritance transformation
    { success: false, error: "Class inheritance transformation not yet implemented" }
  end

  def transform_class_module_inclusion(file_path, class_name, context, lang: nil)
    # Implement class module inclusion transformation
    { success: false, error: "Class module inclusion transformation not yet implemented" }
  end

  def apply_semantic_from_patch(file_path, patch_text, lang: nil)
    # Convert patch to semantic pattern and apply
    semantic_patch = HermeticSymbolicAnalysis.convert_to_semantic_patch(patch_text, lang: lang)
    
    if semantic_patch
      apply_advanced_semantic_patch(file_path, semantic_patch[:search], semantic_patch[:replace], lang: lang)
    else
      { success: false, error: "Cannot convert patch to semantic pattern" }
    end
  end

  def analyze_patch_complexity(patch_text)
    # Simple complexity heuristic
    lines = patch_text.lines.size
    indent_levels = patch_text.scan(/^\s+/).map { |indent| indent.size / 2 }.max || 0
    lines + indent_levels
  end

  def analyze_semantic_compatibility(patch_text, lang)
    # Analyze if patch can be converted to semantic patterns
    patterns = extract_ast_grep_patterns(patch_text)
    {
      compatible: !patterns.empty?,
      highly_compatible: patterns.include?(:meta_variables),
      patterns_found: patterns
    }
  end

  def detect_structural_patterns(patch_text, lang)
    # Detect structural patterns in patch
    [] # Placeholder - would implement actual detection
  end

  def calculate_patch_complexity(patch_text)
    # Calculate patch complexity for optimization
    patch_text.size / 100.0
  end

  def build_dependency_graph(patches)
    # Build dependency graph for patches
    {} # Placeholder - would implement actual dependency analysis
  end

  def apply_optimized_batch(patches, parallel_processing: true)
    # Apply optimized batch of patches
    patches.map { |patch| apply(patch[:path], patch[:search_pattern], patch[:replace_pattern]) }
  end

  # Cross-file YAML rule application
  def apply_cross_file_yaml(file_patterns, search_pattern, replace_pattern, lang: nil)
    # Handle single pattern or array of patterns
    patterns = file_patterns.is_a?(Array) ? file_patterns : [file_patterns]
    
    yaml_rule = HermeticSymbolicAnalysis::YamlRuleParser.generate_rule(
      pattern: search_pattern,
      rewrite: replace_pattern,
      language: lang
    )

    HermeticSymbolicAnalysis.ast_grep_with_rule(yaml_rule, patterns, apply_changes: !!replace_pattern)
  end

  # Cross-file DSL rule application
  def apply_cross_file_dsl(file_patterns, search_pattern, replace_pattern, lang: nil)
    # Handle single pattern or array of patterns
    patterns = file_patterns.is_a?(Array) ? file_patterns : [file_patterns]
    
    dsl_rule = HermeticSymbolicAnalysis::RuleBuilderDSL.build_rule do
      pattern(search_pattern)
      rewrite(replace_pattern) if replace_pattern
      language(lang) if lang
    end

    HermeticSymbolicAnalysis.ast_grep_with_rule(dsl_rule, patterns, apply_changes: !!replace_pattern)
  end

  # Cross-file simple pattern application
  def apply_cross_file_simple(file_patterns, search_pattern, replace_pattern, lang: nil)
    # Handle single pattern or array of patterns
    patterns = file_patterns.is_a?(Array) ? file_patterns : [file_patterns]
    
    args = ['ast-grep', 'run']
    args += ['--pattern', search_pattern]
    args += ['--rewrite', replace_pattern] if replace_pattern
    args += ['--lang', lang] if lang
    args += patterns
    args += ['--update-all'] if replace_pattern

    stdout, stderr, status = Open3.capture3(*args)

    if status.success?
      {
        success: true,
        result: parse_ast_grep_advanced_output(stdout),
        applied: !!replace_pattern
      }
    else
      {
        success: false,
        error: stderr,
        status: status.exitstatus
      }
    end
  end


  # Analyze pattern matches
  def analyze_pattern_matches(file_path, pattern, lang: nil)
    return { success: false, error: "Pattern cannot be empty" } if pattern.nil? || pattern.empty?
    
    args = ['ast-grep', 'run', '--pattern', pattern, '--json']
    args += ['--lang', lang] if lang
    args << file_path

    stdout, stderr, status = Open3.capture3(*args)

    if status.success?
      matches = parse_ast_grep_advanced_output(stdout)[:matches]
      {
        success: true,
        matches: matches,
        match_count: matches.size,
        pattern_analysis: analyze_pattern_structure(pattern)
      }
    else
      { success: false, error: stderr }
    end
  end

  # Analyze pattern context
  def analyze_pattern_context(file_path, pattern, lang: nil)
    args = ['ast-grep', 'run', '--pattern', pattern, '--context', '3']
    args += ['--lang', lang] if lang
    args << file_path

    stdout, stderr, status = Open3.capture3(*args)

    if status.success?
      {
        success: true,
        context_lines: stdout.lines,
        pattern: pattern
      }
    else
      { success: false, error: stderr }
    end
  end

  # Analyze pattern transformations
  def analyze_pattern_transformations(file_path, pattern, lang: nil)
    # First, find matches
    matches_result = analyze_pattern_matches(file_path, pattern, lang: lang)
    return matches_result unless matches_result[:success]

    # Analyze transformation safety and impact
    transformations = matches_result[:matches].map do |match|
      {
        match: match,
        safety: analyze_transformation_safety(match),
        impact: analyze_transformation_impact(match),
        suggested_rewrite: suggest_rewrite_pattern(match, pattern)
      }
    end

    matches_result.merge({
      transformations: transformations,
      safety_score: calculate_overall_safety(transformations),
      impact_level: calculate_overall_impact(transformations)
    })
  end

  # Analyze pattern structure
  def analyze_pattern_structure(pattern)
    {
      meta_variables: pattern.scan(/\$[A-Z_]+/).uniq,
      complexity: calculate_pattern_complexity(pattern),
      structural_elements: detect_structural_elements(pattern),
      hermetic_resonance: analyze_hermetic_resonance(pattern)
    }
  end

  # Detect structural elements in pattern
  def detect_structural_elements(pattern)
    elements = []
    elements << :method if pattern.include?('def ')
    elements << :class if pattern.include?('class ')
    elements << :module if pattern.include?('module ')
    elements << :conditional if pattern.include?('if ') || pattern.include?('unless ')
    elements << :loop if pattern.include?('while ') || pattern.include?('for ')
    elements
  end

  # Analyze hermetic resonance of pattern
  def analyze_hermetic_resonance(pattern)
    resonance = HermeticSymbolicOracle.principle_for_pattern(pattern)
    resonance || { principle: :unknown, vibration: :neutral }
  end

  # Analyze transformation safety
  def analyze_transformation_safety(match)
    # Simple safety heuristic based on match characteristics
    safety_score = 0.8 # Base safety

    # Adjust based on match complexity
    if match[:range]
      lines_affected = match[:range][:end][:line] - match[:range][:start][:line]
      safety_score -= lines_affected * 0.05
    end

    { score: safety_score.clamp(0.0, 1.0), level: safety_score > 0.7 ? :safe : :risky }
  end

  # Analyze transformation impact
  def analyze_transformation_impact(match)
    # Simple impact analysis
    impact_level = :low

    if match[:text]&.include?('def ') || match[:text]&.include?('class ')
      impact_level = :high
    elsif match[:text]&.include?('if ') || match[:text]&.include?('while ')
      impact_level = :medium
    end

    { level: impact_level, description: "#{impact_level} impact transformation" }
  end

  # Suggest rewrite pattern
  def suggest_rewrite_pattern(match, original_pattern)
    # Simple rewrite suggestion based on pattern structure
    if original_pattern.include?('$METHOD')
      "def new_#{match.dig(:metaVariables, :single, :METHOD, :text) rescue 'method'}"
    elsif original_pattern.include?('$CLASS')
      "class New#{match.dig(:metaVariables, :single, :CLASS, :text) rescue 'Class'}"
    else
      "#{match[:text]} # transformed"
    end
  end

  # Calculate overall safety score
  def calculate_overall_safety(transformations)
    safety_scores = transformations.map { |t| t[:safety][:score] }
    safety_scores.empty? ? 1.0 : safety_scores.sum / safety_scores.size
  end

  # Calculate overall impact level
  def calculate_overall_impact(transformations)
    impact_levels = transformations.map { |t| t[:impact][:level] }
    
    if impact_levels.include?(:high)
      :high
    elsif impact_levels.include?(:medium)
      :medium
    else
      :low
    end
  end

  # Analyze file structure for comprehensive analysis
  def analyze_file_structure(file_path)
    return {} unless File.exist?(file_path)
    
    content = File.read(file_path)
    {
      lines: content.lines.size,
      methods: content.scan(/def\s+\w+/).size,
      classes: content.scan(/class\s+\w+/).size,
      modules: content.scan(/module\s+\w+/).size
    }
  end

  # Assess pattern compatibility with file
  def assess_pattern_compatibility(patch_text, file_path)
    return { compatible: false } unless File.exist?(file_path)
    
    content = File.read(file_path)
    patterns = extract_ast_grep_patterns(patch_text)
    
    {
      compatible: !patterns.empty?,
      patterns_found: patterns,
      file_complexity: content.lines.size
    }
  end
  
  # Phase 3: Advanced Feature Integration Methods
  
  # Create AST-GREP project configuration file
  def create_ast_grep_config(config_data)
    config_file = Tempfile.new(['ast_grep_config', '.yml'])
    config_file.write(YAML.dump(config_data))
    config_file.close
    config_file.path
  end

  # Advanced pattern matching with context lines
  def pattern_match_with_context(file_path, pattern, lang: nil, context_lines: 3, strictness: :smart)
    args = ['ast-grep', 'run', '--pattern', pattern]
    args += ['--lang', lang] if lang
    args += ['--strictness', strictness.to_s] if strictness
    args += ['--context', context_lines.to_s]
    args << file_path

    stdout, stderr, status = Open3.capture3(*args)

    if status.success?
      {
        success: true,
        matches: parse_contextual_matches(stdout),
        context_lines: context_lines
      }
    else
      {
        success: false,
        error: stderr,
        status: status.exitstatus
      }
    end
  end

  # Parse contextual matches with surrounding code
  def parse_contextual_matches(output)
    matches = []
    current_match = nil
    
    output.lines.each do |line|
      if line.start_with?('---')
        # Start of match context
        matches << current_match if current_match
        current_match = { context: [] }
      elsif line.start_with?('+++')
        # End of match context
        current_match[:match] = line[3..-1].strip if current_match
      elsif current_match
        # Context line
        current_match[:context] << line.strip
      end
    end
    
    matches << current_match if current_match
    matches
  end

  # Batch pattern matching with parallel processing
  def batch_pattern_match(file_patterns, pattern, lang: nil, parallel: true)
    patterns = file_patterns.is_a?(Array) ? file_patterns : [file_patterns]
    
    if parallel && patterns.size > 1
      # Parallel processing for multiple files
      results = patterns.map do |file_pattern|
        Thread.new do
          pattern_match_with_context(file_pattern, pattern, lang: lang)
        end
      end.map(&:value)
      
      {
        success: results.all? { |r| r[:success] },
        results: results,
        processed_in_parallel: true
      }
    else
      # Sequential processing
      results = patterns.map do |file_pattern|
        pattern_match_with_context(file_pattern, pattern, lang: lang)
      end
      
      {
        success: results.all? { |r| r[:success] },
        results: results,
        processed_in_parallel: false
      }
    end
  end

  # Pattern similarity analysis
  def analyze_pattern_similarity(pattern1, pattern2, lang: nil)
    # Create test files with representative code
    test_file1 = create_pattern_test_file(pattern1, lang)
    test_file2 = create_pattern_test_file(pattern2, lang)
    
    # Find matches for both patterns
    result1 = pattern_match_with_context(test_file1, pattern1, lang: lang)
    result2 = pattern_match_with_context(test_file2, pattern2, lang: lang)
    
    # Calculate similarity based on match characteristics
    similarity_score = calculate_pattern_similarity_score(result1, result2)
    
    # Clean up test files
    File.unlink(test_file1) if File.exist?(test_file1)
    File.unlink(test_file2) if File.exist?(test_file2)
    
    {
      similarity_score: similarity_score,
      pattern1_matches: result1[:matches]&.size || 0,
      pattern2_matches: result2[:matches]&.size || 0,
      analysis: analyze_pattern_differences(pattern1, pattern2)
    }
  end

  # Create test file for pattern analysis
  def create_pattern_test_file(pattern, lang)
    test_file = Tempfile.new(['pattern_test', file_extension_for_lang(lang)])
    
    # Generate representative code based on pattern type
    test_code = generate_test_code_for_pattern(pattern, lang)
    test_file.write(test_code)
    test_file.close
    
    test_file.path
  end

  # Generate test code based on pattern characteristics
  def generate_test_code_for_pattern(pattern, lang)
    case lang
    when 'ruby'
      if pattern.include?('def ')
        "def test_method\n  # test content\nend"
      elsif pattern.include?('class ')
        "class TestClass\n  # test content\nend"
      else
        "# Test code for pattern analysis"
      end
    else
      "// Test code for pattern analysis"
    end
  end

  # Calculate pattern similarity score
  def calculate_pattern_similarity_score(result1, result2)
    return 0.0 unless result1[:success] && result2[:success]
    
    matches1 = result1[:matches] || []
    matches2 = result2[:matches] || []
    
    # Simple similarity heuristic based on match count and context
    total_matches = matches1.size + matches2.size
    return 1.0 if total_matches == 0
    
    common_elements = matches1.size.to_f / total_matches
    common_elements.clamp(0.0, 1.0)
  end

  # Analyze pattern differences
  def analyze_pattern_differences(pattern1, pattern2)
    {
      meta_variables_diff: analyze_meta_variable_differences(pattern1, pattern2),
      structural_diff: analyze_structural_differences(pattern1, pattern2),
      complexity_diff: (calculate_pattern_complexity(pattern1) - calculate_pattern_complexity(pattern2)).abs
    }
  end

  # Analyze meta variable differences
  def analyze_meta_variable_differences(pattern1, pattern2)
    vars1 = extract_meta_variables(pattern1)
    vars2 = extract_meta_variables(pattern2)
    
    {
      unique_to_pattern1: vars1 - vars2,
      unique_to_pattern2: vars2 - vars1,
      common: vars1 & vars2
    }
  end

  # Analyze structural differences
  def analyze_structural_differences(pattern1, pattern2)
    elements1 = detect_structural_elements(pattern1)
    elements2 = detect_structural_elements(pattern2)
    
    {
      unique_to_pattern1: elements1 - elements2,
      unique_to_pattern2: elements2 - elements1,
      common: elements1 & elements2
    }
  end

  # Get file extension for language
  def file_extension_for_lang(lang)
    case lang
    when 'ruby' then '.rb'
    when 'javascript' then '.js'
    when 'python' then '.py'
    when 'java' then '.java'
    else '.txt'
    end
  end

  # Advanced error analysis with pattern debugging
  def debug_pattern_match(file_path, pattern, lang: nil)
    # First attempt normal matching
    normal_result = pattern_match_with_context(file_path, pattern, lang: lang)
    
    # Consider pattern valid if we get matches or if the pattern syntax is valid
    pattern_valid = normal_result[:success] &&
                   (normal_result[:matches]&.any? || validate_pattern_syntax(pattern, lang))
    
    if pattern_valid
      return normal_result.merge(debug_info: { status: 'success', analysis: 'pattern_valid' })
    end
    
    # If pattern matching fails or returns no matches with invalid syntax, try debug mode
    args = ['ast-grep', 'run', '--pattern', pattern, '--debug-query']
    args += ['--lang', lang] if lang
    args << file_path

    stdout, stderr, status = Open3.capture3(*args)
    
    pattern_analysis = analyze_pattern_validity(pattern, lang) || {}
    suggestions = suggest_pattern_fixes(pattern, lang) || []
    
    {
      success: false,
      error: stderr,
      debug_output: stdout,
      pattern_analysis: pattern_analysis,
      suggestions: suggestions
    }
  end

  # Analyze pattern validity
  def analyze_pattern_validity(pattern, lang)
    return {} if pattern.nil? || pattern.empty?
    
    {
      has_meta_variables: pattern.match?(/\$[A-Z_]+/),
      has_valid_syntax: validate_pattern_syntax(pattern, lang),
      structural_elements: detect_structural_elements(pattern),
      complexity_level: calculate_pattern_complexity(pattern)
    }
  end

  # Validate pattern syntax
  def validate_pattern_syntax(pattern, lang)
    # More strict syntax validation
    return false if pattern.nil? || pattern.empty? || pattern.length > 1000
    
    # Check for basic AST-GREP pattern structure
    # Valid patterns should contain some recognizable elements
    has_meta_variables = pattern.match?(/\$[A-Z_]+/)
    has_structural_elements = pattern.match?(/(def |class |module |if |while |for )/)
    has_quoted_content = pattern.match?(/['"].*['"]/)
    
    # Consider pattern valid if it has at least one of these elements
    has_meta_variables || has_structural_elements || has_quoted_content
  end

  # Suggest pattern fixes
  def suggest_pattern_fixes(pattern, lang)
    suggestions = []
    
    unless pattern.match?(/\$[A-Z_]+/)
      suggestions << "Consider adding meta variables (e.g., $METHOD, $CLASS) for better matching"
    end
    
    if pattern.length > 500
      suggestions << "Pattern is very long. Consider breaking it into smaller components"
    end
    
    suggestions
  end

  # Performance optimization for large-scale operations
  def optimize_pattern_matching(file_patterns, patterns, lang: nil, batch_size: 10)
    # Group patterns by complexity for optimal execution order
    grouped_patterns = patterns.group_by do |pattern|
      complexity = calculate_pattern_complexity(pattern)
      case complexity
      when 0..3 then :simple
      when 4..7 then :medium
      else :complex
      end
    end
    
    # Process simple patterns first, then complex ones
    results = {}
    
    [:simple, :medium, :complex].each do |complexity_level|
      patterns_group = grouped_patterns[complexity_level] || []
      
      # Process in batches
      patterns_group.each_slice(batch_size) do |batch_patterns|
        batch_results = batch_patterns.map do |pattern|
          batch_pattern_match(file_patterns, pattern, lang: lang, parallel: true)
        end
        
        results[complexity_level] ||= []
        results[complexity_level].concat(batch_results)
      end
    end
    
    results.merge({
      optimization_strategy: 'complexity_based_batching',
      batch_size: batch_size,
      total_patterns: patterns.size
    })
  end

  # Enhanced pattern transformation with safety checks
  def safe_pattern_transform(file_path, pattern, rewrite, lang: nil, safety_threshold: 0.8)
    # First analyze the transformation
    analysis = analyze_pattern_transformations(file_path, pattern, lang: lang)
    
    unless analysis[:success]
      return { success: false, error: 'Pattern analysis failed', analysis: analysis }
    end
    
    # Check safety score
    safety_score = analysis[:safety_score]
    if safety_score < safety_threshold
      return {
        success: false,
        error: "Transformation safety score #{safety_score} below threshold #{safety_threshold}",
        analysis: analysis,
        safety_violations: identify_safety_violations(analysis)
      }
    end
    
    # Apply transformation if safe
    apply_advanced_semantic_patch(file_path, pattern, rewrite, lang: lang)
  end

  # Identify safety violations in transformation analysis
  def identify_safety_violations(analysis)
    violations = []
    
    if analysis[:safety_score] < 0.7
      violations << "Low safety score: #{analysis[:safety_score]}"
    end
    
    if analysis[:impact_level] == :high
      violations << "High impact transformation detected"
    end
    
    analysis[:transformations]&.each do |transformation|
      if transformation[:safety][:level] == :risky
        violations << "Risky transformation: #{transformation[:match][:text] rescue 'unknown'}"
      end
    end
    
    violations
  end

  # Cross-file dependency analysis
  def analyze_cross_file_dependencies(file_patterns, pattern, lang: nil)
    # Find all matches across files
    matches_result = batch_pattern_match(file_patterns, pattern, lang: lang)
    
    unless matches_result[:success]
      return { success: false, error: 'Pattern matching failed', matches_result: matches_result }
    end
    
    # Analyze dependencies between matches
    dependencies = analyze_match_dependencies(matches_result[:results])
    
    {
      success: true,
      matches: matches_result[:results],
      dependencies: dependencies,
      dependency_graph: build_dependency_graph(dependencies),
      transformation_order: suggest_transformation_order(dependencies)
    }
  end

  # Analyze dependencies between matches
  def analyze_match_dependencies(match_results)
    dependencies = []
    
    match_results.each do |result|
      next unless result[:success] && result[:matches]
      
      result[:matches].each do |match|
        # Simple dependency analysis based on file relationships
        # In practice, this would analyze import/require relationships
        dependencies << {
          file: result[:file_pattern],
          match: match,
          depends_on: analyze_file_dependencies(result[:file_pattern])
        }
      end
    end
    
    dependencies
  end

  # Analyze file dependencies (placeholder implementation)
  def analyze_file_dependencies(file_path)
    # In practice, this would analyze import/require statements
    # For now, return empty array
    []
  end

  # Build dependency graph
  def build_dependency_graph(dependencies)
    graph = {}
    
    dependencies.each do |dep|
      graph[dep[:file]] ||= { dependencies: [], dependents: [] }
      graph[dep[:file]][:dependencies] = dep[:depends_on]
      
      # Add reverse dependencies
      dep[:depends_on].each do |dependency|
        graph[dependency] ||= { dependencies: [], dependents: [] }
        graph[dependency][:dependents] << dep[:file]
      end
    end
    
    graph
  end

  # Suggest transformation order based on dependencies
  def suggest_transformation_order(dependencies)
    # Simple topological sort (in practice would use more sophisticated algorithm)
    files = dependencies.map { |dep| dep[:file] }.uniq
    files.sort_by { |file| file_dependency_depth(file, build_dependency_graph(dependencies)) }
  end

  # Calculate file dependency depth
  def file_dependency_depth(file, graph, visited = Set.new)
    return 0 if visited.include?(file)
    visited.add(file)
    
    dependencies = graph[file]&.[](:dependencies) || []
    return 0 if dependencies.empty?
    
    1 + dependencies.map { |dep| file_dependency_depth(dep, graph, visited) }.max
  end

  # Make advanced methods public for testing and external use
  SymbolicPatchFile.module_eval do
    public :apply_yaml_rule_patch, :apply_dsl_rule_patch, :apply_simple_pattern_patch,
           :apply_auto_level_patch, :calculate_transformation_complexity,
           :apply_cross_file_yaml, :apply_cross_file_dsl, :apply_cross_file_simple,
           :analyze_pattern_matches, :analyze_pattern_context, :analyze_pattern_transformations,
           :apply_enhanced_dsl_patch, :build_pattern, :build_constraints,
           :apply_composite_pattern, :apply_structural_pattern,
           # Phase 3 Advanced Features
           :pattern_match_with_context, :batch_pattern_match, :analyze_pattern_similarity,
           :debug_pattern_match, :optimize_pattern_matching, :safe_pattern_transform,
           :analyze_cross_file_dependencies
  end
end
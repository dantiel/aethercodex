# frozen_string_literal: true

require_relative 'hermetic_symbolic_analysis'
require_relative 'diff_crepusculum'

# Semantic Patch Engine - AST-GREP powered code transformations
module SemanticPatch
  extend self

  # Apply semantic patch using AST-GREP
  def apply_semantic_patch(file_path, search_pattern, replace_pattern, lang: nil)
    HermeticSymbolicAnalysis.ast_grep_execute(
      [file_path],
      pattern: search_pattern,
      rewrite: replace_pattern,
      lang: lang
    )
  end

  # Hybrid patch application - tries semantic first, falls back to line-based
  def apply_hybrid_patch(file_path, patch_text, lang: nil)
    # First attempt semantic patch
    semantic_result = try_semantic_patch(file_path, patch_text, lang: lang)
    
    if semantic_result[:success]
      return semantic_result
    end
    
    # Fall back to line-based patching
    fallback_to_line_based(file_path, patch_text)
  end

  # Try to convert and apply as semantic patch
  def try_semantic_patch(file_path, patch_text, lang: nil)
    semantic_patch = HermeticSymbolicAnalysis.convert_to_semantic_patch(patch_text, lang: lang)
    
    return { error: "Cannot convert to semantic patch" } unless semantic_patch
    
    apply_semantic_patch(
      file_path,
      semantic_patch[:search],
      semantic_patch[:replace],
      lang: lang
    )
  end

  # Fallback to traditional line-based patching
  def fallback_to_line_based(file_path, patch_text)
    # Read the original content
    original_content = File.read(file_path)
    
    # Apply using existing diff_crepusculum
    diff_engine = DiffCrepusculum::ChrysopoeiaDiff.new
    result = diff_engine.apply_diff(original_content, patch_text)
    
    if result[:success]
      File.write(file_path, result[:content])
      {
        ok: true,
        result: [original_content, result[:content]],
        method: :line_based,
        original_content: original_content
      }
    else
      { error: result[:fail_parts], method: :line_based }
    end
  end

  # Analyze patch to determine best approach
  def analyze_patch_strategy(patch_text, file_path = nil)
    lang = file_path ? HermeticSymbolicAnalysis.detect_language(file_path) : nil
    
    # Check if patch can be converted to semantic pattern
    semantic_patch = HermeticSymbolicAnalysis.convert_to_semantic_patch(patch_text, lang: lang)
    
    analysis = {
      can_be_semantic: !!semantic_patch,
      semantic_pattern: semantic_patch,
      recommended_approach: semantic_patch ? :semantic : :line_based,
      confidence: semantic_patch ? 0.8 : 1.0
    }
    
    # Additional analysis based on patch content
    lines = patch_text.lines
    analysis[:line_count] = lines.size
    analysis[:has_complex_indentation] = lines.any? { |line| line.start_with?('    ') || line.start_with?('\t') }
    
    analysis
  end

  # Batch apply patches with intelligent routing
  def apply_patches(patches)
    results = []
    
    patches.each do |patch|
      file_path = patch[:path]
      patch_text = patch[:diff]
      
      # Analyze patch to determine best strategy
      analysis = analyze_patch_strategy(patch_text, file_path)
      
      if analysis[:recommended_approach] == :semantic
        result = try_semantic_patch(file_path, patch_text)
        result[:strategy] = :semantic
      else
        result = fallback_to_line_based(file_path, patch_text)
        result[:strategy] = :line_based
      end
      
      results << result.merge(analysis: analysis)
    end
    
    results
  end

  # Create semantic patch pattern from examples
  def learn_from_examples(file_path, examples)
    # This would implement machine learning to derive patterns
    # from multiple examples of similar transformations
    
    patterns = examples.map do |example|
      HermeticSymbolicAnalysis.convert_to_semantic_patch(example[:patch])
    end.compact
    
    # Find common patterns across examples
    common_pattern = derive_common_pattern(patterns)
    
    common_pattern
  end

  private

  # Derive common pattern from multiple semantic patches
  def derive_common_pattern(patterns)
    return patterns.first if patterns.size == 1
    
    # Simple heuristic - in real implementation would use more sophisticated analysis
    search_patterns = patterns.map { |p| p[:search] }
    replace_patterns = patterns.map { |p| p[:replace] }
    
    {
      search: most_common_pattern(search_patterns),
      replace: most_common_pattern(replace_patterns)
    }
  end

  # Find most common pattern (simplified)
  def most_common_pattern(patterns)
    patterns.max_by { |p| patterns.count(p) }
  end
end
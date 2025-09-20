# frozen_string_literal: true

require_relative 'semantic_patch'
require_relative 'hermetic_execution_domain'
require_relative 'hermetic_symbolic_analysis'
require_relative '../argonaut/argonaut'
require 'tempfile'

# Symbolic Patch File Tool
# Provides a clean interface for semantic patching operations
module SymbolicPatchFile
  extend self

  # Apply semantic patch to file
  # @param file_path [String] Path to the file to patch
  # @param search_pattern [String] AST-GREP search pattern
  # @param replace_pattern [String] AST-GREP replace pattern
  # @param lang [String, nil] Language hint (auto-detected if nil)
  # @return [Hash] Result of the operation
  def apply(file_path, search_pattern, replace_pattern, lang: nil)
    HermeticExecutionDomain.execute do
      # Use proper path resolution like other tools
      resolved_path = Argonaut.relative_path(file_path)
      SemanticPatch.apply_semantic_patch(resolved_path, search_pattern, replace_pattern, lang: lang)
    end
  end

  # Hybrid patch application - tries semantic first, falls back to line-based
  # @param file_path [String] Path to the file to patch
  # @param patch_text [String] Traditional patch text
  # @param lang [String, nil] Language hint
  # @return [Hash] Result with strategy information
  def apply_hybrid(file_path, patch_text, lang: nil)
    HermeticExecutionDomain.execute do
      SemanticPatch.apply_hybrid_patch(file_path, patch_text, lang: lang)
    end
  end

  # Analyze patch to determine best approach
  # @param patch_text [String] Patch text to analyze
  # @param file_path [String, nil] Optional file path for language detection
  # @return [Hash] Analysis results
  def analyze(patch_text, file_path = nil)
    SemanticPatch.analyze_patch_strategy(patch_text, file_path)
  end

  # Batch apply multiple patches with intelligent routing
  # @param patches [Array<Hash>] Array of patch specifications
  # @return [Array<Hash>] Results for each patch
  def apply_batch(patches)
    HermeticExecutionDomain.execute do
      SemanticPatch.apply_patches(patches)
    end
  end

  # Create and apply semantic patch from method transformation
  # @param file_path [String] Path to the file
  # @param method_name [String] Method name to transform
  # @param new_method_name [String, nil] New method name (for renaming)
  # @param new_body [String, nil] New method body
  # @return [Hash] Result of the transformation
  def transform_method_with_ast(file_path, method_name, new_method_name: nil, new_body: nil, selector: nil, context: nil)
    HermeticExecutionDomain.execute do
      # Use proper path resolution like other tools
      resolved_path = Argonaut.relative_path(file_path)
      lang = HermeticSymbolicAnalysis.detect_language(resolved_path)
      
      # Use AST-GREP selector pattern if provided
      if selector
        search_pattern = selector.gsub('$METHOD', method_name)
        replace_pattern = selector.gsub('$METHOD', new_method_name) if new_method_name
        
        result = SemanticPatch.apply_semantic_patch(resolved_path, search_pattern, replace_pattern, lang: lang)
        return result
      end
      
      if new_method_name
        # Rename method using AST pattern
        search_pattern = "def #{method_name}"
        replace_pattern = "def #{new_method_name}"
        result = SemanticPatch.apply_semantic_patch(resolved_path, search_pattern, replace_pattern, lang: lang)
        return result
      end
      
      if new_body
        # For body replacement, we need a more complex approach
        # This is a limitation of current AST-GREP patterns
        # Fall back to line-based patching for complex transformations
        return {
          success: false,
          error: "Complex method body replacement not yet supported. Use line-based patching for now.",
          recommendation: "Use patch_file for complex method transformations"
        }
      end
      
      { success: true }
    end
  end
  

  # Create and apply semantic patch for class transformation
  # @param file_path [String] Path to the file
  # @param class_name [String] Class name to transform
  # @param new_class_name [String, nil] New class name
  # @param new_body [String, nil] New class body
  # @return [Hash] Result of the transformation
  def transform_class_with_ast(file_path, class_name, new_class_name: nil, new_body: nil, selector: nil, context: nil)
    HermeticExecutionDomain.execute do
      # Use proper path resolution like other tools
      resolved_path = Argonaut.relative_path(file_path)
      lang = HermeticSymbolicAnalysis.detect_language(resolved_path)
      
      if new_class_name
        # Rename class using simple text replacement
        search_pattern = class_name
        replace_pattern = new_class_name
        SemanticPatch.apply_semantic_patch(resolved_path, search_pattern, replace_pattern, lang: lang)
      end
      
      if new_body
        # Complex class body replacement not supported yet
        return {
          success: false,
          error: "Complex class body replacement not yet supported. Use line-based patching for now.",
          recommendation: "Use patch_file for complex class transformations"
        }
      end
      
      { success: true }
    end
  end

  # Add documentation to a method
  # @param file_path [String] Path to the file
  # @param method_name [String] Method name to document
  # @param documentation [String] Documentation text
  # @return [Hash] Result of the operation
  def document_method_with_ast(file_path, method_name, documentation, selector: nil, context: nil)
      # Use proper path resolution like other tools
      resolved_path = Argonaut.relative_path(file_path)
      lang = HermeticSymbolicAnalysis.detect_language(resolved_path)
      
      # Use a more specific pattern to target only the method definition
      search_pattern = "def #{method_name}"
      replace_pattern = "# #{documentation}\ndef #{method_name}"
      
      SemanticPatch.apply_semantic_patch(resolved_path, search_pattern, replace_pattern, lang: lang)
    end

  # Find and replace text with semantic context awareness
  # @param file_path [String] Path to the file
  # @param search_text [String] Text to search for
  # @param replace_text [String] Text to replace with
  # @param context_pattern [String, nil] Optional context pattern for precision
  # @return [Hash] Result of the operation
  def find_and_replace_with_ast(file_path, search_text, replace_text, context_pattern: nil, selector: nil, ast_pattern: nil)
      # Use proper path resolution like other tools
      resolved_path = Argonaut.relative_path(file_path)
      lang = HermeticSymbolicAnalysis.detect_language(resolved_path)
      
      if context_pattern
        # Use context-aware replacement
        search_pattern = context_pattern.gsub('$TEXT', search_text)
        replace_pattern = context_pattern.gsub('$TEXT', replace_text)
      else
        # Simple text replacement
        search_pattern = search_text
        replace_pattern = replace_text
      end
      
      SemanticPatch.apply_semantic_patch(resolved_path, search_pattern, replace_pattern, lang: lang)
    end

  # Test if semantic patching is available and working
  # @return [Hash] Status information
  def status
    HermeticExecutionDomain.execute do
      # Test with a simple pattern
      test_file = Tempfile.new(['symbolic_test', '.rb'])
      test_file.write("def test_method; 'hello'; end")
      test_file.close
      
      result = apply(test_file.path, "def test_method; end", "def test_method; 'world' end", lang: 'ruby')
      
      test_content = File.read(test_file.path)
      test_file.unlink
      
      {
        available: true,
        test_result: result,
        test_content: test_content,
        ast_grep_installed: system('which ast-grep > /dev/null 2>&1')
      }
    rescue => e
      {
        available: false,
        error: e.message,
        ast_grep_installed: system('which ast-grep > /dev/null 2>&1')
      }
    end
  end
end
# Enhanced Symbolic Patching with AST-GREP

## Overview

The symbolic patch tool has been significantly enhanced to leverage AST-GREP's advanced capabilities for sophisticated code transformations. This revision provides comprehensive support for AST-GREP's extended features while maintaining backward compatibility.

## Key Enhancements

### 1. Advanced Operation Modes

**New operation modes provide granular control over transformation strategies:**

- **`simple_replace`**: Direct text replacement (backward compatible)
- **`pattern_match`**: AST pattern matching with meta variables
- **`structural_rewrite`**: Structural tree rewriting with constraints
- **`multi_file`**: Cross-file transformations (future enhancement)
- **`interactive`**: Interactive patch application (future enhancement)
- **`constraint_based`**: Constraint-driven transformations
- **`utility_reuse`**: Rule utility composition
- **`elemental`**: Elemental pattern transformations (hermetic)
- **`planetary`**: Planetary semantic transformations (hermetic)
- **`alchemical`**: Alchemical code purification (hermetic)

### 2. Enhanced Pattern Types

**Support for AST-GREP's comprehensive pattern system:**

- **Meta Variables**: `$VAR` - matches any single AST node
- **Multi Meta Variables**: `$$$` - matches zero or more AST nodes
- **Kind Selectors**: `kind: function` - matches by node kind
- **Relational Patterns**: `inside: { kind: class }` - relational constraints
- **Composite Patterns**: `all: [pattern1, pattern2]` - composite patterns
- **Regex Constraints**: `regex: \\w+` - regex constraints on meta variables

### 3. Intelligent Strategy Selection

**Automatic analysis determines the optimal patching strategy:**

```ruby
# Intelligent hybrid patching
result = SymbolicPatchFile.apply_hybrid(
  file_path, patch_text, 
  strategy_analysis: true
)
```

**Features:**
- Automatic complexity analysis
- Semantic compatibility assessment
- Structural pattern detection
- Confidence-based strategy selection

### 4. Advanced Method Transformations

**Comprehensive method transformation support:**

```ruby
# Method renaming with constraints
result = SymbolicPatchFile.transform_method(
  file_path, 'old_method', 
  new_method_name: 'new_method',
  transformation_type: :rename
)

# Method body replacement
result = SymbolicPatchFile.transform_method(
  file_path, 'method_name',
  new_body: 'new implementation',
  transformation_type: :body_replacement
)
```

### 5. Enhanced Class Transformations

**Advanced class-level transformations:**

```ruby
# Class renaming
result = SymbolicPatchFile.transform_class(
  file_path, 'OldClass',
  new_class_name: 'NewClass',
  transformation_type: :rename
)

# Class body replacement
result = SymbolicPatchFile.transform_class(
  file_path, 'ClassName',
  new_body: 'new class implementation',
  transformation_type: :body_replacement
)
```

### 6. Sophisticated Documentation

**Flexible documentation addition with multiple formats:**

```ruby
# Single-line documentation
result = SymbolicPatchFile.document_method(
  file_path, 'method_name', 'Method description',
  doc_type: :single_line
)

# Multi-line documentation
result = SymbolicPatchFile.document_method(
  file_path, 'method_name', 'Line1\nLine2\nLine3',
  doc_type: :multi_line
)

# YARDoc format
result = SymbolicPatchFile.document_method(
  file_path, 'method_name', 'Method documentation',
  doc_type: :yardoc
)
```

### 7. Advanced Find and Replace

**Context-aware find and replace with multiple strategies:**

```ruby
# Semantic replacement
result = SymbolicPatchFile.find_and_replace(
  file_path, 'old_text', 'new_text',
  replacement_strategy: :semantic
)

# Structural replacement
result = SymbolicPatchFile.find_and_replace(
  file_path, 'pattern', 'replacement',
  replacement_strategy: :structural
)

# Context-aware replacement
result = SymbolicPatchFile.find_and_replace(
  file_path, 'text', 'replacement',
  context_pattern: 'class $CLASS { $TEXT }',
  replacement_strategy: :semantic
)
```

### 8. Batch Processing Enhancements

**Intelligent batch processing with dependency analysis:**

```ruby
# Optimized batch processing
result = SymbolicPatchFile.apply_batch(
  patches,
  parallel_processing: true,
  dependency_analysis: true
)
```

**Features:**
- Automatic dependency analysis
- Optimized execution order
- Parallel processing support
- Comprehensive result analysis

## Usage Examples

### Basic Usage (Backward Compatible)

```ruby
# Simple method renaming
result = SymbolicPatchFile.transform_method(
  'file.rb', 'old_name', 
  new_method_name: 'new_name'
)

# Basic find and replace
result = SymbolicPatchFile.find_and_replace(
  'file.rb', 'old_text', 'new_text'
)
```

### Advanced Usage

```ruby
# Advanced method transformation with constraints
result = SymbolicPatchFile.transform_method(
  'file.rb', 'method_name',
  new_body: 'new implementation',
  transformation_type: :body_replacement
)

# Structural class transformation
result = SymbolicPatchFile.transform_class(
  'file.rb', 'ClassName',
  new_body: 'class ClassName\n  def new_method\n    # implementation\n  end\nend',
  transformation_type: :body_replacement
)

# Pattern-based transformation
result = SymbolicPatchFile.apply(
  'file.rb', 
  'def $METHOD; $BODY; end',
  'def $METHOD; # enhanced: $BODY; end',
  operation_mode: :pattern_match
)
```

### Hermetic Integration

```ruby
# Elemental transformation (fire - transformative operations)
result = SymbolicPatchFile.apply(
  'file.rb', 'pattern', 'replacement',
  resonance: :fire
)

# Planetary transformation (solar - core logic)
result = SymbolicPatchFile.apply(
  'file.rb', 'pattern', 'replacement',
  resonance: :solar
)
```

## Pattern Examples

### Meta Variable Patterns

```ruby
# Match any method definition
pattern = 'def $METHOD; end'

# Match method calls with any arguments
pattern = '$OBJECT.$METHOD($$$ARGS)'

# Match class definitions with inheritance
pattern = 'class $CLASS < $PARENT; end'
```

### Constraint-Based Patterns

```ruby
# Match only numeric literals
pattern = '$NUM'
constraints = { NUM: { kind: 'number' } }

# Match method calls with specific context
pattern = '$CALL'
constraints = { 
  CALL: { 
    inside: { kind: 'method' },
    regex: '^[a-z]\\w+$'
  }
}
```

### Composite Patterns

```ruby
# Match both function declarations and expressions
pattern = {
  any: [
    { pattern: 'function $NAME() {}' },
    { pattern: 'const $NAME = () => {}' }
  ]
}
```

## Error Handling and Diagnostics

### Comprehensive Status Checking

```ruby
# Check tool status and capabilities
status = SymbolicPatchFile.status
puts "AST-GREP Version: #{status[:version]}"
puts "Advanced Features: #{status[:advanced_features]}"
```

### Enhanced Error Reporting

```ruby
# Rich error information
result = SymbolicPatchFile.apply('file.rb', 'pattern', 'replacement')

if result[:success]
  puts "Transformation successful"
  puts "Matches: #{result[:result][:match_count]}"
  puts "Pattern Analysis: #{result[:pattern_analysis]}"
else
  puts "Error: #{result[:error]}"
  puts "Operation Mode: #{result[:operation_mode]}"
end
```

## Performance Optimizations

### Intelligent Strategy Selection

The tool automatically analyzes patch complexity and selects the optimal strategy:

- **Simple patches**: Direct semantic application
- **Complex patches**: Hybrid approach with fallback
- **Structural changes**: Advanced AST-GREP features

### Batch Optimization

Batch processing includes:
- Dependency analysis
- Execution order optimization
- Parallel processing
- Memory-efficient transformations

## Integration with Hermetic System

### Vibrational Analysis

```ruby
# Analyze file vibrations
analysis = SymbolicPatchFile.oracular_analysis('file.rb')
puts "Elemental Patterns: #{analysis[:elemental]}"
puts "Planetary Patterns: #{analysis[:planetary]}"
```

### Resonance-Based Transformations

```ruby
# Apply transformation with elemental resonance
result = SymbolicPatchFile.transform_with_resonance(
  'file.rb',
  {
    type: :method_rename,
    target: 'old_method',
    new_value: 'new_method',
    resonance: :fire
  }
)
```

## Migration Guide

### From Previous Version

**Backward Compatibility:** All existing code continues to work without changes.

**New Features:** Gradually adopt advanced features for improved precision and performance.

**Recommended Migration Steps:**
1. Update tool calls to include `operation_mode` parameter
2. Use enhanced error reporting for better diagnostics
3. Implement strategy analysis for complex transformations
4. Explore hermetic integration for advanced use cases

## Conclusion

The enhanced symbolic patch tool provides a comprehensive solution for code transformations, combining AST-GREP's advanced capabilities with intelligent strategy selection and hermetic integration. This revision maintains backward compatibility while offering significant improvements in precision, performance, and functionality.
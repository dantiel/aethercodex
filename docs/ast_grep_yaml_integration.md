# AST-GREP YAML Rule Integration

Complete integration of AST-GREP's advanced YAML rule capabilities into the Hermetic Symbolic Analysis system.

## Overview

This implementation provides three progressive levels of AST-GREP integration:

1. **Level 1: Simple Patterns** - Basic pattern matching (backward compatible)
2. **Level 2: Rule Builder DSL** - Programmatic rule construction
3. **Level 3: Full YAML Integration** - Complete YAML rule support

## Core Components

### 1. YAML Rule Parser (`HermeticSymbolicAnalysis::YamlRuleParser`)

Parses and validates YAML rules for AST-GREP, supporting:

- **Basic patterns**: Simple search/replace operations
- **Utility composition**: `matches:` directive for rule reuse
- **Constraints**: Meta-variable constraints and validation
- **Strictness levels**: Pattern matching strictness control

#### Example Usage

```ruby
# Parse YAML rule
yaml_rule = <<~YAML
  rule:
    pattern: "def $METHOD"
    rewrite: "def new_$METHOD"
    language: ruby
    strictness: smart
YAML

command = HermeticSymbolicAnalysis::YamlRuleParser.parse_rule(yaml_rule)
```

### 2. Rule Builder DSL (`HermeticSymbolicAnalysis::RuleBuilderDSL`)

Programmatic rule construction with fluent interface:

```ruby
# Build rule using DSL
dsl_rule = HermeticSymbolicAnalysis::RuleBuilderDSL.build_rule do
  pattern "def $METHOD"
  rewrite "def enhanced_$METHOD"
  language "ruby"
  strictness "smart"
  constraint "METHOD", regex: "^[a-z_]+"
  utility "method_pattern", "def $METHOD"
end
```

### 3. Progressive Enhancement Interface

Automatic level selection based on transformation complexity:

```ruby
# Auto-detect optimal level
result = HermeticSymbolicAnalysis.apply_semantic_transformation(
  file_path, 
  { pattern: "def $METHOD", rewrite: "def new_$METHOD" },
  level: :auto
)
```

## Advanced Features

### Cross-File Pattern Matching

Transform patterns across multiple files with project configuration:

```ruby
result = SymbolicPatchFile.cross_file_transform(
  ['**/*.rb', 'lib/**/*.js'],
  "def $METHOD",
  replace_pattern: "def enhanced_$METHOD",
  lang: "ruby",
  project_config: { rules_dir: './ast_grep_rules' }
)
```

### Pattern Analysis and Preview

Analyze patterns before applying transformations:

```ruby
# Analyze matches
matches_result = SymbolicPatchFile.analyze_pattern(
  file_path, "def $METHOD", preview_mode: :matches
)

# Analyze transformations
transform_result = SymbolicPatchFile.analyze_pattern(
  file_path, "def $METHOD", preview_mode: :transformations
)
```

### Utility Rule Composition

Create reusable utility rules for complex pattern matching:

```yaml
# Utility rule definition
utils:
  method_pattern: "def $METHOD"
  class_pattern: "class $CLASS"

rule:
  matches: 
    all: [method_pattern, class_pattern]
```

## Integration with Hermetic Principles

### Elemental Pattern Resonance

Patterns are mapped to hermetic elemental principles:

- **Fire**: Transformative operations (method/class modifications)
- **Water**: Flow operations (control structures)
- **Earth**: Structural operations (class/module definitions)
- **Air**: Abstract operations (imports/dependencies)

### Vibrational Analysis

Each pattern transformation includes vibrational analysis:

```ruby
result = SymbolicPatchFile.apply(
  file_path, "def $METHOD", "def new_$METHOD",
  resonance: :fire,  # Apply fire element transformation
  rule_level: :yaml
)
```

## Usage Examples

### Level 1: Simple Pattern (Backward Compatible)

```ruby
# Simple text replacement
result = SymbolicPatchFile.apply(
  file_path, "old_method", "new_method",
  rule_level: :simple
)
```

### Level 2: DSL Rule Builder

```ruby
# Programmatic rule construction
result = SymbolicPatchFile.apply(
  file_path, "def $METHOD", "def enhanced_$METHOD",
  rule_level: :dsl,
  constraints: { METHOD: { regex: "^[a-z_]+" } }
)
```

### Level 3: Full YAML Integration

```ruby
# Complete YAML rule support
yaml_rule = <<~YAML
  rule:
    pattern: "class $CLASS"
    rewrite: "class Improved$CLASS"
    language: ruby
    constraints:
      CLASS:
        regex: "^[A-Z]"
YAML

result = SymbolicPatchFile.apply(
  file_path, yaml_rule, nil,
  rule_level: :yaml
)
```

## Performance Optimization

### Intelligent Level Selection

The system automatically selects the optimal rule level based on:

- **Pattern complexity**: Meta-variable count and structural elements
- **Constraint requirements**: Validation and transformation complexity
- **Utility composition**: Rule reuse and composition needs

### Batch Operations

Efficient batch processing with dependency analysis:

```ruby
patches = [
  { path: 'file1.rb', search_pattern: 'def $METHOD', replace_pattern: 'def new_$METHOD' },
  { path: 'file2.rb', search_pattern: 'class $CLASS', replace_pattern: 'class New$CLASS' }
]

result = SymbolicPatchFile.apply_batch(
  patches,
  parallel_processing: true,
  dependency_analysis: true
)
```

## Error Handling and Validation

### Comprehensive Error Reporting

- **YAML validation**: Rule structure and syntax validation
- **Pattern validation**: AST-GREP pattern compatibility checking
- **Transformation safety**: Impact analysis and safety scoring
- **Hermetic resonance**: Pattern compatibility with hermetic principles

### Automatic Retry Mechanisms

- **Network issues**: Automatic retry for transient failures
- **Rate limiting**: Exponential backoff for API limits
- **Timeout handling**: Configurable timeout with graceful degradation

## Testing and Validation

### Test Suite

Comprehensive test coverage including:

- **YAML rule parsing**: Validation and command generation
- **DSL rule building**: Programmatic rule construction
- **Cross-file operations**: Multi-file pattern matching
- **Pattern analysis**: Match detection and transformation preview

### Integration Testing

```ruby
# Run integration tests
TestYamlRuleIntegration.run_tests
```

## Configuration

### Project Configuration

Create `.ast-grep.yml` for project-specific settings:

```yaml
rules:
  - id: method_renaming
    pattern: def $METHOD
    rewrite: def new_$METHOD
    
utils:
  method_pattern: def $METHOD
  class_pattern: class $CLASS
```

### Hermetic Configuration

Configure hermetic resonance mappings:

```yaml
hermetic_resonance:
  fire:
    patterns: [def $METHOD, class $CLASS]
    vibration: transformative
  water:
    patterns: [if $COND, while $COND]
    vibration: flowing
```

## Conclusion

The AST-GREP YAML integration provides a comprehensive, hermetic-aligned approach to symbolic code transformation with progressive enhancement from simple patterns to complex YAML rule compositions.
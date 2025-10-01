# Practical Usage Guide

## From Beginner to Master: Progressive Learning Path

> *"The journey of a thousand miles begins with a single step" - Practical guide to mastering the Hermetic Symbolic Oracle*

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Level 1: Simple Patterns](#level-1-simple-patterns)
3. [Level 2: Rule Builder DSL](#level-2-rule-builder-dsl)
4. [Level 3: YAML Rule Mastery](#level-3-yaml-rule-mastery)
5. [Real-World Examples](#real-world-examples)
6. [Common Patterns & Recipes](#common-patterns--recipes)
7. [Troubleshooting Guide](#troubleshooting-guide)
8. [Best Practices](#best-practices)

---

## Getting Started

### Prerequisites

1. **Install AST-GREP**: Ensure `ast-grep` is installed and in your PATH
2. **Project Setup**: Your Ruby project should have the Support directory structure
3. **Basic Understanding**: Familiarity with Ruby and code patterns

### Quick Start Example

```ruby
# Basic require statement
require_relative 'instrumentarium/symbolic_patch_file'

# Simple method renaming
result = SymbolicPatchFile.apply(
  'app/models/user.rb',
  'def old_method_name',
  'def new_method_name'
)

if result[:success]
  puts "✅ Transformation successful!"
else
  puts "❌ Error: #{result[:error]}"
end
```

### System Status Check

```ruby
# Check if everything is working
status = SymbolicPatchFile.status

if status[:available]
  puts "✅ System ready: AST-GREP #{status[:version]}"
  puts "Advanced features: #{status[:advanced_features]}"
else
  puts "❌ System not available: #{status[:error]}"
end
```

---

## Level 1: Simple Patterns

### Basic Text Replacement

**Use Case**: Simple find-and-replace operations

```ruby
# Replace variable name
result = SymbolicPatchFile.apply(
  'calculator.rb',
  'total_sum',
  'final_total'
)

# Replace method call
result = SymbolicPatchFile.apply(
  'api_client.rb',
  'make_request',
  'send_request'
)
```

### Simple AST Patterns

**Use Case**: Pattern-based transformations with meta variables

```ruby
# Rename all methods starting with "old_"
result = SymbolicPatchFile.apply(
  'legacy_code.rb',
  'def old_$METHOD',
  'def new_$METHOD'
)

# Add logging to all methods
result = SymbolicPatchFile.apply(
  'service.rb',
  'def $METHOD($$ARGS)',
  'def $METHOD($$ARGS)\n  logger.info "Method #{$METHOD} called"\n  $$$BODY'
)
```

### Common Simple Patterns

```ruby
# Method patterns
'def $METHOD'                    # Match any method
'def $METHOD($$PARAMS)'          # Match methods with parameters
'def $METHOD; $$$BODY; end'      # Match complete methods

# Class patterns
'class $CLASS'                   # Match any class
'class $CLASS < $PARENT'         # Match classes with inheritance

# Control structures
'if $CONDITION'                  # Match if statements
'while $CONDITION'               # Match while loops
'for $VAR in $COLLECTION'        # Match for loops
```

---

## Level 2: Rule Builder DSL

### Basic DSL Usage

**Use Case**: More complex patterns with constraints

```ruby
require_relative 'instrumentarium/hermetic_symbolic_analysis'

# Build rule with DSL
rule = HermeticSymbolicAnalysis::RuleBuilderDSL.build_rule do
  pattern('def $METHOD')
  rewrite('def new_$METHOD')
  language('ruby')
  strictness('smart')
end

# Apply the rule
result = HermeticSymbolicAnalysis.ast_grep_with_rule(rule, ['file.rb'], apply_changes: true)
```

### Adding Constraints

**Use Case**: Precise pattern matching with conditions

```ruby
# Only match methods with specific naming patterns
rule = HermeticSymbolicAnalysis::RuleBuilderDSL.build_rule do
  pattern('def $METHOD')
  rewrite('def validated_$METHOD')
  constraint('METHOD', regex: '^[a-z_]+$')  # Only lowercase with underscores
  constraint('METHOD', kind: 'identifier')  # Must be valid identifier
end
```

### Using Relational Patterns

**Use Case**: Patterns that depend on context

```ruby
# Only match methods inside specific classes
rule = HermeticSymbolicAnalysis::RuleBuilderDSL.build_rule do
  pattern('def $METHOD')
  rewrite('def documented_$METHOD')
  inside('class User')  # Only inside User class
end

# Match methods that have specific content
rule = HermeticSymbolicAnalysis::RuleBuilderDSL.build_rule do
  pattern('def $METHOD')
  rewrite('def optimized_$METHOD')
  has('@instance_variable')  # Only methods using instance variables
end
```

### Utility Rule Composition

**Use Case**: Reusing common patterns

```ruby
# Define utility for method bodies
rule = HermeticSymbolicAnalysis::RuleBuilderDSL.build_rule do
  pattern('def $METHOD; $$$BODY; end')
  rewrite('def $METHOD; puts "Entering #{$METHOD}"; $$$BODY; end')
  utility('method_body', '$$$')  # Define utility for method bodies
end
```

---

## Level 3: YAML Rule Mastery

### Basic YAML Rule

**Use Case**: Complex multi-file transformations

```yaml
# rule.yaml
rule:
  pattern: "def $METHOD"
  rewrite: "def new_$METHOD"
  language: ruby
  strictness: smart
```

```ruby
# Apply YAML rule
result = HermeticSymbolicAnalysis.ast_grep_with_rule('rule.yaml', ['**/*.rb'])
```

### Advanced YAML with Constraints

```yaml
# advanced_rule.yaml
rule:
  pattern: "def $METHOD"
  rewrite: "def validated_$METHOD"
  language: ruby
  constraints:
    METHOD:
      regex: "^[a-z_]+$"
      kind: identifier
  strictness: strict
```

### Composite Patterns with Matches Directive

```yaml
# composite_rule.yaml
rule:
  matches:
    all:
      - inside: { kind: class }
      - pattern: "def $METHOD"
      - has: "@$IVAR"
  rewrite: "def $METHOD; validate_$IVAR; $$$BODY; end"
utils:
  method_with_validation: "def $METHOD; validate_$IVAR; $$$BODY; end"
```

### Project Configuration

```yaml
# .ast-grep.yml (project configuration)
ruleDirs:
  - ./ast_rules
utils:
  common_patterns: ./utils/common.yml
```

---

## Real-World Examples

### Example 1: Codebase Modernization

**Scenario**: Migrating from legacy naming conventions

```ruby
# Modernize method names across entire codebase
modernization_rules = [
  { search: 'def get_$NAME', replace: 'def fetch_$NAME' },
  { search: 'def set_$NAME', replace: 'def assign_$NAME' },
  { search: 'def is_$NAME', replace: 'def $NAME?' },
  { search: 'def has_$NAME', replace: 'def $NAME?' }
]

modernization_rules.each do |rule|
  result = SymbolicPatchFile.cross_file_transform(
    ['app/**/*.rb', 'lib/**/*.rb'],
    rule[:search],
    replace_pattern: rule[:replace],
    rule_level: :yaml
  )
  
  puts "#{rule[:search]} → #{rule[:replace]}: #{result[:success] ? '✅' : '❌'}"
end
```

### Example 2: Security Hardening

**Scenario**: Adding input validation to all public methods

```yaml
# security_rule.yaml
rule:
  pattern: "def $METHOD($$PARAMS)"
  rewrite: |
    def $METHOD($$PARAMS)
      validate_parameters($$PARAMS)
      $$$ORIGINAL_BODY
    end
  constraints:
    METHOD:
      regex: "^[a-z]"  # Public methods (start with lowercase)
utils:
  parameter_validation: "validate_parameters($$PARAMS)"
```

```ruby
# Apply security hardening
result = SymbolicPatchFile.cross_file_transform(
  ['app/controllers/**/*.rb', 'app/services/**/*.rb'],
  'security_rule.yaml',
  rule_level: :yaml
)
```

### Example 3: Performance Optimization

**Scenario**: Adding caching to expensive method calls

```ruby
# Identify expensive methods through pattern analysis
expensive_methods = SymbolicPatchFile.analyze_pattern(
  'app/services/calculation_service.rb',
  'def $METHOD',
  preview_mode: :transformations
)

# Add caching to identified methods
expensive_methods[:matches].each do |match|
  method_name = match.dig(:metaVariables, :single, :METHOD, :text)
  
  result = SymbolicPatchFile.apply(
    'app/services/calculation_service.rb',
    "def #{method_name}\n  $$$BODY\nend",
    "def #{method_name}\n  Rails.cache.fetch(\"#{method_name}_\" + args_hash) do\n    $$$BODY\n  end\nend",
    rule_level: :dsl
  )
end
```

### Example 4: Documentation Enhancement

**Scenario**: Adding YARD documentation to all public methods

```ruby
# Add documentation to methods without it
methods_without_docs = SymbolicPatchFile.analyze_pattern(
  'app/models/user.rb',
  'def $METHOD',
  preview_mode: :matches
)

methods_without_docs[:matches].each do |match|
  method_name = match.dig(:metaVariables, :single, :METHOD, :text)
  
  result = SymbolicPatchFile.document_method(
    'app/models/user.rb',
    method_name,
    "@!method #{method_name}\n   @return [Object] description",
    doc_type: :yardoc
  )
end
```

---

## Common Patterns & Recipes

### Method Transformation Recipes

#### Recipe 1: Method Renaming with Validation

```ruby
def rename_method_with_validation(file_path, old_name, new_name)
  # First, analyze the method
  analysis = SymbolicPatchFile.analyze_pattern(
    file_path,
    "def #{old_name}",
    preview_mode: :transformations
  )
  
  # Check safety
  if analysis[:safety_score] > 0.7
    # Apply renaming
    SymbolicPatchFile.transform_method(
      file_path, old_name,
      new_method_name: new_name,
      transformation_type: :rename
    )
  else
    puts "⚠️  Safety score too low: #{analysis[:safety_score]}"
  end
end
```

#### Recipe 2: Method Body Optimization

```ruby
def optimize_method_body(file_path, method_name, optimization_pattern)
  # Replace method body with optimized version
  SymbolicPatchFile.transform_method(
    file_path, method_name,
    new_body: optimization_pattern,
    transformation_type: :body_replacement
  )
end
```

### Class Transformation Recipes

#### Recipe 1: Class Extraction (Extract Class Refactoring)

```ruby
def extract_class(source_file, source_class, new_class_name, methods_to_move)
  # Analyze source class
  analysis = SymbolicPatchFile.analyze_pattern(
    source_file,
    "class #{source_class}",
    preview_mode: :context
  )
  
  # Create new class file
  new_class_content = <<~RUBY
    class #{new_class_name}
      #{methods_to_move.map { |m| "def #{m}; end" }.join("\n  ")}
    end
  RUBY
  
  File.write("app/models/#{new_class_name.underscore}.rb", new_class_content)
  
  # Remove methods from source class
  methods_to_move.each do |method_name|
    SymbolicPatchFile.apply(
      source_file,
      "def #{method_name}\n  $$$BODY\nend",
      "# Method moved to #{new_class_name}"
    )
  end
end
```

#### Recipe 2: Module Inclusion

```ruby
def include_module_in_class(file_path, class_name, module_name)
  SymbolicPatchFile.apply(
    file_path,
    "class #{class_name}",
    "class #{class_name}\n  include #{module_name}"
  )
end
```

### Batch Operation Recipes

#### Recipe 1: Safe Batch Refactoring

```ruby
def safe_batch_refactor(patches)
  # First, analyze all patches for safety
  safety_analysis = patches.map do |patch|
    analysis = SymbolicPatchFile.analyze(patch[:diff], patch[:path])
    patch.merge(safety_score: analysis[:transformation_safety][:score])
  end
  
  # Filter safe patches
  safe_patches = safety_analysis.select { |p| p[:safety_score] > 0.8 }
  
  # Apply safe patches with optimization
  SymbolicPatchFile.apply_batch(safe_patches, dependency_analysis: true)
end
```

#### Recipe 2: Project-Wide Pattern Application

```ruby
def apply_project_wide_pattern(pattern, replacement, file_patterns = ['**/*.rb'])
  result = SymbolicPatchFile.cross_file_transform(
    file_patterns,
    pattern,
    replace_pattern: replacement,
    rule_level: :yaml
  )
  
  puts "Applied to #{result[:match_count]} files"
  puts "Success rate: #{(result[:success_count].to_f / result[:total_files] * 100).round}%"
  
  result
end
```

---

## Troubleshooting Guide

### Common Issues and Solutions

#### Issue 1: "AST-GREP not found"

**Symptoms**:
- `status[:available]` returns false
- `status[:ast_grep_installed]` returns false

**Solutions**:
1. Install AST-GREP: `cargo install ast-grep`
2. Add to PATH: Ensure `ast-grep` is in your system PATH
3. Verify installation: Run `ast-grep --version` in terminal

#### Issue 2: "Pattern not matching"

**Symptoms**:
- Transformation returns success but no changes made
- `result[:match_count]` is 0

**Solutions**:
1. Check pattern syntax: Use `analyze_pattern` to preview matches
2. Verify language: Ensure correct language is specified
3. Test pattern: Use simple test cases first

```ruby
# Debug pattern matching
analysis = SymbolicPatchFile.analyze_pattern(
  'file.rb', 'def $METHOD', preview_mode: :matches
)
puts "Found #{analysis[:match_count]} matches"
```

#### Issue 3: "Transformation applied incorrectly"

**Symptoms**:
- Code breaks after transformation
- Unexpected changes in unrelated code

**Solutions**:
1. Use safety analysis: Always check `analyze_pattern` with `preview_mode: :transformations`
2. Start with dry runs: Use `apply_changes: false` for testing
3. Use constraints: Add precise constraints to limit matching

```ruby
# Safe transformation with preview
analysis = SymbolicPatchFile.analyze_pattern(
  'file.rb', 'def $METHOD', preview_mode: :transformations
)

if analysis[:safety_score] > 0.7
  SymbolicPatchFile.apply('file.rb', 'def $METHOD', 'def new_$METHOD')
else
  puts "Transformation too risky"
end
```

#### Issue 4: "YAML rule parsing error"

**Symptoms**:
- YAML rule execution fails
- Validation errors reported

**Solutions**:
1. Validate YAML structure: Use online YAML validator
2. Check indentation: YAML is sensitive to indentation
3. Test with simple rule: Start with basic pattern and add complexity gradually

```ruby
# Validate YAML rule
begin
  HermeticSymbolicAnalysis::YamlRuleParser.validate_rule_structure(rule_data)
  puts "YAML rule is valid"
rescue ArgumentError => e
  puts "YAML validation error: #{e.message}"
end
```

### Debugging Techniques

#### Technique 1: Pattern Analysis

```ruby
# Comprehensive pattern analysis
analysis = SymbolicPatchFile.analyze_pattern(
  'file.rb',
  'def $METHOD',
  preview_mode: :transformations,
  analysis_depth: :comprehensive
)

puts "Safety score: #{analysis[:safety_score]}"
puts "Impact level: #{analysis[:impact_level]}"
puts "Pattern complexity: #{analysis[:pattern_complexity]}"
```

#### Technique 2: Step-by-Step Transformation

```ruby
# Transform in steps with verification
def safe_transformation(file_path, pattern, replacement)
  # Step 1: Analyze
  analysis = SymbolicPatchFile.analyze_pattern(file_path, pattern)
  
  # Step 2: Preview
  puts "Will affect #{analysis[:match_count]} matches"
  
  # Step 3: Dry run
  dry_run = SymbolicPatchFile.apply(file_path, pattern, replacement)
  
  # Step 4: Apply if safe
  if dry_run[:success] && analysis[:safety_score] > 0.8
    SymbolicPatchFile.apply(file_path, pattern, replacement)
  end
end
```

#### Technique 3: Batch Operation Debugging

```ruby
# Debug batch operations with detailed logging
def debug_batch_operations(patches)
  patches.each_with_index do |patch, index|
    puts "Processing patch #{index + 1}/#{patches.size}"
    
    # Analyze each patch individually
    analysis = SymbolicPatchFile.analyze(patch[:diff], patch[:path])
    
    if analysis[:transformation_safety][:score] > 0.7
      result = SymbolicPatchFile.apply(patch[:path], patch[:search], patch[:replace])
      puts "  ✅ #{result[:success] ? 'Success' : 'Failed'}"
    else
      puts "  ⚠️  Skipped (safety score: #{analysis[:transformation_safety][:score]})"
    end
  end
end
```

---

## Best Practices

### 1. Start Simple, Progress Gradually

**Beginner Level**:
- Use simple text replacement
- Test patterns with `analyze_pattern` first
- Apply to small files before large codebases

**Intermediate Level**:
- Experiment with DSL rules
- Add constraints for precision
- Use relational patterns for context

**Advanced Level**:
- Create YAML rule libraries
- Implement project-wide transformations
- Use utility composition for complex patterns

### 2. Safety First

**Always**:
- Preview transformations before applying
- Check safety scores
- Use version control for rollback capability

**Recommended**:
- Start with dry runs (`apply_changes: false`)
- Apply to copies of files first
- Use incremental application for large changes

### 3. Pattern Design Principles

**Effective Patterns**:
- Be specific but not overly restrictive
- Use constraints for precision
- Test patterns on representative code samples

**Pattern Anti-patterns**:
- Overly broad patterns that match unintended code
- Patterns without constraints in large codebases
- Complex patterns without adequate testing

### 4. Project Organization

**File Structure**:
```
project/
├── ast_rules/           # YAML rule files
│   ├── security.yaml
│   ├── performance.yaml
│   └── refactoring.yaml
├── utils/               # Utility patterns
│   └── common.yml
└── scripts/            # Transformation scripts
    ├── modernize.rb
    └── optimize.rb
```

**Rule Management**:
- Organize rules by purpose (security, performance, etc.)
- Document each rule with examples
- Version control rule files alongside code

### 5. Performance Considerations

**Large Codebases**:
- Use project configuration files
- Apply transformations in batches
- Monitor memory usage for very large projects

**Optimization Tips**:
- Cache frequently used patterns
- Use project-specific utility rules
- Profile transformation performance

### 6. Team Collaboration

**Documentation**:
- Document all custom rules and patterns
- Share successful transformation recipes
- Maintain transformation logs

**Communication**:
- Coordinate large-scale transformations
- Review pattern designs as a team
- Establish transformation guidelines

---

## Conclusion

This practical usage guide provides a comprehensive path from beginner to master level usage of the Hermetic Symbolic Oracle system. The key to success is progressive learning:

1. **Start** with simple text replacements
2. **Progress** to pattern-based transformations
3. **Master** YAML rule composition and utility reuse
4. **Excel** with project-wide intelligent transformations

Remember the hermetic principle: "As above, so below." The patterns you create should mirror the structure and intent of your codebase. With practice, you'll develop an intuitive understanding of how to apply hermetic principles to code transformation, creating more harmonious and maintainable software.

### Next Steps

1. **Practice** with the examples in this guide
2. **Experiment** with your own codebase
3. **Contribute** patterns and recipes to the community
4. **Explore** advanced hermetic analysis features

Happy transforming! 🌌
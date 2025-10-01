# AST-GREP Integration API Reference

## Complete Technical Documentation

> *"As above, so below" - Comprehensive API reference for the Hermetic Symbolic Oracle system*

---

## Table of Contents

1. [Core Modules Overview](#core-modules-overview)
2. [Hermetic Symbolic Oracle API](#hermetic-symbolic-oracle-api)
3. [Hermetic Symbolic Analysis API](#hermetic-symbolic-analysis-api)
4. [Symbolic Patch File API](#symbolic-patch-file-api)
5. [Symbolic Forecast API](#symbolic-forecast-api)
6. [YAML Rule Parser API](#yaml-rule-parser-api)
7. [Rule Builder DSL API](#rule-builder-dsl-api)
8. [Error Handling & Status Codes](#error-handling--status-codes)
9. [Configuration & Constants](#configuration--constants)

---

## Core Modules Overview

### Module Dependencies

```ruby
# Primary module dependencies
require 'instrumentarium/hermetic_symbolic_oracle'      # Main oracular engine
require 'instrumentarium/hermetic_symbolic_analysis'    # AST-GREP integration
require 'instrumentarium/symbolic_patch_file'           # Enhanced patching
require 'instrumentarium/symbolic_forecast'             # Predictive analysis
require 'instrumentarium/hermetic_execution_domain'     # Error handling
require 'argonaut/argonaut'                             # Path resolution
```

### Module Relationships

```
HermeticSymbolicOracle (Main Interface)
    ├── PatternResonance Engine
    ├── VibrationEngine
    └── TransformationOracle
        └── HermeticSymbolicAnalysis
            ├── YamlRuleParser
            └── RuleBuilderDSL
                └── SymbolicPatchFile
                    └── SymbolicForecast
```

---

## Hermetic Symbolic Oracle API

### Primary Interface Methods

#### `oracular_analysis(file_path, lang: nil)`

**Purpose**: Comprehensive hermetic analysis of code file

**Parameters**:
- `file_path` (String): Path to the file to analyze
- `lang` (String, optional): Language hint (auto-detected if nil)

**Returns**: Hash with comprehensive analysis results

```ruby
analysis = HermeticSymbolicOracle.oracular_analysis('app/models/user.rb')

# Returns:
{
  vibrational_signature: {
    elemental: { fire: {...}, water: {...}, earth: {...}, air: {...} },
    planetary: { solar: {...}, lunar: {...}, mercurial: {...} },
    alchemical: { nigredo: {...}, albedo: {...}, citrinitas: {...}, rubedo: {...} },
    overall: { intensity: Integer, dominant_element: Symbol, balance: Float }
  },
  transformation_forecast: [
    { type: Symbol, description: String, confidence: Float, priority: Integer }
  ],
  hermetic_resonance: {
    correspondence_strength: Float,
    polarity_balance: Float,
    rhythmic_patterns: Hash,
    gender_harmony: Hash
  }
}
```

#### `oracular_transform(file_path, transformation_spec)`

**Purpose**: Apply transformation with hermetic resonance

**Parameters**:
- `file_path` (String): Path to the file to transform
- `transformation_spec` (Hash): Transformation specification

**Transformation Specification**:
```ruby
transformation_spec = {
  type: Symbol,           # :method_rename, :class_rename, :document_method
  target: String,         # Original name/pattern
  new_value: String,      # New name/value
  resonance: Symbol,      # Hermetic resonance principle
  operation_mode: Symbol, # AST-GREP operation mode
  constraints: Hash,      # Meta variable constraints
  strictness: Symbol,     # Pattern strictness
  rule_level: Symbol      # :simple, :dsl, :yaml, :auto
}
```

**Returns**: Hash with transformation results

```ruby
result = HermeticSymbolicOracle.oracular_transform(
  'file.rb',
  { type: :method_rename, target: 'old', new_value: 'new', resonance: :fire }
)

# Returns:
{
  success: Boolean,
  result: Array,                    # AST-GREP match results
  resonance_applied: Symbol,        # Applied resonance principle
  vibrational_signature: Hash,      # Post-transformation vibrations
  pattern_type: Symbol              # :simple_text or :ast
}
```

#### `batch_transform_with_harmony(transformations, harmony_strategy: :balanced)`

**Purpose**: Apply batch transformations with harmonic analysis

**Parameters**:
- `transformations` (Array): Array of transformation specifications
- `harmony_strategy` (Symbol): Harmony strategy (:balanced, :masculine, :feminine)

**Returns**: Hash with batch results and harmonic analysis

```ruby
results = HermeticSymbolicOracle.batch_transform_with_harmony(
  transformations,
  harmony_strategy: :balanced
)

# Returns:
{
  harmonic_convergence: Float,      # Success ratio (0.0-1.0)
  vibrational_balance: Hash,        # Elemental balance analysis
  results: Array,                   # Individual transformation results
  harmony_strategy: Symbol          # Applied strategy
}
```

### Pattern Resonance Methods

#### `patterns_for_principle(principle, resonance_map = ELEMENTAL_RESONANCE)`

**Purpose**: Get code patterns for a hermetic principle

**Parameters**:
- `principle` (Symbol): Hermetic principle (:fire, :water, :earth, :air, etc.)
- `resonance_map` (Hash): Resonance mapping to use

**Returns**: Array of pattern strings

```ruby
patterns = HermeticSymbolicOracle.patterns_for_principle(:fire)
# => ['def $METHOD', 'class $CLASS', 'module $MODULE']
```

#### `principle_for_pattern(pattern, resonance_map = ELEMENTAL_RESONANCE)`

**Purpose**: Get hermetic principle for a code pattern

**Parameters**:
- `pattern` (String): Code pattern to analyze
- `resonance_map` (Hash): Resonance mapping to use

**Returns**: Hash with principle information or nil

```ruby
principle = HermeticSymbolicOracle.principle_for_pattern('def calculate_sum')
# => {
#   principle: :fire,
#   vibration: :transformative,
#   polarity: :active,
#   rhythm: :accelerando,
#   gender: :masculine
# }
```

### Vibration Analysis Methods

#### `analyze_vibrations(file_path, lang: nil)`

**Purpose**: Analyze vibrational signature of code

**Parameters**:
- `file_path` (String): Path to the file
- `lang` (String, optional): Language hint

**Returns**: Hash with vibrational analysis

```ruby
vibrations = HermeticSymbolicOracle.analyze_vibrations('file.rb')
# Returns elemental, planetary, and alchemical vibrations
```

#### `forecast_vibrational_transformations(file_path, lang: nil)`

**Purpose**: Forecast how transformations will affect vibrations

**Parameters**:
- `file_path` (String): Path to the file
- `lang` (String, optional): Language hint

**Returns**: Array of transformation forecasts with vibrational impact

```ruby
forecasts = HermeticSymbolicOracle.forecast_vibrational_transformations('file.rb')
# Returns array of operations with vibration and resonance analysis
```

---

## Hermetic Symbolic Analysis API

### Core AST-GREP Methods

#### `ast_grep_execute(command_args, pattern: nil, rewrite: nil, lang: nil)`

**Purpose**: Execute AST-GREP command with hermetic execution domain

**Parameters**:
- `command_args` (Array): AST-GREP command arguments
- `pattern` (String, optional): Search pattern
- `rewrite` (String, optional): Replacement pattern
- `lang` (String, optional): Language hint

**Returns**: Hash with execution results

```ruby
result = HermeticSymbolicAnalysis.ast_grep_execute(
  ['file.rb'],
  pattern: 'def $METHOD',
  rewrite: 'def new_$METHOD',
  lang: 'ruby'
)

# Returns:
{
  success: Boolean,
  result: Array,          # Match results
  pattern_type: Symbol,   # :simple_text or :ast
  error: String,          # Error message if failed
  status: Integer         # Exit status
}
```

#### `find_patterns(file_path, pattern, lang: nil)`

**Purpose**: Find patterns in code using AST-GREP

**Parameters**:
- `file_path` (String): Path to the file
- `pattern` (String): AST-GREP pattern to search for
- `lang` (String, optional): Language hint

**Returns**: Hash with pattern matching results

```ruby
result = HermeticSymbolicAnalysis.find_patterns('file.rb', 'def $METHOD')
```

#### `semantic_rewrite(file_path, pattern, rewrite, lang: nil)`

**Purpose**: Apply semantic rewrite using AST-GREP

**Parameters**:
- `file_path` (String): Path to the file
- `pattern` (String): Search pattern
- `rewrite` (String): Replacement pattern
- `lang` (String, optional): Language hint

**Returns**: Hash with rewrite results

```ruby
result = HermeticSymbolicAnalysis.semantic_rewrite(
  'file.rb', 'def old', 'def new'
)
```

### Structural Analysis Methods

#### `find_methods(file_path, lang: nil)`

**Purpose**: Find all methods in a file

**Parameters**:
- `file_path` (String): Path to the file
- `lang` (String, optional): Language hint

**Returns**: Hash with method findings

```ruby
methods = HermeticSymbolicAnalysis.find_methods('file.rb')
```

#### `find_classes(file_path, lang: nil)`

**Purpose**: Find all classes in a file

**Parameters**:
- `file_path` (String): Path to the file
- `lang` (String, optional): Language hint

**Returns**: Hash with class findings

```ruby
classes = HermeticSymbolicAnalysis.find_classes('file.rb')
```

#### `find_modules(file_path, lang: nil)`

**Purpose**: Find all modules in a file

**Parameters**:
- `file_path` (String): Path to the file
- `lang` (String, optional): Language hint

**Returns**: Hash with module findings

```ruby
modules = HermeticSymbolicAnalysis.find_modules('file.rb')
```

### Hermetic Symbol Extraction

#### `extract_hermetic_symbols(file_path, lang: nil)`

**Purpose**: Extract hermetic symbols from code

**Parameters**:
- `file_path` (String): Path to the file
- `lang` (String, optional): Language hint

**Returns**: Hash with categorized symbols

```ruby
symbols = HermeticSymbolicAnalysis.extract_hermetic_symbols('file.rb')

# Returns:
{
  fire: Array,        # Transformative patterns (methods)
  water: Array,       # Flowing patterns (control structures)
  earth: Array,       # Structural patterns (classes/modules)
  air: Array,         # Abstract patterns (imports/requires)
  solar: Array,       # Core logic patterns
  lunar: Array,       # Reflective patterns
  mercurial: Array,   # Communication patterns
  nigredo: Array,     # Analysis patterns (TODOs)
  albedo: Array,      # Purification patterns (FIXMEs)
  citrinitas: Array,  # Illumination patterns (NOTEs)
  methods: Array,     # Precise method definitions
  classes: Array,     # Precise class definitions
  modules: Array      # Precise module definitions
}
```

### Language Detection

#### `detect_language(file_path)`

**Purpose**: Detect programming language from file extension

**Parameters**:
- `file_path` (String): Path to the file

**Returns**: String language identifier or nil

```ruby
lang = HermeticSymbolicAnalysis.detect_language('app/models/user.rb')
# => 'ruby'
```

**Supported Languages**:
- `ruby` (.rb)
- `javascript` (.js, .jsx, .ts, .tsx)
- `python` (.py)
- `java` (.java)
- `go` (.go)
- `rust` (.rs)
- `php` (.php)
- `html` (.html, .htm)
- `css` (.css)
- `xml` (.xml)
- `json` (.json)
- `yaml` (.yml, .yaml)

---

## Symbolic Patch File API

### Primary Patching Methods

#### `apply(file_path, search_pattern, replace_pattern, **options)`

**Purpose**: Apply symbolic patch with enhanced features

**Parameters**:
- `file_path` (String): Path to the file
- `search_pattern` (String): Search pattern
- `replace_pattern` (String): Replacement pattern
- `options` (Hash): Additional options

**Options**:
- `lang` (String): Language hint
- `resonance` (Symbol): Hermetic resonance principle
- `operation_mode` (Symbol): AST-GREP operation mode
- `constraints` (Hash): Meta variable constraints
- `utils` (Hash): Utility rules
- `strictness` (Symbol): Pattern strictness
- `rule_level` (Symbol): Rule application level

**Returns**: Hash with enhanced patch results

```ruby
result = SymbolicPatchFile.apply(
  'file.rb',
  'def $METHOD',
  'def new_$METHOD',
  resonance: :fire,
  rule_level: :auto
)

# Returns:
{
  success: Boolean,
  result: Array,
  pattern_analysis: {
    search_pattern: String,
    replace_pattern: String,
    operation_mode: Symbol,
    meta_variables: Array,
    pattern_complexity: Integer
  },
  applied: Boolean
}
```

#### `apply_hybrid(file_path, patch_text, lang: nil, strategy_analysis: true)`

**Purpose**: Apply hybrid patch with intelligent strategy selection

**Parameters**:
- `file_path` (String): Path to the file
- `patch_text` (String): Traditional patch text
- `lang` (String, optional): Language hint
- `strategy_analysis` (Boolean): Whether to perform strategy analysis

**Returns**: Hash with hybrid patch results

```ruby
result = SymbolicPatchFile.apply_hybrid('file.rb', patch_text)
```

### Transformation Methods

#### `transform_method(file_path, method_name, **options)`

**Purpose**: Transform method with AST-GREP precision

**Parameters**:
- `file_path` (String): Path to the file
- `method_name` (String): Method name to transform
- `options` (Hash): Transformation options

**Options**:
- `new_method_name` (String): New method name (for renaming)
- `new_body` (String): New method body
- `selector` (String): AST-GREP selector pattern
- `context` (Hash): Transformation context
- `transformation_type` (Symbol): Type of transformation

**Transformation Types**:
- `:rename` - Method renaming
- `:body_replacement` - Method body replacement
- `:signature_change` - Method signature change
- `:decorator_add` - Method decorator addition

**Returns**: Hash with transformation results

```ruby
result = SymbolicPatchFile.transform_method(
  'file.rb',
  'old_method',
  new_method_name: 'new_method',
  transformation_type: :rename
)
```

#### `transform_class(file_path, class_name, **options)`

**Purpose**: Transform class with AST-GREP structural patterns

**Parameters**:
- `file_path` (String): Path to the file
- `class_name` (String): Class name to transform
- `options` (Hash): Transformation options

**Options**:
- `new_class_name` (String): New class name
- `new_body` (String): New class body
- `selector` (String): AST-GREP selector pattern
- `context` (Hash): Transformation context
- `transformation_type` (Symbol): Type of transformation

**Transformation Types**:
- `:rename` - Class renaming
- `:body_replacement` - Class body replacement
- `:inheritance_change` - Class inheritance change
- `:module_inclusion` - Class module inclusion

**Returns**: Hash with transformation results

```ruby
result = SymbolicPatchFile.transform_class(
  'file.rb',
  'OldClass',
  new_class_name: 'NewClass',
  transformation_type: :rename
)
```

### Analysis Methods

#### `analyze(patch_text, file_path = nil, analysis_depth: :advanced)`

**Purpose**: Analyze patch with AST-GREP pattern intelligence

**Parameters**:
- `patch_text` (String): Patch text to analyze
- `file_path` (String, optional): File path for language detection
- `analysis_depth` (Symbol): Analysis depth (:basic, :advanced, :comprehensive)

**Returns**: Hash with comprehensive analysis results

```ruby
analysis = SymbolicPatchFile.analyze(patch_text, 'file.rb', analysis_depth: :comprehensive)

# Returns:
{
  ast_grep_patterns: Array,
  meta_variable_usage: Hash,
  pattern_complexity: Integer,
  transformation_safety: Hash,
  hermetic_vibrations: Hash,        # Only with :comprehensive depth
  structural_analysis: Hash,        # Only with :comprehensive depth
  pattern_compatibility: Hash       # Only with :comprehensive depth
}
```

#### `analyze_pattern(file_path, pattern, lang: nil, preview_mode: :matches)`

**Purpose**: Analyze pattern matches and transformations

**Parameters**:
- `file_path` (String): Path to the file
- `pattern` (String): AST-GREP pattern to analyze
- `lang` (String, optional): Language hint
- `preview_mode` (Symbol): Preview mode (:matches, :context, :transformations)

**Returns**: Hash with pattern analysis results

```ruby
analysis = SymbolicPatchFile.analyze_pattern(
  'file.rb',
  'def $METHOD',
  preview_mode: :transformations
)
```

### Batch Operations

#### `apply_batch(patches, parallel_processing: true, dependency_analysis: true)`

**Purpose**: Apply batch patches with optimization

**Parameters**:
- `patches` (Array): Array of patch specifications
- `parallel_processing` (Boolean): Whether to process in parallel
- `dependency_analysis` (Boolean): Whether to analyze dependencies

**Patch Specification**:
```ruby
patch = {
  path: String,           # File path
  search_pattern: String, # Search pattern
  replace_pattern: String # Replacement pattern
  # Additional options...
}
```

**Returns**: Hash with batch results and optimization data

```ruby
results = SymbolicPatchFile.apply_batch(patches)

# Returns:
{
  success: Boolean,
  results: Array,
  optimization: {
    original_count: Integer,
    optimized_order: Array,
    dependency_graph: Hash,
    parallel_processing: Boolean
  }
}
```

### Cross-File Operations

#### `cross_file_transform(file_patterns, search_pattern, **options)`

**Purpose**: Apply transformations across multiple files

**Parameters**:
- `file_patterns` (Array): Array of file patterns
- `search_pattern` (String): Search pattern
- `options` (Hash): Additional options

**Options**:
- `replace_pattern` (String): Replacement pattern
- `lang` (String): Language hint
- `rule_level` (Symbol): Rule application level
- `project_config` (Hash): Project configuration

**Returns**: Hash with cross-file transformation results

```ruby
result = SymbolicPatchFile.cross_file_transform(
  ['app/**/*.rb', 'lib/**/*.rb'],
  'def $OLD_METHOD',
  replace_pattern: 'def $NEW_METHOD',
  rule_level: :yaml
)
```

---

## Symbolic Forecast API

### Forecasting Methods

#### `forecast_file_transformations(file_path)`

**Purpose**: Forecast transformations for a file based on patterns

**Parameters**:
- `file_path` (String): Path to the file

**Returns**: Array of transformation forecasts

```ruby
forecasts = SymbolicForecast.forecast_file_transformations('file.rb')

# Returns:
[
  {
    type: Symbol,           # :method_refactor, :class_restructure, etc.
    element: Symbol,        # :fire, :water, :earth, :air
    description: String,    # Human-readable description
    confidence: Float,      # Confidence score (0.0-1.0)
    priority: Integer       # Priority level (1=high, 4=low)
  }
]
```

#### `forecast_project_transformations(directory = '.')`

**Purpose**: Forecast transformations for entire project

**Parameters**:
- `directory` (String): Project directory path

**Returns**: Array of transformation forecasts with file context

```ruby
forecasts = SymbolicForecast.forecast_project_transformations('.')

# Returns forecasts with additional file context:
[
  {
    type: Symbol,
    element: Symbol,
    description: String,
    confidence: Float,
    priority: Integer,
    file: String            # File path
  }
]
```

#### `generate_patch_suggestions(forecasts)`

**Purpose**: Generate patch suggestions from forecasts

**Parameters**:
- `forecasts` (Array): Array of transformation forecasts

**Returns**: Array of patch suggestions

```ruby
suggestions = SymbolicForecast.generate_patch_suggestions(forecasts)

# Returns:
[
  {
    file: String,           # File path
    description: String,    # Patch description
    suggested_patch: String,# Patch content
    confidence: Float,      # Confidence score
    priority: Integer       # Priority level
  }
]
```

---

## YAML Rule Parser API

### Core Methods

#### `parse_rule(rule_source)`

**Purpose**: Parse YAML rule file or string

**Parameters**:
- `rule_source` (String): YAML content or file path

**Returns**: Array of AST-GREP command arguments

```ruby
command = HermeticSymbolicAnalysis::YamlRuleParser.parse_rule('rule.yaml')
# => ['ast-grep', 'run', '--pattern', 'def $METHOD', ...]
```

#### `generate_rule(**options)`

**Purpose**: Generate YAML rule from components

**Parameters**:
- `pattern` (String): Search pattern
- `rewrite` (String, optional): Replacement pattern
- `language` (String, optional): Language hint
- `constraints` (Hash, optional): Meta variable constraints
- `utils` (Hash, optional): Utility rules
- `strictness` (String, optional): Pattern strictness

**Returns**: YAML string

```ruby
yaml_rule = HermeticSymbolicAnalysis::YamlRuleParser.generate_rule(
  pattern: 'def $METHOD',
  rewrite: 'def new_$METHOD',
  constraints: { METHOD: { regex: '^[a-z_]+$' } },
  strictness: 'smart'
)
```

### Validation Methods

#### `validate_rule_structure(rule_data)`

**Purpose**: Validate YAML rule structure

**Parameters**:
- `rule_data` (Hash): Parsed rule data

**Returns**: Boolean (true if valid)

**Raises**: ArgumentError for invalid structure

```ruby
HermeticSymbolicAnalysis::YamlRuleParser.validate_rule_structure(rule_data)
```

---

## Rule Builder DSL API

### DSL Methods

#### `build_rule(&block)`

**Purpose**: Build YAML rule using DSL

**Parameters**:
- `&block` (Block): DSL configuration block

**Returns**: YAML string

```ruby
rule_yaml = HermeticSymbolicAnalysis::RuleBuilderDSL.build_rule do
  pattern('def $METHOD')
  rewrite('def new_$METHOD')
  language('ruby')
  constraint('METHOD', regex: '^[a-z_]+$')
  utility('method_body', '$$$')
  strictness('smart')
end
```

### DSL Context Methods

Available within the `build_rule` block:

#### `pattern(pattern_text)`
**Purpose**: Set search pattern

#### `rewrite(replacement_text)`
**Purpose**: Set replacement pattern

#### `language(lang)`
**Purpose**: Set language hint

#### `constraint(variable, **options)`
**Purpose**: Add meta variable constraint

#### `utility(name, pattern)`
**Purpose**: Add utility rule

#### `inside(pattern)`
**Purpose**: Add inside constraint

#### `has(pattern)`
**Purpose**: Add has constraint

#### `strictness(level)`
**Purpose**: Set pattern strictness

---

## Error Handling & Status Codes

### Common Error Patterns

#### AST-GREP Execution Errors

```ruby
{
  success: false,
  error: "AST-GREP command failed",
  status: 1,                    # Exit status
  pattern_type: :ast           # or :simple_text
}
```

#### File Access Errors

```ruby
{
  success: false,
  error: "File does not exist: path/to/file.rb"
}
```

#### Pattern Validation Errors

```ruby
{
  success: false,
  error: "Invalid pattern syntax",
  pattern: "def $METHOD",
  suggestion: "Check meta variable usage"
}
```

#### YAML Rule Errors

```ruby
{
  success: false,
  error: "YAML rule validation failed",
  validation_errors: ["Missing 'rule' key", "Invalid pattern syntax"]
}
```

### Status Checking

#### `SymbolicPatchFile.status`

**Purpose**: Check system status and capabilities

**Returns**: Hash with status information

```ruby
status = SymbolicPatchFile.status

# Returns:
{
  available: Boolean,
  ast_grep_installed: Boolean,
  version: String,
  advanced_features: {
    json_output: Boolean,
    pattern_matching: Boolean,
    language_support: Boolean
  },
  operation_modes: Array,
  pattern_types: Array,
  hermetic_oracle_available: Boolean
}
```

---

## Configuration & Constants

### Operation Modes

```ruby
SymbolicPatchFile::OPERATION_MODES = {
  simple_replace: 'Direct text replacement',
  pattern_match: 'AST pattern matching',
  structural_rewrite: 'Structural tree rewriting',
  multi_file: 'Cross-file transformations',
  interactive: 'Interactive patch application',
  constraint_based: 'Constraint-driven transformations',
  utility_reuse: 'Rule utility composition',
  elemental: 'Elemental pattern transformations',
  planetary: 'Planetary semantic transformations',
  alchemical: 'Alchemical code purification'
}
```

### Pattern Types

```ruby
SymbolicPatchFile::PATTERN_TYPES = {
  meta_variable: '$VAR - matches any single AST node',
  multi_meta: '$$$ - matches zero or more AST nodes',
  kind_selector: 'kind: function - matches by node kind',
  relational: 'inside: { kind: class } - relational constraints',
  composite: 'all: [pattern1, pattern2] - composite patterns',
  regex_constraint: 'regex: \\w+ - regex constraints on meta variables'
}
```

### Hermetic Resonance Mappings

```ruby
HermeticSymbolicOracle::PatternResonance::ELEMENTAL_RESONANCE = {
  fire: { vibration: :transformative, patterns: ['def $METHOD', 'class $CLASS'] },
  water: { vibration: :flowing, patterns: ['if $COND', 'while $COND'] },
  earth: { vibration: :structural, patterns: ['class $CLASS', 'module $MODULE'] },
  air: { vibration: :abstract, patterns: ['require $LIB', 'import $MODULE'] }
}
```

---

## Conclusion

This comprehensive API reference provides complete documentation for the Hermetic Symbolic Oracle system. The API is designed with progressive enhancement in mind, allowing developers to start with simple patterns and gradually adopt more advanced features as needed.

### Key Design Principles

1. **Progressive Enhancement**: Three-tier interface from simple to advanced
2. **Hermetic Integration**: All methods respect hermetic principles
3. **Safety First**: Comprehensive error handling and validation
4. **Intelligent Defaults**: Auto-detection of optimal strategies
5. **Comprehensive Analysis**: Deep pattern and transformation analysis

### Getting Started

For beginners, start with:
- `SymbolicPatchFile.apply()` for basic patching
- `HermeticSymbolicAnalysis.find_patterns()` for pattern matching
- `SymbolicForecast.forecast_file_transformations()` for insights

For advanced users, explore:
- YAML rule composition and utility reuse
- Cross-file transformations with project configuration
- Hermetic resonance-based transformations
- Batch optimization with dependency analysis

This API represents the culmination of the AST-GREP integration magnum opus - a complete system that transforms code analysis from technical exercise to spiritual practice.
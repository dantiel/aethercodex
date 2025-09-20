# 🔮 Hermetic Symbolic Analysis API Reference

## 📋 Overview

This document provides detailed API reference for the Hermetic Symbolic Analysis Engine components, including method signatures, parameters, return values, and usage examples.

## 🏗️ Core Components

### HermeticSymbolicAnalysis Module

**Location**: `Support/instrumentarium/hermetic_symbolic_analysis.rb`

#### `ast_grep_execute(command_args, pattern: nil, rewrite: nil, lang: nil)`

Execute AST-GREP command with hermetic execution domain and structured error handling.

**Parameters:**
- `command_args` (Array): AST-GREP command arguments
- `pattern` (String, optional): AST pattern to match
- `rewrite` (String, optional): Replacement pattern
- `lang` (String, optional): Programming language (auto-detected if nil)

**Returns:** Hash with execution results
- `:success` (Boolean): Whether operation succeeded
- `:result` (Array/Hash): Parsed AST-GREP output
- `:error` (String): Error message if failed
- `:status` (Integer): Exit status code

**Example:**
```ruby
result = HermeticSymbolicAnalysis.ast_grep_execute(
  ['file.rb'], 
  pattern: 'def $METHOD', 
  lang: 'ruby'
)
```

#### `find_patterns(file_path, pattern, lang: nil)`

Find patterns in code using AST-GREP semantic search.

**Parameters:**
- `file_path` (String): Path to file to analyze
- `pattern` (String): AST pattern to search for
- `lang` (String, optional): Programming language

**Returns:** Hash with pattern matching results

**Example:**
```ruby
result = HermeticSymbolicAnalysis.find_patterns('app.rb', 'def $METHOD', lang: 'ruby')
```

#### `semantic_rewrite(file_path, pattern, rewrite, lang: nil)`

Apply semantic rewrite to file using AST-GREP pattern matching.

**Parameters:**
- `file_path` (String): Path to file to modify
- `pattern` (String): AST pattern to match
- `rewrite` (String): Replacement pattern
- `lang` (String, optional): Programming language

**Returns:** Hash with rewrite results

**Example:**
```ruby
result = HermeticSymbolicAnalysis.semantic_rewrite(
  'app.rb',
  'def $METHOD($$_) $$BODY end',
  'def $METHOD($$_) puts "TRANSFORMED"; $$BODY end',
  lang: 'ruby'
)
```

#### `extract_hermetic_symbols(file_path, lang: nil)`

Extract elemental, planetary, and alchemical symbols from code.

**Parameters:**
- `file_path` (String): Path to file to analyze
- `lang` (String, optional): Programming language

**Returns:** Hash with symbolic patterns
- `:fire`, `:water`, `:earth`, `:air` (Elemental patterns)
- `:solar`, `:lunar`, `:mercurial` (Planetary patterns)  
- `:nigredo`, `:albedo`, `:citrinitas` (Alchemical patterns)

**Example:**
```ruby
symbols = HermeticSymbolicAnalysis.extract_hermetic_symbols('app.rb')
```

#### `forecast_operations(file_path, lang: nil)`

Forecast symbolic operations based on patterns found in code.

**Parameters:**
- `file_path` (String): Path to file to analyze
- `lang` (String, optional): Programming language

**Returns:** Array of operation forecasts with confidence scores

**Example:**
```ruby
forecasts = HermeticSymbolicAnalysis.forecast_operations('app.rb')
```

#### `detect_language(file_path)`

Detect programming language based on file extension.

**Parameters:**
- `file_path` (String): Path to file

**Returns:** String language identifier

**Example:**
```ruby
lang = HermeticSymbolicAnalysis.detect_language('app.rb') # => 'ruby'
```

#### `generate_pattern_from_code(code_snippet, lang: nil)`

Generate AST pattern from code snippet.

**Parameters:**
- `code_snippet` (String): Code example to convert to pattern
- `lang` (String, optional): Programming language

**Returns:** String AST pattern

**Example:**
```ruby
pattern = HermeticSymbolicAnalysis.generate_pattern_from_code('def example; end')
# => 'def $METHOD; end'
```

#### `convert_to_semantic_patch(patch_text, lang: nil)`

Convert line-based patch to semantic pattern.

**Parameters:**
- `patch_text` (String): Line-based patch text
- `lang` (String, optional): Programming language

**Returns:** Hash with semantic patch or nil if conversion fails
- `:search` (String): Search pattern
- `:replace` (String): Replacement pattern

**Example:**
```ruby
semantic_patch = HermeticSymbolicAnalysis.convert_to_semantic_patch(<<~PATCH)
<<<<<<< SEARCH
:start_line:42
-------
def old_method
  puts "obsolete"
end
=======
def new_method
  puts "refactored"
end
>>>>>>> REPLACE
PATCH
```

### SemanticPatch Module

**Location**: `Support/instrumentarium/semantic_patch.rb`

#### `apply_semantic_patch(file_path, search_pattern, replace_pattern, lang: nil)`

Apply semantic patch using AST-GREP pattern matching.

**Parameters:**
- `file_path` (String): Path to file to modify
- `search_pattern` (String): AST pattern to match
- `replace_pattern` (String): Replacement pattern
- `lang` (String, optional): Programming language

**Returns:** Hash with patch application results

**Example:**
```ruby
result = SemanticPatch.apply_semantic_patch(
  'app.rb',
  'def $METHOD($$_) $$BODY end',
  'def $METHOD($$_) puts "TRANSFORMED"; $$BODY end',
  lang: 'ruby'
)
```

#### `apply_hybrid_patch(file_path, patch_text, lang: nil)`

Hybrid patch application - tries semantic first, falls back to line-based.

**Parameters:**
- `file_path` (String): Path to file to modify
- `patch_text` (String): Patch text in unified diff format
- `lang` (String, optional): Programming language

**Returns:** Hash with patch results including strategy used

**Example:**
```ruby
result = SemanticPatch.apply_hybrid_patch('app.rb', <<~PATCH)
<<<<<<< SEARCH
:start_line:42
-------
def old_method
  puts "obsolete"
end
=======
def new_method
  puts "refactored"
end
>>>>>>> REPLACE
PATCH
```

#### `analyze_patch_strategy(patch_text, file_path = nil)`

Analyze patch to determine best approach (semantic vs line-based).

**Parameters:**
- `patch_text` (String): Patch text in unified diff format
- `file_path` (String, optional): Path to file for language detection

**Returns:** Hash with strategy analysis
- `:can_be_semantic` (Boolean): Whether patch can be semantic
- `:semantic_pattern` (Hash): Converted semantic pattern if possible
- `:recommended_approach` (Symbol): `:semantic` or `:line_based`
- `:confidence` (Float): Confidence score (0.0-1.0)
- `:line_count` (Integer): Number of lines in patch
- `:has_complex_indentation` (Boolean): Whether patch has complex indentation

**Example:**
```ruby
analysis = SemanticPatch.analyze_patch_strategy(patch_text, 'app.rb')
```

#### `apply_patches(patches)`

Batch apply patches with intelligent routing.

**Parameters:**
- `patches` (Array): Array of patch hashes
  - `:path` (String): File path
  - `:diff` (String): Patch text

**Returns:** Array of patch results with strategy information

**Example:**
```ruby
results = SemanticPatch.apply_patches([
  { path: 'app.rb', diff: patch_text1 },
  { path: 'lib.rb', diff: patch_text2 }
])
```

#### `learn_from_examples(file_path, examples)`

Create semantic patch pattern from examples (machine learning stub).

**Parameters:**
- `file_path` (String): Target file path
- `examples` (Array): Array of example transformations

**Returns:** Hash with learned pattern

**Example:**
```ruby
pattern = SemanticPatch.learn_from_examples('app.rb', [
  { before: 'def old1; end', after: 'def new1; puts "new" end' },
  { before: 'def old2; end', after: 'def new2; puts "new" end' }
])
```

### SymbolicForecast Module

**Location**: `Support/instrumentarium/symbolic_forecast.rb`

#### `forecast_file_transformations(file_path)`

Forecast transformations for a single file based on hermetic symbols.

**Parameters:**
- `file_path` (String): Path to file to analyze

**Returns:** Array of transformation forecasts
- `:type` (Symbol): Transformation type
- `:element`/:planet/:stage (Symbol): Hermetic category
- `:description` (String): Description of transformation
- `:confidence` (Float): Confidence score (0.0-1.0)
- `:priority` (Integer): Priority level (1=highest)

**Example:**
```ruby
forecasts = SymbolicForecast.forecast_file_transformations('app.rb')
```

#### `forecast_project_transformations(directory = '.')`

Forecast transformations for all source files in directory.

**Parameters:**
- `directory` (String): Directory path to analyze

**Returns:** Array of transformation forecasts with file information

**Example:**
```ruby
forecasts = SymbolicForecast.forecast_project_transformations('src/')
```

#### `generate_patch_suggestions(forecasts)`

Generate patch suggestions from transformation forecasts.

**Parameters:**
- `forecasts` (Array): Array of transformation forecasts

**Returns:** Array of patch suggestions
- `:file` (String): Target file path
- `:description` (String): Transformation description
- `:suggested_patch` (String): Patch template
- `:confidence` (Float): Confidence score
- `:priority` (Integer): Priority level

**Example:**
```ruby
suggestions = SymbolicForecast.generate_patch_suggestions(forecasts)
```

## 🔧 Configuration Constants

### Hermetic Symbolic Patterns

**Elemental Patterns** (`HermeticSymbolicAnalysis::ELEMENTAL_PATTERNS`):
- `:fire`: `{ description: "Transformative operations", pattern: "def $METHOD($$_) $$BODY end" }`
- `:water`: `{ description: "Flow operations", pattern: "if $COND $$THEN else $$ELSE end" }`
- `:earth`: `{ description: "Structural operations", pattern: "class $CLASS $$BODY end" }`
- `:air`: `{ description: "Abstract operations", pattern: "require $LIBRARY" }`

**Planetary Patterns** (`HermeticSymbolicAnalysis::PLANETARY_PATTERNS`):
- `:solar`: `{ description: "Core logic", pattern: "def $METHOD($$_) $$BODY end" }`
- `:lunar`: `{ description: "Reflective operations", pattern: "define_method $SYMBOL $$BODY end" }`
- `:mercurial`: `{ description: "Communication patterns", pattern: "$METHOD($$ARGS)" }`

**Alchemical Patterns** (`HermeticSymbolicAnalysis::ALCHEMICAL_PATTERNS`):
- `:nigredo`: `{ description: "Analysis patterns", pattern: "# TODO: $NOTE" }`
- `:albedo`: `{ description: "Purification patterns", pattern: "# FIXME: $NOTE" }`
- `:citrinitas`: `{ description: "Illumination patterns", pattern: "# NOTE: $NOTE" }`

## 🚨 Error Handling

All methods return structured error responses:

```ruby
{
  error: "Error message describing the failure",
  status: 1, # Exit status code
  details: { /* Additional error context */ }
}
```

Common error types:
- `:ast_grep_not_found` - AST-GREP executable not available
- `:pattern_syntax_error` - Invalid AST pattern syntax
- `:file_not_found` - Target file does not exist
- `:permission_denied` - File access permission issues
- `:rewrite_failed` - Semantic rewrite operation failed

## 📊 Return Value Examples

### Successful Pattern Matching
```ruby
{
  success: true,
  result: [
    { match: "def calculate_total", range: { start: 42, end: 45 } },
    { match: "def process_data", range: { start: 87, end: 90 } }
  ]
}
```

### Successful Semantic Rewrite
```ruby
{
  success: true,
  result: {
    modified: true,
    changes: 2,
    file: "app.rb"
  }
}
```

### Error Response
```ruby
{
  error: "AST-GREP command failed: No such file or directory",
  status: 127,
  details: {
    command: "ast-grep run --pattern 'def $METHOD' missing_file.rb",
    stderr: "ast-grep: error: missing_file.rb: No such file or directory"
  }
}
```

---

*This API reference is part of the AetherCodex Hermetic Symbolic Analysis Engine documentation.*
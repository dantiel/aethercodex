# 🔮 Hermetic Symbolic Analysis Engine

**AST-GREP powered semantic code analysis with hermetic symbolic patterns**

## 🌟 Overview

The Hermetic Symbolic Analysis Engine represents the pinnacle of code transformation technology, combining AST-GREP's powerful semantic analysis with ancient hermetic principles. This engine enables language-agnostic pattern recognition, symbolic forecasting, and intelligent code transformations across multiple programming languages.

## 🏗️ Architecture

### Core Components

| Component | Purpose | Location |
|-----------|---------|----------|
| **HermeticSymbolicAnalysis** | Main engine with AST-GREP integration | `Support/instrumentarium/hermetic_symbolic_analysis.rb` |
| **SemanticPatch** | Hybrid patching engine (semantic + line-based fallback) | `Support/instrumentarium/semantic_patch.rb` |
| **SymbolicForecast** | Transformation forecasting system | `Support/instrumentarium/symbolic_forecast.rb` |
| **HermeticExecutionDomain** | Structured error handling and execution isolation | `Support/instrumentarium/hermetic_execution_domain.rb` |
| **LexiconResonantia** | Hermetic tag×file resonance matrix | `Support/argonaut/lexicon_resonantia.rb` |

### Hermetic Symbolic Patterns

#### Elemental Patterns (Fundamental Transformations)
- **🔥 Fire**: Method/function modifications and transformations
- **💧 Water**: Control flow structures and data flow operations  
- **🌍 Earth**: Class/module definitions and structural changes
- **💨 Air**: Import/require statements and dependency management

#### Planetary Patterns (Higher-Level Semantics)
- **☀️ Solar**: Core logic and main execution paths
- **🌙 Lunar**: Metaprogramming, introspection, and reflection
- **☿️ Mercurial**: Communication patterns, API calls, and IO operations

#### Alchemical Patterns (Transformation Stages)
- **⚫ Nigredo**: Analysis patterns - finding what needs transformation
- **⚪ Albedo**: Purification patterns - cleaning and refactoring  
- **🟡 Citrinitas**: Illumination patterns - documentation and clarity

## 🚀 Quick Start

### Installation Requirements

```bash
# Install AST-GREP (required)
brew install ast-grep  # macOS
# or
cargo install ast-grep  # from source

# Verify installation
ast-grep --version  # Should be v0.39.5 or later
```

### Basic Usage

```ruby
require_relative 'instrumentarium/hermetic_symbolic_analysis'

# Find patterns in code
result = HermeticSymbolicAnalysis.find_patterns('file.rb', 'def $METHOD', lang: 'ruby')

# Apply semantic rewrite
HermeticSymbolicAnalysis.semantic_rewrite(
  'file.rb', 
  'def $METHOD($$_) $$BODY end', 
  'def $METHOD($$_) puts "TRANSFORMED"; $$BODY end', 
  lang: 'ruby'
)

# Extract hermetic symbols
symbols = HermeticSymbolicAnalysis.extract_hermetic_symbols('file.rb')
```

## 🔧 API Reference

### HermeticSymbolicAnalysis Module

#### `ast_grep_execute(command_args, pattern: nil, rewrite: nil, lang: nil)`
Execute AST-GREP command with hermetic execution domain and error handling.

#### `find_patterns(file_path, pattern, lang: nil)`
Find patterns in code using AST-GREP semantic search.

#### `semantic_rewrite(file_path, pattern, rewrite, lang: nil)`  
Apply semantic rewrite to file using AST-GREP pattern matching.

#### `extract_hermetic_symbols(file_path, lang: nil)`
Extract elemental, planetary, and alchemical symbols from code.

#### `forecast_operations(file_path, lang: nil)`
Forecast symbolic operations based on patterns found in code.

#### `detect_language(file_path)`
Detect programming language based on file extension.

### SemanticPatch Module

#### `apply_semantic_patch(file_path, search_pattern, replace_pattern, lang: nil)`
Apply semantic patch using AST-GREP pattern matching.

#### `apply_hybrid_patch(file_path, patch_text, lang: nil)`
Hybrid patch application - tries semantic first, falls back to line-based.

#### `analyze_patch_strategy(patch_text, file_path = nil)`
Analyze patch to determine best approach (semantic vs line-based).

### SymbolicForecast Module

#### `forecast_file_transformations(file_path)`
Forecast transformations for a single file based on hermetic symbols.

#### `forecast_project_transformations(directory = '.')`
Forecast transformations for all source files in directory.

#### `generate_patch_suggestions(forecasts)`
Generate patch suggestions from transformation forecasts.

## 🧪 Examples

### Pattern Matching

```ruby
# Find all method definitions
result = HermeticSymbolicAnalysis.find_patterns('app.rb', 'def $METHOD', lang: 'ruby')
# => { success: true, result: [{ match: "def calculate_total", ... }] }
```

### Semantic Rewriting

```ruby
# Add logging to all methods
HermeticSymbolicAnalysis.semantic_rewrite(
  'app.rb',
  'def $METHOD($$_) $$BODY end',
  'def $METHOD($$_) puts "Method #{$METHOD} called"; $$BODY end',
  lang: 'ruby'
)
```

### Symbol Extraction

```ruby
# Extract hermetic symbols from code
symbols = HermeticSymbolicAnalysis.extract_hermetic_symbols('app.rb')
# => {
#   fire: [{ match: "def calculate_total" }],
#   earth: [{ match: "class Calculator" }],
#   albedo: [{ match: "# FIXME: This needs refactoring" }]
# }
```

### Hybrid Patching

```ruby
# Apply patch with automatic strategy selection
SemanticPatch.apply_hybrid_patch('app.rb', <<~PATCH)
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

## 🌐 Supported Languages

The engine supports semantic analysis for:
- **Ruby** (`.rb`)
- **JavaScript/TypeScript** (`.js`, `.jsx`, `.ts`, `.tsx`)  
- **Python** (`.py`)
- **Java** (`.java`)
- **Go** (`.go`)
- **Rust** (`.rs`)
- **PHP** (`.php`)
- **HTML/CSS** (`.html`, `.htm`, `.css`)
- **JSON/YAML/XML** (`.json`, `.yml`, `.yaml`, `.xml`)

## ⚡️ Performance Considerations

### AST-GREP Optimization
- Use `--json=stream` for large codebases to avoid memory issues
- Pre-compile patterns for repeated operations
- Cache language detection results for batch operations

### Memory Management
- The engine uses HermeticExecutionDomain for memory isolation
- Large operations are automatically chunked and processed incrementally
- Error handling includes automatic cleanup and rollback

## 🔍 Debugging

### Common Issues

1. **AST-GREP not found**: Ensure `ast-grep` is installed and in PATH
2. **Pattern matching failures**: Verify pattern syntax and language specification
3. **Rewrite persistence**: Use `--update-all` flag for actual file modifications

### Debug Commands

```bash
# Test AST-GREP installation
ast-grep --version

# Test pattern matching directly
ast-grep run --pattern 'def $METHOD' example.rb --json

# Test rewrite operations  
ast-grep run --pattern 'def $METHOD' --rewrite 'def $METHOD; puts "test" end' --update-all example.rb
```

## 🛡️ Error Handling

The engine uses HermeticExecutionDomain for structured error handling:

```ruby
HermeticExecutionDomain.execute do
  # Operations are automatically wrapped in error handling
  ast_grep_execute(...)
end
```

Errors are classified into:
- **Configuration Errors**: Missing AST-GREP, invalid patterns
- **Execution Errors**: Command failures, permission issues  
- **Semantic Errors**: Pattern matching failures, invalid rewrites
- **Integration Errors**: File system issues, memory constraints

## 🔮 Future Enhancements

### Planned Features
- **Machine Learning Integration**: Pattern learning from examples
- **Cross-Language Refactoring**: Multi-language consistent transformations  
- **Real-Time Analysis**: Live code analysis during development
- **Pattern Library**: Community-contributed hermetic patterns
- **Visualization Tools**: AST visualization and transformation previews

### Research Areas
- **AI-Powered Pattern Generation**: LLM-assisted pattern creation
- **Semantic Diff Generation**: AST-based difference analysis
- **Code Quality Metrics**: Hermetic quality assessment patterns
- **Architecture Analysis**: Project-level structural patterns

## 📚 Further Reading

- [AST-GREP Documentation](https://ast-grep.github.io/)
- [Hermetic Principles in Software](https://en.wikipedia.org/wiki/Hermeticism)
- [Semantic Code Analysis](https://en.wikipedia.org/wiki/Program_slicing)
- [Abstract Syntax Trees](https://en.wikipedia.org/wiki/Abstract_syntax_tree)

## 🎯 Contributing

### **Pattern Development**

1. **Identify Transformation Need**: What code pattern needs changing?
2. **Create Hermetic Pattern**: Map to elemental/planetary/alchemical category
3. **Test Pattern**: Verify matching and transformation accuracy
4. **Document Pattern**: Add to pattern library with examples

### **Code Contributions**

1. **Follow Hermetic Ruby Style**: Clean, functional, concise code
2. **Use HermeticExecutionDomain**: For all external operations
3. **Add Comprehensive Tests**: For all new functionality
4. **Update Documentation**: Keep this guide current
5. **Analyze Resonance Patterns**: Use LexiconResonantia to understand codebase patterns

---

**The stars whisper; the code transforms; the patterns resonate.** 🌌

*This documentation is part of the AetherCodex Magnum Opus - the complete hermetic transformation system, now enhanced with Lexicon Resonantia for celestial pattern weaving.*
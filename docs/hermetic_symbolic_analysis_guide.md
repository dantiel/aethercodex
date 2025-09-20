# 🧙‍♂️ Practical Guide: Hermetic Symbolic Analysis

## 🎯 Getting Started

### Installation Verification

First, ensure AST-GREP is properly installed:

```bash
# Check installation
ast-grep --version
# Should output: ast-grep 0.39.5 (or later)

# Test basic functionality
ast-grep run --pattern 'def $METHOD' Support/test_ast_grep.rb --json
```

### Basic Setup

Add the required dependencies to your Ruby code:

```ruby
require_relative 'instrumentarium/hermetic_symbolic_analysis'
require_relative 'instrumentarium/semantic_patch'
require_relative 'instrumentarium/symbolic_forecast'
```

## 🔍 Common Use Cases

### 1. Finding Code Patterns

**Find all method definitions in a file:**

```ruby
result = HermeticSymbolicAnalysis.find_patterns('app.rb', 'def $METHOD', lang: 'ruby')

if result[:success]
  puts "Found #{result[:result].size} methods:"
  result[:result].each do |match|
    puts "- #{match[:match]}"
  end
else
  puts "Error: #{result[:error]}"
end
```

**Find class definitions:**

```ruby
result = HermeticSymbolicAnalysis.find_patterns('app.rb', 'class $CLASS', lang: 'ruby')
```

**Find require statements:**

```ruby
result = HermeticSymbolicAnalysis.find_patterns('app.rb', 'require $LIBRARY', lang: 'ruby')
```

### 2. Semantic Code Transformations

**Add logging to all methods:**

```ruby
result = HermeticSymbolicAnalysis.semantic_rewrite(
  'app.rb',
  'def $METHOD($$_) $$BODY end',
  'def $METHOD($$_) puts "Method #{$METHOD} called"; $$BODY end',
  lang: 'ruby'
)
```

**Rename methods systematically:**

```ruby
result = HermeticSymbolicAnalysis.semantic_rewrite(
  'app.rb',
  'def old_$METHOD($$_) $$BODY end',
  'def new_$METHOD($$_) $$BODY end',
  lang: 'ruby'
)
```

**Add documentation to classes:**

```ruby
result = HermeticSymbolicAnalysis.semantic_rewrite(
  'app.rb',
  'class $CLASS $$BODY end',
  'class $CLASS
  # Documentation for #{$CLASS} class
  $$BODY
end',
  lang: 'ruby'
)
```

### 3. Hybrid Patching

**Intelligent patch application with fallback:**

```ruby
patch_text = <<~PATCH
<<<<<<< SEARCH
:start_line:42
-------
def calculate_total(items)
  total = 0
  items.each { |item| total += item }
  total
end
=======
def calculate_total(items)
  items.sum
end
>>>>>>> REPLACE
PATCH

result = SemanticPatch.apply_hybrid_patch('app.rb', patch_text)

puts "Used strategy: #{result[:strategy]}"
puts "Success: #{result[:ok]}"
```

### 4. Code Analysis and Forecasting

**Extract hermetic symbols from code:**

```ruby
symbols = HermeticSymbolicAnalysis.extract_hermetic_symbols('app.rb')

puts "Elemental patterns found:"
puts "- Fire (methods): #{symbols[:fire]&.size || 0}"
puts "- Earth (classes): #{symbols[:earth]&.size || 0}"
puts "- Air (requires): #{symbols[:air]&.size || 0}"

puts "Alchemical patterns found:"
puts "- TODO items: #{symbols[:nigredo]&.size || 0}"
puts "- FIXME items: #{symbols[:albedo]&.size || 0}"
```

**Forecast transformations for a file:**

```ruby
forecasts = SymbolicForecast.forecast_file_transformations('app.rb')

forecasts.each do |forecast|
  puts "[#{forecast[:confidence] * 100}%] #{forecast[:description]}"
end
```

**Analyze project-wide transformations:**

```ruby
forecasts = SymbolicForecast.forecast_project_transformations('src/')

forecasts.take(10).each do |forecast|
  puts "#{File.basename(forecast[:file])}: #{forecast[:description]}"
end
```

## 🎨 Advanced Patterns

### Custom Pattern Creation

**Create your own hermetic patterns:**

```ruby
# Define custom elemental pattern
CUSTOM_PATTERNS = {
  database: {
    description: "Database query patterns",
    pattern: "$MODEL.where($$CONDITIONS)"
  },
  api: {
    description: "API call patterns", 
    pattern: "$HTTP_METHOD($$URL, $$OPTIONS)"
  }
}

# Extend the pattern matching
result = HermeticSymbolicAnalysis.find_patterns(
  'app.rb', 
  CUSTOM_PATTERNS[:database][:pattern], 
  lang: 'ruby'
)
```

### Pattern Learning from Examples

**Learn patterns from multiple examples:**

```ruby
examples = [
  {
    before: 'User.where(active: true)',
    after: 'User.active'
  },
  {
    before: 'Post.where(published: true)', 
    after: 'Post.published'
  }
]

learned_pattern = SemanticPatch.learn_from_examples('app.rb', examples)
# => { search: '$MODEL.where($$CONDITIONS)', replace: '$MODEL.$SCOPE' }
```

### Batch Operations

**Process multiple files efficiently:**

```ruby
files = ['app.rb', 'lib/utils.rb', 'models/user.rb']

results = files.map do |file|
  {
    file: file,
    symbols: HermeticSymbolicAnalysis.extract_hermetic_symbols(file),
    forecasts: SymbolicForecast.forecast_file_transformations(file)
  }
end
```

**Apply consistent transformations across project:**

```ruby
# Add logging to all methods in all Ruby files
Dir.glob('**/*.rb').each do |ruby_file|
  HermeticSymbolicAnalysis.semantic_rewrite(
    ruby_file,
    'def $METHOD($$_) $$BODY end',
    'def $METHOD($$_) logger.debug("#{$METHOD} called"); $$BODY end',
    lang: 'ruby'
  )
end
```

## 🔧 Troubleshooting

### Common Issues and Solutions

**1. AST-GREP not found:**
```bash
# Install AST-GREP
brew install ast-grep  # macOS
# or
cargo install ast-grep  # from source
```

**2. Pattern matching returns no results:**
- Verify pattern syntax
- Check language specification
- Test pattern directly with AST-GREP CLI

**3. Rewrite doesn't persist changes:**
- Ensure `--update-all` flag is used (automatically handled by the engine)
- Check file permissions
- Verify pattern matches exactly

**4. Performance issues with large codebases:**
- Use `--json=stream` for large files
- Process files in batches
- Cache language detection results

### Debugging Techniques

**Enable debug logging:**

```ruby
# Set debug environment variable
ENV['TM_AI_DEBUG'] = '1'

# Operations will now log detailed information
result = HermeticSymbolicAnalysis.find_patterns('app.rb', 'def $METHOD')
```

**Test patterns directly with AST-GREP:**

```bash
# Test pattern matching
ast-grep run --pattern 'def $METHOD' app.rb --json

# Test rewrite operations
ast-grep run --pattern 'def $METHOD' --rewrite 'def $METHOD; puts "test" end' --update-all app.rb
```

**Verify file content after operations:**

```ruby
# Read file before and after transformation
original_content = File.read('app.rb')
result = HermeticSymbolicAnalysis.semantic_rewrite(...)
new_content = File.read('app.rb')

puts "Changes made:"
puts Diffy::Diff.new(original_content, new_content).to_s(:color)
```

## 🚀 Performance Optimization

### Efficient Pattern Design

**Use specific patterns:**
```ruby
# Instead of broad patterns:
'def $METHOD'  # Too broad

# Use more specific patterns:
'def $METHOD($$_) $$BODY end'  # More specific
'def test_$METHOD'  # Test methods only
```

**Batch operations:**
```ruby
# Process multiple files in single AST-GREP call
HermeticSymbolicAnalysis.ast_grep_execute(
  ['src/**/*.rb'],
  pattern: 'def $METHOD',
  lang: 'ruby'
)
```

### Memory Management

**Stream large results:**
```ruby
# Use streaming for large codebases
result = HermeticSymbolicAnalysis.semantic_search(
  'large_project/',
  'def $METHOD',
  lang: 'ruby'
)
```

**Chunk processing:**
```ruby
# Process large files in chunks
large_files.each_slice(10) do |files_batch|
  files_batch.each do |file|
    HermeticSymbolicAnalysis.extract_hermetic_symbols(file)
  end
end
```

## 📚 Real-World Examples

### Refactoring Legacy Code

```ruby
# Find all old-style class methods
old_methods = HermeticSymbolicAnalysis.find_patterns(
  'legacy_app.rb',
  'def self.$METHOD($$_) $$BODY end',
  lang: 'ruby'
)

# Convert to modern class method syntax
HermeticSymbolicAnalysis.semantic_rewrite(
  'legacy_app.rb',
  'def self.$METHOD($$_) $$BODY end',
  'class << self
    def $METHOD($$_) $$BODY end
  end',
  lang: 'ruby'
)
```

### Adding Documentation

```ruby
# Find all undocumented classes
classes = HermeticSymbolicAnalysis.find_patterns('app.rb', 'class $CLASS', lang: 'ruby')

# Add documentation to each class
classes[:result].each do |class_match|
  class_name = class_match[:match].gsub('class ', '').strip
  
  HermeticSymbolicAnalysis.semantic_rewrite(
    'app.rb',
    "class #{class_name} $$BODY end",
    "class #{class_name}
  # #{class_name} class documentation
  # 
  # This class handles...
  $$BODY
end",
    lang: 'ruby'
  )
end
```

### Security Hardening

```ruby
# Find potential SQL injection patterns
sql_patterns = HermeticSymbolicAnalysis.find_patterns(
  'app.rb',
  '$MODEL.where("$SQL")',
  lang: 'ruby'
)

# Replace with parameterized queries
sql_patterns[:result].each do |sql_match|
  # Custom logic to convert to parameterized queries
  safe_pattern = convert_to_parameterized(sql_match[:match])
  
  HermeticSymbolicAnalysis.semantic_rewrite(
    'app.rb',
    sql_match[:match],
    safe_pattern,
    lang: 'ruby'
  )
end
```

---

*This practical guide demonstrates the power of the Hermetic Symbolic Analysis Engine for real-world code transformation tasks.*
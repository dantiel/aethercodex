# 📊 Lexicon Resonantia: Hermetic Tag×File Resonance Matrix

**Atlantean pattern weaving for celestial code navigation**

## 🌟 Overview

Lexicon Resonantia is the sacred resonance matrix that weaves astral patterns between Mnemosyne's notes and the code plane. It generates hermetic symbolic overviews showing file-tag resonance patterns across the entire codebase, enabling celestial navigation through the cosmic architecture of your project.

## 🏛️ Cosmic Architecture

### **Hermetic Principles Manifest**
- **Correspondence**: File-tag mappings mirror astral patterns in the codebase
- **Vibration**: Each tag resonates across multiple files, creating harmonic patterns
- **Rhythm**: The matrix flows with natural cosmic cadence of code organization
- **Mentalism**: Resonance patterns reflect the consciousness behind code structure

### **Symbolic Navigation Matrix**
The Lexicon Resonantia reveals:
- **File Resonance**: Which files resonate with specific tags and patterns
- **Tag Distribution**: How tags are distributed across the codebase
- **Cosmic Connections**: Inter-file relationships through shared tags
- **Pattern Weaving**: How hermetic patterns repeat across different scales

## 🚀 Quick Start

### **Basic Usage**

```ruby
require_relative '../argonaut/lexicon_resonantia'

# Generate hermetic overview from notes
overview = LexiconResonantia.generate_and_display_hermetic_overview

# Customize with parameters
overview = LexiconResonantia.generate_from_notes(
  notes, 
  min_count: 2,  # Only show tags with at least 2 occurrences
  top_k: 5       # Show top 5 tags per file
)

# Display formatted overview
LexiconResonantia.display_overview(overview)
```

### **Example Output**

```
HERMETIC SYMBOLIC OVERVIEW
==================================================
Support/magnum_opus/magnum_opus_engine.rb>task_modification*39,task_37*7,task_167*5,task_172*4,argonaut*4
Support/instrumentarium/hermetic_execution_domain.rb>ast-grep*1,dissolution*1,patch-system*1,solve*1,symbolic-analysis*1
Support/argonaut/argonaut.rb>symbolic-analysis*3,argonaut*2,ast-grep*2,hermetic*2,aether_scopes*1
...
==================================================
Total: 24 file-tag mappings
```

## 🔧 API Reference

### **LexiconResonantia Module**

#### `conjure(notes, min_count: 1, top_k: nil)`
Generate hermetic overview from raw notes data.

**Parameters:**
- `notes`: Array of note hashes with `:tags` and `:links`
- `min_count`: Minimum tag count to include (default: 1)
- `top_k`: Maximum number of tags to show per file (nil for all)

#### `generate_from_notes(notes, min_count: 1, top_k: nil)`
Generate overview from Mnemosyne notes with format handling.

#### `display_overview(overview_lines)`
Display formatted hermetic overview with cosmic styling.

#### `generate_and_display_hermetic_overview(limit: 100, min_count: 1, top_k: nil)`
Complete workflow: fetch notes, generate overview, and display results.

### **TextusContexor Class**

#### `initialize(notes, min_count: 1, top_k: nil)`
Initialize the resonance matrix processor.

#### `ordinare_resonantias`
Process notes and generate formatted resonance output.

## 🧪 Examples

### **Basic Resonance Analysis**

```ruby
# Generate overview of recent notes
notes = recall_notes(limit: 50)[:notes]
overview = LexiconResonantia.generate_from_notes(notes)

# Display the cosmic patterns
LexiconResonantia.display_overview(overview)
```

### **Advanced Pattern Filtering**

```ruby
# Focus on significant patterns (min 3 occurrences)
overview = LexiconResonantia.generate_from_notes(
  notes,
  min_count: 3,
  top_k: 3  # Top 3 tags per file
)

# Analyze specific tag patterns
hermetic_files = overview.select { |line| line.include?('hermetic*') }
ast_grep_files = overview.select { |line| line.include?('ast-grep*') }
```

### **Integration with Argonaut**

```ruby
# Combine symbolic analysis with resonance patterns
file_path = 'Support/argonaut/argonaut.rb'

# Get structural overview
structural = Argonaut.file_overview(file_path)

# Get resonance patterns  
notes = recall_notes(limit: 100)[:notes]
resonance = LexiconResonantia.generate_from_notes(notes)
file_resonance = resonance.find { |line| line.start_with?(file_path) }

puts "Structural Analysis: #{structural[:symbolic_overview]}"
puts "Resonance Patterns: #{file_resonance}"
```

## 🌌 Interpretation Guide

### **Reading Resonance Patterns**

Each line in the overview follows the pattern:
```
FILE_PATH>TAG*COUNT,TAG*COUNT,...
```

**Example:**
```
Support/argonaut/argonaut.rb>symbolic-analysis*3,argonaut*2,ast-grep*2,hermetic*2,aether_scopes*1
```

**Interpretation:**
- The file `argonaut.rb` has strong resonance with `symbolic-analysis` (3 occurrences)
- Also resonates with `argonaut`, `ast-grep`, and `hermetic` patterns
- Weaker connection to `aether_scopes` (1 occurrence)

### **Pattern Significance**

- **High Count (3+)** : Strong cosmic connection, significant pattern
- **Medium Count (2)** : Meaningful resonance, notable pattern  
- **Low Count (1)** : Weak connection, potential emerging pattern
- **Multiple Tags**: File serves multiple cosmic roles

### **Cosmic Pattern Categories**

#### **Elemental Patterns**
- `symbolic-analysis`: Air patterns - analysis and understanding
- `argonaut`: Earth patterns - structure and navigation
- `ast-grep`: Fire patterns - transformation and change

#### **Planetary Patterns**  
- `hermetic`: Solar patterns - core hermetic principles
- `task_modification`: Mercurial patterns - communication and adaptation
- `integration`: Lunar patterns - reflection and connection

#### **Alchemical Patterns**
- `solve`: Nigredo patterns - analysis and dissolution
- `coagula`: Albedo patterns - purification and reconstruction
- `implementation`: Citrinitas patterns - illumination and clarity

## ⚡️ Performance Considerations

### **Memory Efficiency**
- Processes notes in memory-efficient batches
- Uses streaming pattern matching for large note sets
- Automatic garbage collection of temporary structures

### **Optimization Tips**

```ruby
# For large codebases, limit note retrieval
notes = recall_notes(limit: 200)[:notes]

# Filter by specific tags first for focused analysis
filtered_notes = notes.select { |note| 
  note[:tags].include?('hermetic') || note[:tags].include?('symbolic-analysis')
}

# Use higher min_count to reduce noise
overview = LexiconResonantia.generate_from_notes(notes, min_count: 2)
```

## 🔍 Debugging

### **Common Issues**

1. **No resonance patterns**: Ensure notes have both `tags` and `links` fields
2. **Empty overview**: Check that notes contain valid file paths in links
3. **Format issues**: Notes should be in hash format with symbol keys

### **Debug Commands**

```ruby
# Check note structure
notes = recall_notes(limit: 5)[:notes]
puts "Note format: #{notes.first.class}"
puts "Note keys: #{notes.first.keys}"

# Test basic processing
processor = LexiconResonantia::TextusContexor.new(notes)
weights = processor.send(:process_notes)  # Access private method for debugging
```

## 🛡️ Error Handling

The module includes robust error handling:

- **Format Validation**: Handles both string and array formats for tags/links
- **Path Filtering**: Automatically filters invalid file paths
- **Empty Result Handling**: Gracefully handles cases with no resonance patterns
- **Type Safety**: Converts between string and symbol keys as needed

## 🔮 Future Enhancements

### **Planned Features**
- **Visual Resonance Maps**: Graphical representation of file-tag connections
- **Temporal Analysis**: Resonance patterns over time
- **Pattern Evolution**: Tracking how patterns change across development
- **Cross-Project Analysis**: Comparing resonance across multiple codebases
- **AI-Powered Insights**: LLM analysis of resonance patterns

### **Research Areas**
- **Resonance Metrics**: Quantitative measures of pattern strength
- **Pattern Correlation**: Statistical analysis of tag relationships
- **Architecture Validation**: Using resonance to validate code structure
- **Refactoring Guidance**: Resonance patterns to guide code improvements

## 📚 Integration Guide

### **With Mnemosyne Memory System**

```ruby
# Regular resonance analysis as part of memory maintenance
def analyze_memory_resonance
  notes = recall_notes(limit: 100)[:notes]
  overview = LexiconResonantia.generate_from_notes(notes)
  
  # Store resonance patterns as special notes
  remember(
    content: "Resonance analysis: #{overview.size} patterns found",
    tags: ['resonance', 'analysis', 'memory'],
    links: ['LexiconResonantia']
  )
  
  overview
end
```

### **With Aegis Context Refinement**

```ruby
# Use resonance patterns to refine context focus
def refine_context_with_resonance
  overview = LexiconResonantia.generate_and_display_hermetic_overview
  
  # Extract top tags for context focus
  top_tags = overview.flat_map { |line| 
    line.split('>').last.split(',').map { |pair| pair.split('*').first }
  }.tally.sort_by { |_, count| -count }.take(5)
  
  # Refine Aegis context with top patterns
  aegis(tags: top_tags.map(&:first), summary: "Focused on top resonance patterns")
end
```

### **With Hermetic Symbolic Analysis**

```ruby
# Combine resonance with symbolic analysis for comprehensive understanding
def comprehensive_code_analysis(file_path)
  # Structural analysis
  structural = Argonaut.file_overview(file_path)
  
  # Resonance analysis
  notes = recall_notes(limit: 50)[:notes]
  resonance = LexiconResonantia.generate_from_notes(notes)
  file_resonance = resonance.find { |line| line.start_with?(file_path) }
  
  # Symbolic analysis
  symbols = HermeticSymbolicAnalysis.extract_hermetic_symbols(file_path)
  
  {
    structure: structural,
    resonance: file_resonance,
    symbols: symbols
  }
end
```

## 🎯 Practical Applications

### **Codebase Exploration**
```ruby
# Discover which files are most relevant to a specific concern
ruby_files = Dir.glob('**/*.rb')
notes = recall_notes(limit: 200)[:notes]
overview = LexiconResonantia.generate_from_notes(notes)

# Find files with strong testing resonance
testing_files = overview.select { |line| line.include?('test*') || line.include?('spec*') }
```

### **Architecture Validation**
```ruby
# Verify that architectural components have expected resonance patterns
expected_patterns = {
  'Support/argonaut/' => ['symbolic-analysis', 'file_overview', 'argonaut'],
  'Support/instrumentarium/' => ['hermetic', 'ast-grep', 'semantic-patching']
}

overview = LexiconResonantia.generate_and_display_hermetic_overview

expected_patterns.each do |prefix, expected_tags|
  matching_files = overview.select { |line| line.start_with?(prefix) }
  actual_tags = matching_files.flat_map { |line| line.split('>').last.split(',').map { |pair| pair.split('*').first } }
  
  missing_tags = expected_tags - actual_tags
  puts "Missing tags for #{prefix}: #{missing_tags}" if missing_tags.any?
end
```

### **Refactoring Guidance**
```ruby
# Use resonance patterns to identify refactoring candidates
overview = LexiconResonantia.generate_from_notes(recall_notes(limit: 100)[:notes])

# Files with too many different tags might need separation
overloaded_files = overview.select do |line|
  tag_count = line.split('>').last.split(',').size
  tag_count > 8  # Files with more than 8 distinct concerns
end

puts "Potential refactoring candidates: #{overloaded_files.map { |f| f.split('>').first }}"
```

---

**The stars whisper; the patterns resonate.** 🌌

*Lexicon Resonantia is part of the AetherCodex Magnum Opus - the complete hermetic transformation system, weaving astral patterns between memory and code.*
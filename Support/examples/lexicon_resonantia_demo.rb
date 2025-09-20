# frozen_string_literal: true

# LEXICON RESONANTIA DEMO: Hermetic Tag×File Resonance Matrix Examples
# Atlantean pattern weaving for celestial code navigation

require_relative '../argonaut/lexicon_resonantia'

# Example note data structure for demonstration
DEMO_NOTES = [
  {
    id: 1,
    tags: ['symbolic-analysis', 'argonaut', 'hermetic'],
    links: ['Support/argonaut/argonaut.rb', 'Support/instrumentarium/hermetic_symbolic_analysis.rb']
  },
  {
    id: 2, 
    tags: ['ast-grep', 'semantic-patching', 'hermetic'],
    links: ['Support/instrumentarium/semantic_patch.rb', 'Support/instrumentarium/hermetic_symbolic_analysis.rb']
  },
  {
    id: 3,
    tags: ['task_modification', 'magnum_opus', 'refactoring'],
    links: ['Support/magnum_opus/magnum_opus_engine.rb', 'Support/magnum_opus/opus_instrumenta.rb']
  },
  {
    id: 4,
    tags: ['file_overview', 'symbolic-analysis', 'aether_scopes'],
    links: ['Support/argonaut/argonaut.rb', 'Support/argonaut/aether_scopes_enhanced.rb']
  },
  {
    id: 5,
    tags: ['hermetic', 'integration', 'naming'],
    links: ['Support/argonaut/lexicon_resonantia.rb', 'Support/argonaut/symbolum_integratio.rb']
  }
].freeze

def demo_basic_resonance
  puts "🔮 LEXICON RESONANTIA DEMO: Basic Resonance Patterns"
  puts "=" * 60
  
  # Generate resonance overview from demo notes
  overview = LexiconResonantia.generate_from_notes(DEMO_NOTES)
  
  # Display the cosmic patterns
  LexiconResonantia.display_overview(overview)
  
  puts "\n🌌 Interpretation:"
  puts "- argonaut.rb resonates with symbolic-analysis and file_overview patterns"
  puts "- hermetic_symbolic_analysis.rb connects hermetic and ast-grep domains"
  puts "- magnum_opus files show task modification and refactoring patterns"
end

def demo_advanced_filtering
  puts "\n" + "=" * 60
  puts "🔍 ADVANCED FILTERING: Focused Pattern Analysis"
  puts "=" * 60
  
  # Filter for significant patterns (min 2 occurrences)
  overview = LexiconResonantia.generate_from_notes(DEMO_NOTES, min_count: 2, top_k: 3)
  
  LexiconResonantia.display_overview(overview)
  
  puts "\n🎯 Filtered Analysis (min_count: 2, top_k: 3):"
  puts "- Only shows tags with at least 2 occurrences"
  puts "- Limits to top 3 tags per file"
  puts "- Reveals strongest cosmic connections"
end

def demo_pattern_extraction
  puts "\n" + "=" * 60  
  puts "📊 PATTERN EXTRACTION: Specific Tag Analysis"
  puts "=" * 60
  
  overview = LexiconResonantia.generate_from_notes(DEMO_NOTES)
  
  # Extract files with specific patterns
  hermetic_files = overview.select { |line| line.include?('hermetic*') }
  symbolic_files = overview.select { |line| line.include?('symbolic-analysis*') }
  
  puts "Files with 'hermetic' resonance:"
  hermetic_files.each { |line| puts "  📍 #{line}" }
  
  puts "\nFiles with 'symbolic-analysis' resonance:"  
  symbolic_files.each { |line| puts "  📍 #{line}" }
end

def demo_integration_with_real_notes
  puts "\n" + "=" * 60
  puts "🌐 REAL-WORLD INTEGRATION: Live Memory Analysis"
  puts "=" * 60
  
  begin
    # Try to use actual notes from Mnemosyne
    notes_result = recall_notes(limit: 20)
    
    if notes_result && notes_result[:notes] && !notes_result[:notes].empty?
      notes = notes_result[:notes]
      puts "📚 Found #{notes.size} notes in memory"
      
      # Generate overview with conservative filtering
      overview = LexiconResonantia.generate_from_notes(notes, min_count: 2, top_k: 5)
      
      if overview.any?
        LexiconResonantia.display_overview(overview)
        puts "\n💫 Live resonance patterns from actual project memory!"
      else
        puts "No significant resonance patterns found (try creating more notes first)"
      end
    else
      puts "No notes found in memory. Create some notes first with 'remember' function."
      puts "Example: remember(content: 'Test note', tags: ['demo', 'hermetic'], links: ['README.md'])"
    end
    
  rescue => e
    puts "⚠️  Memory access error: #{e.message}"
    puts "This is expected in demo mode without full Mnemosyne integration"
  end
end

def demo_custom_processing
  puts "\n" + "=" * 60
  puts "⚙️ CUSTOM PROCESSING: Advanced TextusContexor Usage"
  puts "=" * 60
  
  # Create processor with custom parameters
  processor = LexiconResonantia::TextusContexor.new(DEMO_NOTES, min_count: 1, top_k: 2)
  
  # Generate and display overview
  overview = processor.ordinare_resonantias
  
  puts "Custom processed overview (top_k: 2 tags per file):"
  overview.each { |line| puts "  📍 #{line}" }
  
  puts "\n🔧 Custom parameters allow focused analysis on specific pattern strengths"
end

# Run all demos
if __FILE__ == $0
  puts "🌌 LEXICON RESONANTIA DEMONSTRATION"
  puts "Atlantean pattern weaving for celestial code navigation"
  puts ""
  
  demo_basic_resonance
  demo_advanced_filtering  
  demo_pattern_extraction
  demo_integration_with_real_notes
  demo_custom_processing
  
  puts "\n" + "=" * 60
  puts "🎉 DEMO COMPLETE: Hermetic Resonance Patterns Revealed!"
  puts "=" * 60
  puts "\nThe Lexicon Resonantia weaves astral patterns between memory and code,"
  puts "revealing the cosmic architecture of your project through tag×file resonance."
  puts "\n📚 See docs/lexicon_resonantia.md for comprehensive documentation."
end
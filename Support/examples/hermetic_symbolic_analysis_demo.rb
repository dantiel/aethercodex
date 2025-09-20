# frozen_string_literal: true

# Hermetic Symbolic Analysis Engine Demo
# Comprehensive demonstration of AST-GREP powered semantic code transformations

require_relative '../instrumentarium/hermetic_symbolic_analysis'
require_relative '../instrumentarium/semantic_patch'
require_relative '../instrumentarium/symbolic_forecast'

# Create demo files for testing
class HermeticSymbolicAnalysisDemo
  def self.run_demo
    puts "🌌 Hermetic Symbolic Analysis Engine Demo"
    puts "=" * 50
    
    # Create demo files
    create_demo_files
    
    # Run demonstrations
    demonstrate_pattern_matching
    demonstrate_semantic_rewriting
    demonstrate_hybrid_patching
    demonstrate_symbol_extraction
    demonstrate_forecasting
    
    puts "\n🎉 Demo completed successfully!"
    
  ensure
    # Clean up demo files
    cleanup_demo_files
  end
  
  def self.create_demo_files
    puts "\n📝 Creating demo files..."
    
    # Demo Ruby file
    File.write('demo_app.rb', <<~RUBY)
      # Demo application for hermetic symbolic analysis
      
      class Calculator
        def initialize
          @value = 0
        end
        
        def add(x)
          @value += x
          @value
        end
        
        def subtract(x)
          @value -= x
          @value
        end
        
        # TODO: Add multiplication functionality
        # FIXME: Handle division by zero
      end
      
      module MathUtils
        def self.square(x)
          x * x
        end
        
        def self.cube(x)
          x * x * x
        end
      end
      
      # Main execution
      calc = Calculator.new
      calc.add(10)
    RUBY
    
    # Demo JavaScript file
    File.write('demo_app.js', <<~JS)
      // Demo JavaScript application
      
      class Calculator {
        constructor() {
          this.value = 0;
        }
        
        add(x) {
          this.value += x;
          return this.value;
        }
        
        subtract(x) {
          this.value -= x;
          return this.value;
        }
        
        // TODO: Add multiplication
        // FIXME: Handle division properly
      }
      
      function square(x) {
        return x * x;
      }
      
      function cube(x) {
        return x * x * x;
      }
      
      // Usage
      const calc = new Calculator();
      const result = calc.add(5);
      console.log(`Result: ${result}`);
    JS
    
    puts "✅ Demo files created: demo_app.rb, demo_app.js"
  end
  
  def self.cleanup_demo_files
    files = ['demo_app.rb', 'demo_app.js']
    files.each { |file| File.delete(file) if File.exist?(file) }
    puts "🧹 Cleaned up demo files"
  end
  
  def self.demonstrate_pattern_matching
    puts "\n🔍 Demonstrating Pattern Matching..."
    
    # Find method definitions in Ruby
    result = HermeticSymbolicAnalysis.find_patterns('demo_app.rb', 'def $METHOD', lang: 'ruby')
    
    if result[:success]
      puts "✅ Found #{result[:result].size} methods in Ruby file:"
      result[:result].each { |match| puts "  - #{match[:match]}" }
    else
      puts "❌ Pattern matching failed: #{result[:error]}"
    end
    
    # Find class definitions in JavaScript
    result = HermeticSymbolicAnalysis.find_patterns('demo_app.js', 'class $CLASS', lang: 'javascript')
    
    if result[:success]
      puts "✅ Found #{result[:result].size} classes in JavaScript file:"
      result[:result].each { |match| puts "  - #{match[:match]}" }
    end
  end
  
  def self.demonstrate_semantic_rewriting
    puts "\n🔄 Demonstrating Semantic Rewriting..."
    
    # Backup original content
    original_content = File.read('demo_app.rb')
    
    # Add logging to all methods
    result = HermeticSymbolicAnalysis.semantic_rewrite(
      'demo_app.rb',
      'def $METHOD($$_) $$BODY end',
      'def $METHOD($$_) puts "Method #{$METHOD} called"; $$BODY end',
      lang: 'ruby'
    )
    
    if result[:success]
      puts "✅ Successfully added logging to methods"
      
      # Show modified content
      modified_content = File.read('demo_app.rb')
      puts "\nModified content preview:"
      puts modified_content.lines.grep(/puts "Method/).join
      
      # Restore original content
      File.write('demo_app.rb', original_content)
      puts "✅ Restored original content"
    else
      puts "❌ Semantic rewrite failed: #{result[:error]}"
    end
  end
  
  def self.demonstrate_hybrid_patching
    puts "\n🔀 Demonstrating Hybrid Patching..."
    
    # Create a patch
    patch_text = <<~PATCH
<<<<<<< SEARCH
:start_line:15
-------
        def subtract(x)
          @value -= x
          @value
        end
=======
        def subtract(x)
          puts "Subtracting number"
          @value -= x
          @value
        end
>>>>>>> REPLACE
PATCH
    
    # Apply hybrid patch
    result = SemanticPatch.apply_hybrid_patch('demo_app.rb', patch_text)
    
    if result[:ok]
      puts "✅ Hybrid patch applied successfully using strategy: #{result[:strategy]}"
      
      # Show the modified method
      content = File.read('demo_app.rb')
      subtract_method = content.lines[14..19].join
      puts "\nModified subtract method:"
      puts subtract_method
      
      # Restore from backup
      File.write('demo_app.rb', result[:original_content])
      puts "✅ Restored original content"
    else
      puts "❌ Hybrid patch failed: #{result[:error]}"
    end
  end
  
  def self.demonstrate_symbol_extraction
    puts "\n🔮 Demonstrating Hermetic Symbol Extraction..."
    
    symbols = HermeticSymbolicAnalysis.extract_hermetic_symbols('demo_app.rb')
    
    puts "✅ Extracted hermetic symbols:"
    
    # Elemental patterns
    puts "\n🔥 Elemental Patterns:"
    puts "  - Fire (methods): #{symbols[:fire]&.size || 0} methods"
    puts "  - Earth (classes): #{symbols[:earth]&.size || 0} classes"
    puts "  - Air (modules): #{symbols[:air]&.size || 0} modules"
    
    # Alchemical patterns  
    puts "\n⚗️ Alchemical Patterns:"
    puts "  - Nigredo (TODOs): #{symbols[:nigredo]&.size || 0} items"
    puts "  - Albedo (FIXMEs): #{symbols[:albedo]&.size || 0} items"
    
    # Show specific patterns if found
    if symbols[:nigredo] && symbols[:nigredo].any?
      puts "\n📋 TODO items found:"
      symbols[:nigredo].each { |item| puts "  - #{item[:match]}" }
    end
  end
  
  def self.demonstrate_forecasting
    puts "\n🔮 Demonstrating Symbolic Forecasting..."
    
    forecasts = SymbolicForecast.forecast_file_transformations('demo_app.rb')
    
    puts "✅ Transformation forecasts:"
    
    forecasts.each do |forecast|
      confidence = (forecast[:confidence] * 100).round
      puts "  [#{confidence}%] #{forecast[:description]}"
    end
    
    # Generate patch suggestions
    suggestions = SymbolicForecast.generate_patch_suggestions(forecasts)
    
    puts "\n💡 Patch suggestions:"
    suggestions.each do |suggestion|
      puts "  - #{suggestion[:description]}"
      puts "    #{suggestion[:suggested_patch]}"
    end
  end
end

# Run the demo if executed directly
if __FILE__ == $0
  begin
    HermeticSymbolicAnalysisDemo.run_demo
  rescue => e
    puts "❌ Demo failed with error: #{e.message}"
    puts e.backtrace.join("\n")
  end
end
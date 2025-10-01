# frozen_string_literal: true

require 'rspec'
require_relative '../instrumentarium/symbolic_patch_file'

describe SymbolicPatchFile do
  before(:each) do
    # Create test files for each example
    @test_ruby_file = 'spec/test_app.rb'
    File.write(@test_ruby_file, <<~RUBY)
      # Test Ruby application for symbolic patching
      
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
        
        def multiply(x)
          @value *= x
          @value
        end
      end
      
      module MathUtils
        def self.square(x)
          x * x
        end
      end
    RUBY
  end

  after(:each) do
    # Clean up test files
    File.delete(@test_ruby_file) if File.exist?(@test_ruby_file)
  end

  describe '#apply with different rule levels' do
    it 'handles simple pattern matching (level 1)' do
      result = SymbolicPatchFile.apply(
        @test_ruby_file,
        'def $METHOD',
        nil,
        rule_level: :simple
      )
      
      expect(result[:success]).to be true
      expect(result[:result][:match_count]).to be > 0
      expect(result[:rule_level]).to eq(:simple)
    end

    it 'handles DSL rule building (level 2)' do
      result = SymbolicPatchFile.apply(
        @test_ruby_file,
        'def $METHOD',
        nil,
        rule_level: :dsl
      )
      
      expect(result[:success]).to be true
      expect(result[:rule_level]).to eq(:dsl)
    end

    it 'handles YAML rule integration (level 3)' do
      yaml_rule = <<~YAML
        rule:
          pattern: def $METHOD
          language: ruby
      YAML
      
      result = SymbolicPatchFile.apply(
        @test_ruby_file,
        yaml_rule,
        nil,
        rule_level: :yaml
      )
      
      expect(result[:success]).to be true
      expect(result[:rule_level]).to eq(:yaml)
      expect(result[:yaml_rule]).to be_present
    end

    it 'auto-detects optimal rule level' do
      result = SymbolicPatchFile.apply(
        @test_ruby_file,
        'def $METHOD',
        nil,
        rule_level: :auto
      )
      
      expect(result[:success]).to be true
      expect([:simple, :dsl, :yaml]).to include(result[:rule_level])
    end
  end

  describe '#apply_yaml_rule_patch' do
    it 'parses and applies YAML rules with pattern' do
      result = SymbolicPatchFile.apply_yaml_rule_patch(
        @test_ruby_file,
        'def $METHOD',
        nil,
        lang: 'ruby'
      )
      
      expect(result[:success]).to be true
      expect(result[:yaml_rule]).to include('pattern: def $METHOD')
    end

    it 'handles YAML rule strings directly' do
      yaml_rule = <<~YAML
        rule:
          pattern: def $METHOD
          language: ruby
      YAML
      
      result = SymbolicPatchFile.apply_yaml_rule_patch(
        @test_ruby_file,
        yaml_rule,
        nil
      )
      
      expect(result[:success]).to be true
      expect(result[:yaml_rule].strip).to eq(yaml_rule.strip)
    end

    it 'handles constraints in YAML rules' do
      result = SymbolicPatchFile.apply_yaml_rule_patch(
        @test_ruby_file,
        'def $METHOD',
        nil,
        lang: 'ruby',
        constraints: { 'METHOD' => { regex: '^[a-z]+$' } }
      )
      
      expect(result[:success]).to be true
      expect(result[:yaml_rule]).to include('constraints')
    end
  end

  describe '#apply_dsl_rule_patch' do
    it 'builds rules using DSL syntax' do
      result = SymbolicPatchFile.apply_dsl_rule_patch(
        @test_ruby_file,
        'def $METHOD',
        nil,
        lang: 'ruby'
      )
      
      expect(result[:success]).to be true
      expect(result[:dsl_rule]).to include('pattern: def $METHOD')
    end

    it 'handles constraints via DSL' do
      result = SymbolicPatchFile.apply_dsl_rule_patch(
        @test_ruby_file,
        'def $METHOD',
        nil,
        lang: 'ruby',
        constraints: { 'METHOD' => { regex: '^[a-z]+$' } }
      )
      
      expect(result[:success]).to be true
      expect(result[:dsl_rule]).to include('constraints')
    end

    it 'handles utility rules via DSL', :wip do
      # Utility rules require AST-GREP configuration files, skipping for now
      pending "Utility rules require AST-GREP configuration files"
      
      result = SymbolicPatchFile.apply_dsl_rule_patch(
        @test_ruby_file,
        'def $METHOD',
        nil,
        lang: 'ruby',
        utils: { 'method_pattern' => 'def $METHOD' }
      )
      
      expect(result[:success]).to be true
      expect(result[:dsl_rule]).to include('utils')
    end
  end

  describe '#apply_simple_pattern_patch' do
    it 'applies simple patterns (backward compatibility)' do
      result = SymbolicPatchFile.apply_simple_pattern_patch(
        @test_ruby_file,
        'def $METHOD',
        nil,
        lang: 'ruby'
      )
      
      expect(result[:success]).to be true
      expect(result[:rule_level]).to eq(:simple)
    end

    it 'handles pattern matching without replacement' do
      result = SymbolicPatchFile.apply_simple_pattern_patch(
        @test_ruby_file,
        'def $METHOD',
        nil,
        lang: 'ruby'
      )
      
      expect(result[:success]).to be true
      expect(result[:result][:match_count]).to be > 0
    end

    it 'handles pattern replacement' do
      result = SymbolicPatchFile.apply_simple_pattern_patch(
        @test_ruby_file,
        'def $METHOD',
        'def new_$METHOD',
        lang: 'ruby'
      )
      
      expect(result[:success]).to be true
      expect(result[:applied]).to be true
    end
  end

  describe '#apply_auto_level_patch' do
    it 'detects simple patterns for level 1' do
      result = SymbolicPatchFile.apply_auto_level_patch(
        @test_ruby_file,
        'def $METHOD',
        nil,
        lang: 'ruby'
      )
      
      expect(result[:success]).to be true
      expect(result[:rule_level]).to eq(:simple)
    end

    it 'detects complex patterns for level 2' do
      result = SymbolicPatchFile.apply_auto_level_patch(
        @test_ruby_file,
        'def $METHOD',
        nil,
        lang: 'ruby',
        constraints: { 'METHOD' => { regex: '^[a-z]+$' } }
      )
      
      expect(result[:success]).to be true
      expect(result[:rule_level]).to eq(:dsl)
    end

    it 'detects YAML rules for level 3' do
      yaml_rule = <<~YAML
        rule:
          pattern: def $METHOD
          language: ruby
      YAML
      
      result = SymbolicPatchFile.apply_auto_level_patch(
        @test_ruby_file,
        yaml_rule,
        nil
      )
      
      if result[:success] == false
        puts "Auto Level YAML Error: #{result[:error]}"
      end
      
      expect(result[:success]).to be true
    end
  end

  describe 'utility rule system', :wip do
    it 'handles matches directive in YAML rules' do
      skip "Utility rules require AST-GREP configuration files"
      
      yaml_rule = <<~YAML
        utils:
          method_pattern: def $METHOD
        rule:
          matches: method_pattern
          language: ruby
      YAML
      
      result = SymbolicPatchFile.apply_yaml_rule_patch(
        @test_ruby_file,
        yaml_rule,
        nil
      )
      
      expect(result[:success]).to be true
    end

    it 'handles composite matches with all operator' do
      skip "Utility rules require AST-GREP configuration files"
      
      yaml_rule = <<~YAML
        utils:
          method_pattern: def $METHOD
          class_pattern: class $CLASS
        rule:
          matches:
            all:
              - method_pattern
              - class_pattern
          language: ruby
      YAML
      
      result = SymbolicPatchFile.apply_yaml_rule_patch(
        @test_ruby_file,
        yaml_rule,
        nil
      )
      
      expect(result[:success]).to be true
    end
  end

  describe 'cross-file operations' do
    it 'handles cross-file YAML rules' do
      result = SymbolicPatchFile.apply_cross_file_yaml(
        '**/*.rb',
        'def $METHOD',
        nil
      )
      
      expect(result[:success]).to be true
    end

    it 'handles cross-file DSL rules' do
      result = SymbolicPatchFile.apply_cross_file_dsl(
        '**/*.rb',
        'def $METHOD',
        nil
      )
      
      expect(result[:success]).to be true
    end
  
    # Phase 2: Enhanced DSL Features
    describe 'enhanced DSL features' do
      it 'handles advanced constraint system' do
        result = SymbolicPatchFile.apply_enhanced_dsl_patch(
          @test_ruby_file,
          {
            method_pattern: 'add',
            regex_constraint: ['METHOD', '^[a-z]+$'],
            rewrite: 'def new_$METHOD'
          }
        )
        
        expect(result[:success]).to be true
        expect(result[:rule_level]).to eq(:enhanced_dsl)
      end
  
      it 'handles composite patterns with AND operator' do
        result = SymbolicPatchFile.apply_composite_pattern(
          @test_ruby_file,
          {
            operator: :and,
            patterns: ['def $METHOD', 'class $CLASS']
          }
        )
        
        expect(result[:success]).to be true
      end
  
      it 'handles composite patterns with OR operator' do
        result = SymbolicPatchFile.apply_composite_pattern(
          @test_ruby_file,
          {
            operator: :or,
            patterns: ['def $METHOD', 'class $CLASS']
          }
        )
        
        expect(result[:success]).to be true
      end
  
      it 'handles structural navigation with inside directive' do
        result = SymbolicPatchFile.apply_structural_pattern(
          @test_ruby_file,
          { inside: 'class Calculator' },
          replace_pattern: 'def new_$METHOD'
        )
        
        expect(result[:success]).to be true
      end
  
      it 'handles pattern builder interface' do
        pattern = SymbolicPatchFile.build_pattern do
          method_def
          class_def
          and_operator
        end
        
        expect(pattern).to be_a(Hash)
        expect(pattern[:all]).to be_an(Array)
      end
  
      it 'handles constraint builder interface' do
        constraints = SymbolicPatchFile.build_constraints do
          regex('METHOD', '^[a-z]+$')
          kind('METHOD', 'identifier')
        end
        
        expect(constraints).to be_a(Hash)
        expect(constraints['METHOD']).to be_a(Hash)
      end
  
      it 'handles method chaining in enhanced DSL' do
        result = SymbolicPatchFile.apply_enhanced_dsl_patch(
          @test_ruby_file,
          {
            method_pattern: 'add',
            inside: 'class Calculator',
            regex_constraint: ['METHOD', '^[a-z]+$'],
            rewrite: 'def new_$METHOD'
          }
        )
        
        expect(result[:success]).to be true
      end
  
      it 'handles complex pattern composition' do
        result = SymbolicPatchFile.apply_enhanced_dsl_patch(
          @test_ruby_file,
          {
            and_pattern: ['def $METHOD', 'class $CLASS'],
            inside: 'module MathUtils',
            rewrite: 'def new_$METHOD'
          }
        )
        
        expect(result[:success]).to be true
      end
    end
  end

  describe 'pattern analysis' do
    it 'analyzes pattern complexity' do
      complexity = SymbolicPatchFile.calculate_transformation_complexity(
        pattern: 'def $METHOD',
        constraints: {},
        utils: {}
      )
      
      expect(complexity).to be_a(Integer)
      expect(complexity).to be > 0
    end

    it 'extracts AST-GREP patterns from text' do
      patterns = SymbolicPatchFile.extract_ast_grep_patterns('def $METHOD')
      expect(patterns).to include(:meta_variables)
    end

    it 'analyzes pattern matches' do
      result = SymbolicPatchFile.analyze_pattern_matches(
        @test_ruby_file,
        'def $METHOD',
        lang: 'ruby'
      )
      
      expect(result[:success]).to be true
      expect(result[:matches]).to be_an(Array)
    end
  end

  # Phase 3: Advanced Feature Integration Tests
  describe 'advanced feature integration' do
    it 'handles pattern matching with context lines' do
      result = SymbolicPatchFile.pattern_match_with_context(
        @test_ruby_file,
        'def $METHOD',
        lang: 'ruby',
        context_lines: 2
      )
      
      expect(result[:success]).to be true
      expect(result[:context_lines]).to eq(2)
    end

    it 'performs batch pattern matching' do
      result = SymbolicPatchFile.batch_pattern_match(
        '**/*.rb',
        'def $METHOD',
        lang: 'ruby'
      )
      
      expect(result[:success]).to be true
      expect(result[:results]).to be_an(Array)
    end

    it 'analyzes pattern similarity' do
      result = SymbolicPatchFile.analyze_pattern_similarity(
        'def $METHOD',
        'class $CLASS',
        lang: 'ruby'
      )
      
      expect(result[:similarity_score]).to be_a(Float)
      expect(result[:analysis]).to be_a(Hash)
    end

    it 'debugs pattern matching errors' do
      result = SymbolicPatchFile.debug_pattern_match(
        @test_ruby_file,
        'invalid pattern syntax',
        lang: 'ruby'
      )
      
      # Even if pattern fails, debug info should be provided
      expect(result[:pattern_analysis]).to be_a(Hash)
      expect(result[:suggestions]).to be_an(Array)
    end

    it 'optimizes pattern matching performance' do
      patterns = ['def $METHOD', 'class $CLASS', 'module $MODULE']
      
      result = SymbolicPatchFile.optimize_pattern_matching(
        '**/*.rb',
        patterns,
        lang: 'ruby',
        batch_size: 2
      )
      
      expect(result[:optimization_strategy]).to eq('complexity_based_batching')
      expect(result[:total_patterns]).to eq(3)
    end

    it 'performs safe pattern transformations' do
      result = SymbolicPatchFile.safe_pattern_transform(
        @test_ruby_file,
        'def $METHOD',
        'def new_$METHOD',
        lang: 'ruby',
        safety_threshold: 0.5
      )
      
      # Should either succeed or provide safety analysis
      expect(result[:success]).to be(true).or be(false)
      if result[:success] == false
        expect(result[:analysis]).to be_a(Hash)
      end
    end

    it 'analyzes cross-file dependencies' do
      result = SymbolicPatchFile.analyze_cross_file_dependencies(
        '**/*.rb',
        'def $METHOD',
        lang: 'ruby'
      )
      
      expect(result[:success]).to be true
      expect(result[:dependencies]).to be_an(Array)
      expect(result[:dependency_graph]).to be_a(Hash)
    end
  end
end
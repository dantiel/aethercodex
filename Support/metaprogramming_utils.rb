# Metaprogramming Utilities for AetherCodex
# Higher-order hermetic constructs for symbolic transmutation and pattern resonance

# Atlantean-Hermetic metaprogramming constructs
# These embody deep hermetic principles of transformation, containment, and symbolic resonance

# Hermetic Execution Domain - creates protected execution contexts
class HermeticExecutionDomain
  def initialize(context = {})
    @context = context
    @error_handlers = []
    @transmutation_rules = {}
  end
  
  # Execute code within protected domain with automatic error containment
  def execute(&block)
    begin
      result = instance_exec(&block)
      @last_result = result
      result
    rescue => e
      handle_error(e)
      nil # Hermetic containment - errors don't escape
    end
  end
  
  # Define error handler for specific error patterns
  def on_error(pattern = //, &handler)
    @error_handlers << { pattern: pattern, handler: handler }
    self
  end
  
  # Define transmutation rule for method patterns
  def transmute(pattern, &transmuter)
    @transmutation_rules[pattern] = transmuter
    self
  end
  
  # Access domain context
  def [](key)
    @context[key]
  end
  
  # Set domain context
  def []=(key, value)
    @context[key] = value
  end
  
  private
  
  def handle_error(error)
    matching_handler = @error_handlers.find do |handler|
      error.message.match?(handler[:pattern]) || error.class.name.match?(handler[:pattern])
    end
    
    if matching_handler
      matching_handler[:handler].call(error, @context)
    end
  end
  
  def method_missing(method_name, *args, &block)
    # Check for transmutation rules first
    matching_rule = @transmutation_rules.find do |pattern, transmuter|
      method_name.to_s.match?(pattern)
    end
    
    if matching_rule
      return matching_rule.last.call(method_name, *args, &block)
    end
    
    # Fall back to context access
    if @context.key?(method_name)
      @context[method_name]
    else
      super
    end
  end
  
  def respond_to_missing?(method_name, include_private = false)
    @context.key?(method_name) || @transmutation_rules.any? { |pattern, _| method_name.to_s.match?(pattern) } || super
  end
end

# Hermetic Delegate - conceptual method forwarding with pattern resonance
class HermeticDelegate
  def initialize(target, pattern_rules = {})
    @target = target
    @pattern_rules = pattern_rules
    @conceptual_bindings = {}
  end
  
  # Bind conceptual pattern to method transformation
  def bind_concept(concept_pattern, &transformer)
    @conceptual_bindings[concept_pattern] = transformer
    self
  end
  
  # Execute method with conceptual understanding
  def execute(method_pattern, *args, &block)
    # Find matching conceptual binding
    concept_binding = @conceptual_bindings.find do |concept_pattern, transformer|
      method_pattern.to_s.match?(concept_pattern)
    end
    
    if concept_binding
      concept_binding.last.call(method_pattern, *args, &block)
    else
      # Fall back to pattern-based method discovery
      discovered_method = discover_method(method_pattern)
      if discovered_method
        @target.send(discovered_method, *args, &block) rescue nil
      else
        nil # Hermetic silence - method not found
      end
    end
  end
  
  private
  
  def discover_method(pattern)
    @target.methods.find do |method|
      method.to_s.match?(pattern) ||
      (@pattern_rules[pattern] && @pattern_rules[pattern].call(method))
    end
  end
  
  def method_missing(method_name, *args, &block)
    execute(method_name, *args, &block)
  end
  
  def respond_to_missing?(method_name, include_private = false)
    true # Hermetic delegates respond to everything conceptually
  end
end

# Symbolic Transmuter - alchemical transformation of code structures
module SymbolicTransmuter
  def self.transmute_structure(structure, &transmutation)
    case structure
    when Hash
      structure.transform_values { |v| transmute_structure(v, &transmutation) }
    when Array
      structure.map { |v| transmute_structure(v, &transmutation) }
    else
      transmutation.call(structure)
    end
  end
  
  def self.create_pattern_based_class(base_class, pattern_rules = {})
    Class.new(base_class) do
      pattern_rules.each do |pattern, implementation|
        define_method(:method_missing) do |method_name, *args, &block|
          if method_name.to_s.match?(pattern)
            implementation.call(method_name, *args, &block)
          else
            super
          end
        end
        
        define_method(:respond_to_missing?) do |method_name, include_private = false|
          method_name.to_s.match?(pattern) || super
        end
      end
    end
  end
end

# String extensions
class String
  # Truncate string to specified length with optional omission
  # @param max_length [Integer] Maximum length of truncated string
  # @param omission [String] String to append when truncated (default: '...')
  # @return [String] Truncated string or original if within limit
  def truncate(max_length, omission = '...')
    return self if length <= max_length
    
    effective_max = max_length - omission.length
    effective_max = 0 if effective_max < 0
    
    self[0...effective_max] + omission
  end
  
  # Check if string is blank (nil, empty, or whitespace only)
  # @return [Boolean] True if string is blank
  def blank?
    self.nil? || self.strip.empty?
  end
  
  # Check if string is present (not blank)
  # @return [Boolean] True if string has content
  def present?
    !blank?
  end
  
  # Convert string to symbol with hermetic cleansing
  # Removes non-alphanumeric characters and converts to snake_case
  # @return [Symbol] Hermetically cleansed symbol
  def to_hermetic_symbol
    gsub(/[^a-zA-Z0-9_]/, '_')
      .gsub(/_+/, '_')
      .gsub(/([a-z])([A-Z])/, '\1_\2')
      .downcase
      .to_sym
  end

  # Hermetic humanization - transforms snake_case and camelCase to human readable form
  # @return [String] Human readable version of the string
  def hermetic_humanize
    gsub(/_/, ' ')
      .gsub(/([a-z])([A-Z])/, '\1 \2')
      .gsub(/\b(\w)/) { $1.upcase }
      .gsub(/\bid\b/i, 'ID')
      .gsub(/\burl\b/i, 'URL')
      .gsub(/\bapi\b/i, 'API')
      .gsub(/\bhtml\b/i, 'HTML')
      .gsub(/\bcss\b/i, 'CSS')
      .gsub(/\bjs\b/i, 'JavaScript')
      .gsub(/\brb\b/i, 'Ruby')
      .gsub(/\bjson\b/i, 'JSON')
      .gsub(/\bxml\b/i, 'XML')
      .gsub(/\byaml\b/i, 'YAML')
      .strip
  end
  
  
  alias_method :humanize, :hermetic_humanize
  

  # Check if string represents a hermetic concept (alphanumeric, underscores only)
  # @return [Boolean] True if string follows hermetic naming conventions
  def hermetic?
    match?(/^[a-zA-Z0-9_]+$/)
  end
end

# Array extensions
class Array
  # Safely access array element with default value
  # @param index [Integer] Index to access
  # @param default [Object] Default value if index out of bounds
  # @return [Object] Element at index or default
  def safe_get(index, default = nil)
    self[index] || default
  end
  
  # Convert array to hash using block to generate keys
  # @yield [element] Block that returns key for each element
  # @return [Hash] Hash with generated keys and array elements as values
  def to_h_with_key
    each_with_object({}) do |element, hash|
      key = yield(element)
      hash[key] = element
    end
  end
  
  # Filter array using hermetic pattern matching
  # @param pattern [Regexp, String] Pattern to match against elements
  # @return [Array] Filtered array of matching elements
  def hermetic_filter(pattern)
    select { |element| element.to_s.match?(pattern) }
  end
  
  # Transform array using hermetic mapping with error handling
  # @yield [element] Block that transforms each element
  # @return [Array] Transformed array with nil values filtered out
  def hermetic_map
    map { |element| yield(element) rescue nil }.compact
  end
end

# Hash extensions
class Hash
  # Deep symbolize keys recursively
  # @return [Hash] Hash with all keys symbolized
  def deep_symbolize_keys
    each_with_object({}) do |(key, value), result|
      symbolized_key = key.respond_to?(:to_sym) ? key.to_sym : key
      result[symbolized_key] = if value.is_a?(Hash)
                                 value.deep_symbolize_keys
                               elsif value.is_a?(Array)
                                 value.map { |v| v.is_a?(Hash) ? v.deep_symbolize_keys : v }
                               else
                                 value
                               end
    end
  end
  
  # Get value with deep key access using dot notation
  # @param path [String] Dot-separated key path (e.g., "user.profile.name")
  # @param default [Object] Default value if path not found
  # @return [Object] Value at path or default
  def dig_path(path, default = nil)
    keys = path.to_s.split('.')
    current = self
    
    keys.each do |key|
      current = if current.is_a?(Hash)
                  current[key.to_sym] || current[key.to_s] || default
                else
                  default
                end
      break if current == default
    end
    
    current
  end
  
  # Filter hash keys using hermetic pattern matching
  # @param pattern [Regexp, String] Pattern to match against keys
  # @return [Hash] Filtered hash with matching keys
  def hermetic_key_filter(pattern)
    select { |key, _| key.to_s.match?(pattern) }
  end
  
  # Transform hash values using hermetic mapping
  # @yield [key, value] Block that transforms each value
  # @return [Hash] Transformed hash
  def hermetic_transform_values
    each_with_object({}) do |(key, value), result|
      result[key] = yield(key, value)
    end
  end
end

# Object extensions
class Object
  # Check if object is present (not nil and responds to empty? or has content)
  # @return [Boolean] True if object has meaningful content
  def present?
    if respond_to?(:empty?)
      !empty?
    else
      !nil?
    end
  end
  
  # Check if object is blank (nil, empty, or false)
  # @return [Boolean] True if object lacks meaningful content
  def blank?
    !present?
  end
  
  # Try to call method, return nil if method doesn't exist or raises error
  # @param method_name [Symbol] Method to call
  # @param args [Array] Arguments to pass to method
  # @return [Object] Method result or nil on error
  def try(method_name, *args)
    return nil unless respond_to?(method_name)
    
    begin
      send(method_name, *args)
    rescue
      nil
    end
  end
  
  # Check if object responds to method with hermetic pattern
  # @param pattern [Regexp] Pattern to match against method names
  # @return [Boolean] True if object has matching method
  def responds_to_pattern?(pattern)
    methods.any? { |method| method.to_s.match?(pattern) }
  end
  
  # Define singleton method with hermetic error handling
  # @param method_name [Symbol] Method name to define
  # @param &block [Proc] Method implementation
  def define_hermetic_method(method_name, &block)
    define_singleton_method(method_name) do |*args|
      begin
        block.call(*args)
      rescue => e
        nil # Hermetic methods return nil on error
      end
    end
  end
end

# NilClass extensions
class NilClass
  # Always blank
  def blank?
    true
  end
  
  # Never present
  def present?
    false
  end
  
  # Try always returns nil
  def try(*_args)
    nil
  end
  
  # Nil responds to all patterns (hermetic acceptance)
  def responds_to_pattern?(_pattern)
    true
  end
end

# Boolean extensions
class TrueClass
  def present?
    true
  end
  
  def blank?
    false
  end
end

class FalseClass
  def present?
    false
  end
  
  def blank?
    true
  end
end

# Module for metaprogramming utilities
module MetaprogrammingUtils
  # Include core extensions in target class/module
  # @param target [Module] Target to include extensions in
  def self.include_core_extensions(target)
    target.include(StringExtensions)
    target.include(ArrayExtensions)
    target.include(HashExtensions)
    target.include(ObjectExtensions)
  end
  
  # Define methods dynamically based on pattern
  # @param target [Module] Target to define methods on
  # @param pattern [Regexp] Pattern to match method names
  # @param &block [Proc] Block to execute for matching methods
  def self.define_pattern_methods(target, pattern, &block)
    target.instance_methods.each do |method|
      if method.to_s.match(pattern)
        target.define_method(method, &block)
      end
    end
  end
  
  # Create hermetic method delegation
  # @param target [Object] Target object to delegate to
  # @param methods [Array<Symbol>] Methods to delegate
  # @param options [Hash] Delegation options
  def self.hermetic_delegate(target, methods, options = {})
    methods.each do |method|
      define_method(method) do |*args, &block|
        target.send(method, *args, &block) rescue nil
      end
    end
  end
  
  # Create memoized hermetic method
  # @param method_name [Symbol] Method name
  # @param &block [Proc] Method implementation
  def self.hermetic_memoize(method_name, &block)
    memoized_var = "@_hermetic_memoized_#{method_name}".to_sym
    
    define_method(method_name) do
      if instance_variable_defined?(memoized_var)
        instance_variable_get(memoized_var)
      else
        value = block.call rescue nil
        instance_variable_set(memoized_var, value)
        value
      end
    end
  end
  
  # Create conditional method based on hermetic pattern
  # @param pattern [Regexp] Pattern to match
  # @param &block [Proc] Method implementation for matching cases
  def self.hermetic_conditional_method(pattern, &block)
    define_method(:method_missing) do |method_name, *args, &method_block|
      if method_name.to_s.match?(pattern)
        block.call(method_name, *args, &method_block)
      else
        super
      end
    end
    
    define_method(:respond_to_missing?) do |method_name, include_private = false|
      method_name.to_s.match?(pattern) || super
    end
  end
end

# Separate modules for better organization
module StringExtensions
  refine String do
    def truncate(max_length, omission = '...')
      return self if length <= max_length
      
      effective_max = max_length - omission.length
      effective_max = 0 if effective_max < 0
      
      self[0...effective_max] + omission
    end
    
    def blank?
      self.nil? || self.strip.empty?
    end
    
    def present?
      !blank?
    end
    
    def to_hermetic_symbol
      gsub(/[^a-zA-Z0-9_]/, '_')
        .gsub(/_+/, '_')
        .gsub(/([a-z])([A-Z])/, '\1_\2')
        .downcase
        .to_sym
    end
    
    def hermetic?
      match?(/^[a-zA-Z0-9_]+$/)
    end
  end
end

module ArrayExtensions
  refine Array do
    def safe_get(index, default = nil)
      self[index] || default
    end
    
    def to_h_with_key
      each_with_object({}) do |element, hash|
        key = yield(element)
        hash[key] = element
      end
    end
    
    def hermetic_filter(pattern)
      select { |element| element.to_s.match?(pattern) }
    end
    
    def hermetic_map
      map { |element| yield(element) rescue nil }.compact
    end
  end
end

module HashExtensions
  refine Hash do
    def deep_symbolize_keys
      each_with_object({}) do |(key, value), result|
        symbolized_key = key.respond_to?(:to_sym) ? key.to_sym : key
        result[symbolized_key] = if value.is_a?(Hash)
                                   value.deep_symbolize_keys
                                 elsif value.is_a?(Array)
                                   value.map { |v| v.is_a?(Hash) ? v.deep_symbolize_keys : v }
                                 else
                                   value
                                 end
      end
    end
    
    def dig_path(path, default = nil)
      keys = path.to_s.split('.')
      current = self
      
      keys.each do |key|
        current = if current.is_a?(Hash)
                    current[key.to_sym] || current[key.to_s] || default
                  else
                    default
                  end
        break if current == default
      end
      
      current
    end
    
    def hermetic_key_filter(pattern)
      select { |key, _| key.to_s.match?(pattern) }
    end
    
    def hermetic_transform_values
      each_with_object({}) do |(key, value), result|
        result[key] = yield(key, value)
      end
    end
  end
end

module ObjectExtensions
  refine Object do
    def present?
      if respond_to?(:empty?)
        !empty?
      else
        !nil?
      end
    end
    
    def blank?
      !present?
    end
    
    def try(method_name, *args)
      return nil unless respond_to?(method_name)
      
      begin
        send(method_name, *args)
      rescue
        nil
      end
    end
    
    def responds_to_pattern?(pattern)
      methods.any? { |method| method.to_s.match?(pattern) }
    end
    
    def define_hermetic_method(method_name, &block)
      define_singleton_method(method_name) do |*args|
        begin
          block.call(*args)
        rescue => e
          nil
        end
      end
    end
  end
end

# Atlantean-Hermetic Higher Order Constructs
# ==========================================

module HermeticConjuration
  # Create a resilient execution domain with automatic error containment
  # @param context_name [Symbol] Name for this execution context
  # @yield [domain] Block executed within the protected domain
  # @return [HermeticDomain] The execution domain
  def self.create_domain(context_name = :default, &block)
    domain = HermeticDomain.new(context_name)
    domain.execute(&block)
    domain
  end
  
  # Define methods based on conceptual patterns rather than explicit names
  # @param pattern [Regexp, Symbol] Pattern to match conceptual intent
  # @param &implementation [Proc] Implementation block
  def self.define_conceptual_method(pattern, &implementation)
    ConceptualMethodRegistry.register(pattern, implementation)
  end
  
  # Transmute object into hermetic delegate with pattern-based forwarding
  # @param target [Object] Object to transmute
  # @param pattern_map [Hash] Pattern-to-method mapping
  # @return [HermeticDelegate] Transmuted delegate
  def self.transmute_to_delegate(target, pattern_map = {})
    HermeticDelegate.new(target, pattern_map)
  end
  
  # Create symbolic binding between concepts and implementations
  # @param concept [Symbol] Hermetic concept to bind
  # @param implementation [Proc] Implementation to bind
  def self.bind_concept(concept, &implementation)
    SymbolicBindingTable.bind(concept, implementation)
  end
  
  # Execute within meta-pattern recognition context
  # @param &block [Proc] Block to execute with pattern awareness
  def self.with_pattern_recognition(&block)
    PatternRecognitionContext.execute(&block)
  end
end

# Resilient execution domain with autonomous error containment
class HermeticDomain
  attr_reader :name, :results, :errors
  
  def initialize(name)
    @name = name.to_sym
    @results = {}
    @errors = {}
    @execution_stack = []
  end
  
  # Execute block within this protected domain
  def execute(&block)
    @execution_stack.push(caller_locations(1,1)[0].to_s)
    
    begin
      result = instance_eval(&block)
      @results[:last] = result
      result
    rescue => e
      error_id = :"error_#{@errors.size + 1}"
      @errors[error_id] = {
        exception: e,
        backtrace: e.backtrace,
        context: @execution_stack.dup
      }
      nil # Hermetic containment - errors don't propagate
    ensure
      @execution_stack.pop
    end
  end
  
  # Define domain-specific methods with automatic error containment
  def define_domain_method(method_name, &implementation)
    define_singleton_method(method_name) do |*args|
      execute { implementation.call(*args) }
    end
  end
  
  # Check if domain execution was successful
  def successful?
    @errors.empty?
  end
  
  # Get all successful results
  def results
    @results.dup
  end
  
  # Get contained errors for analysis
  def contained_errors
    @errors.dup
  end
end

# Hermetic delegate that forwards methods based on conceptual patterns
class HermeticDelegate
  def initialize(target, pattern_map = {})
    @target = target
    @pattern_map = pattern_map
    @conceptual_cache = {}
  end
  
  # Forward method calls based on pattern matching
  def method_missing(method_name, *args, &block)
    # First try exact match
    if @target.respond_to?(method_name)
      return @target.send(method_name, *args, &block)
    end
    
    # Then try pattern-based matching
    matched_method = find_conceptual_method(method_name)
    if matched_method
      return @target.send(matched_method, *args, &block)
    end
    
    # Finally, try symbolic binding
    symbolic_implementation = SymbolicBindingTable.lookup(method_name)
    if symbolic_implementation
      return instance_exec(*args, &symbolic_implementation)
    end
    
    super
  end
  
  def respond_to_missing?(method_name, include_private = false)
    @target.respond_to?(method_name) ||
    find_conceptual_method(method_name) ||
    SymbolicBindingTable.lookup(method_name) ||
    super
  end
  
  private
  
  def find_conceptual_method(method_name)
    return @conceptual_cache[method_name] if @conceptual_cache.key?(method_name)
    
    method_str = method_name.to_s
    
    # Check pattern map first
    @pattern_map.each do |pattern, target_method|
      if method_str.match?(pattern)
        @conceptual_cache[method_name] = target_method
        return target_method
      end
    end
    
    # Then check conceptual registry
    implementation = ConceptualMethodRegistry.find_implementation(method_name)
    if implementation
      @conceptual_cache[method_name] = implementation
      return implementation
    end
    
    @conceptual_cache[method_name] = false
    nil
  end
end

# Registry for conceptual method patterns
module ConceptualMethodRegistry
  @registry = {}
  
  def self.register(pattern, implementation)
    @registry[pattern] = implementation
  end
  
  def self.find_implementation(method_name)
    method_str = method_name.to_s
    
    @registry.each do |pattern, implementation|
      if method_str.match?(pattern)
        return implementation
      end
    end
    
    nil
  end
  
  def self.clear
    @registry.clear
  end
end

# Symbolic binding table for concept-to-implementation mapping
module SymbolicBindingTable
  @bindings = {}
  
  def self.bind(concept, implementation)
    @bindings[concept.to_sym] = implementation
  end
  
  def self.lookup(concept)
    @bindings[concept.to_sym]
  end
  
  def self.bound_concepts
    @bindings.keys
  end
  
  def self.clear
    @bindings.clear
  end
end

# Meta-pattern recognition context
module PatternRecognitionContext
  def self.execute(&block)
    original_verbose = $VERBOSE
    $VERBOSE = nil
    
    begin
      # Enhance method_missing with pattern recognition
      Object.class_eval do
        alias_method :original_method_missing, :method_missing
        
        def method_missing(method_name, *args, &block)
          # Try pattern-based resolution first
          if implementation = ConceptualMethodRegistry.find_implementation(method_name)
            return instance_exec(*args, &implementation)
          end
          
          # Fall back to original
          original_method_missing(method_name, *args, &block)
        end
      end
      
      block.call
    ensure
      # Restore original method_missing
      Object.class_eval do
        alias_method :method_missing, :original_method_missing
      end
      
      $VERBOSE = original_verbose
    end
  end
end

# Make utilities available globally
include MetaprogrammingUtils

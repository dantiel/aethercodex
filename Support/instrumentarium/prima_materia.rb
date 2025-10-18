# frozen_string_literal: true
require_relative '../oracle/oracle'
require_relative '../config'

# Define Boolean type for schema compatibility
Boolean = TrueClass
Number = Numeric

# Prima Materia - The First Matter from which all tools are formed
# Hermetic tool execution system with selective debug logging and argument truncation
class PrimaMateria
  # Tool definition structure
  Tool = Struct.new *%i{name description params returns timeout history_priority implementation}

  def initialize
    @tools = {}
  end

  attr_reader :tools

  def reject(*tool_names)
    # Create a new PrimaMateria instance with filtered tools
    filtered_prima = PrimaMateria.new

    # Add only the tools that are NOT in the reject list
    @tools.each do |name, tool|
      next if tool_names.include? name

      filtered_prima.add_instrument(name,
                                    desc:    tool.description,
                                    params:  tool.params,
                                    returns: tool.returns,
                                    &tool.implementation)
    end

    filtered_prima
  end


  # Merge tools from another PrimaMateria instance (destructive)
  def merge_tools!(other_prima)
    other_prima.tools.each do |name, tool|
      @tools[name] = tool
      # Define the method dynamically for the merged tool
      define_singleton_method name do |*args, **kwargs|
        tool_name = name.to_s
        tool_spec = @tools[name]

        # Convert args to kwargs for validation
        actual_kwargs = args.empty? ? kwargs : {}
        if args.any? && tool_spec.params.keys.any?
          # Map positional args to named parameters
          param_names = tool_spec.params.keys
          args.each_with_index do |arg, index|
            actual_kwargs[param_names[index]] = arg if index < param_names.size
          end
          actual_kwargs.merge! kwargs
        else
          actual_kwargs = kwargs
        end

        # Apply default values
        tool_spec.params.each do |param_name, param_spec|
          unless param_spec.is_a?(Hash) && param_spec.key?(:default) && !actual_kwargs.key?(param_name)
            next
          end

          actual_kwargs[param_name] = param_spec[:default]
        end

        # Validate parameters against tool specification
        validated_kwargs = {}
        tool_spec.params.each do |param_name, param_spec|
          value = actual_kwargs[param_name]

          # Check required parameters
          if param_spec.is_a?(Hash) && param_spec[:required] && !actual_kwargs.key?(param_name)
            raise ArgumentError, "missing required parameter: #{param_name}"
          end

          # Skip validation for missing optional parameters
          next unless actual_kwargs.key? param_name

          # Type validation
          if param_spec.is_a?(Hash) && param_spec[:type]
            validate_type param_name, value, param_spec[:type]
          end

          # Range validation for numbers
          if param_spec.is_a?(Hash) && value.is_a?(Numeric)
            validate_range param_name, value, param_spec
          end

          # String length validation
          if param_spec.is_a?(Hash) && value.is_a?(String)
            validate_string_length param_name, value, param_spec
          end

          # Array validation
          if param_spec.is_a?(Hash) && value.is_a?(Array)
            validate_array param_name, value,
                           param_spec
          end

          # Enum validation
          if param_spec.is_a?(Hash) && param_spec[:enum]
            validate_enum param_name, value, param_spec[:enum]
          end

          validated_kwargs[param_name] = value
        end

        # Validate forbidden parameters from SCHEMA
        schema_entry = schema[tool_name] || schema[tool_aliases.key(tool_name)]
        if schema_entry
          forbidden_params = schema_entry[:forbid].map(&:to_sym)
          forbidden_present = forbidden_params & actual_kwargs.keys
          unless forbidden_present.empty?
            raise ArgumentError, "forbidden parameters present: #{forbidden_present.join ', '}"
          end
        end

        tool_spec.implementation.call(**validated_kwargs)
      end
    end
    self
  end


  # Create a copy of tool definitions for reuse
  def clone_tools
    cloned = PrimaMateria.new
    @tools.each do |name, tool|
      cloned.add_instrument(name,
                            desc:    tool.description,
                            params:  tool.params,
                            returns: tool.returns,
                            &tool.implementation)
    end
    cloned
  end


  # Merge tools from another PrimaMateria instance (non-destructive version)
  def merge_tools(other_prima)
    merged = PrimaMateria.new
    # First add our own tools
    @tools.each do |name, tool|
      merged.add_instrument(name,
                            desc:    tool.description,
                            params:  tool.params,
                            returns: tool.returns,
                            &tool.implementation)
    end
    # Then add tools from the other prima (overwriting if needed)
    other_prima.tools.each do |name, tool|
      merged.add_instrument(name,
                            desc:    tool.description,
                            params:  tool.params,
                            returns: tool.returns,
                            &tool.implementation)
    end
    merged
  end


  # Add instrument with validation schema integration
  def add_instrument(name,
                     desc: '',
                     description: '',
                     params: {},
                     returns: {},
                     timeout: nil,
                     history_priority: 1,
                     &implementation)
    # Use desc parameter if provided, otherwise fall back to description
    tool_description = desc.empty? ? description : desc

    @tools[name] = Tool.new(
      name,
      tool_description,
      params,
      returns,
      timeout,
      history_priority,
      implementation
    )
    # Define the method dynamically with comprehensive validation
    define_singleton_method name do |*args, **kwargs|
      tool_name = name.to_s
      tool_spec = @tools[name]

      # Convert args to kwargs for validation
      actual_kwargs = args.empty? ? kwargs : {}
      if args.any? && tool_spec.params.keys.any?
        # Map positional args to named parameters
        param_names = tool_spec.params.keys
        args.each_with_index do |arg, index|
          actual_kwargs[param_names[index]] = arg if index < param_names.size
        end
        actual_kwargs.merge! kwargs
      else
        actual_kwargs = kwargs
      end

      # Apply default values
      tool_spec.params.each do |param_name, param_spec|
        unless param_spec.is_a?(Hash) && param_spec.key?(:default) && !actual_kwargs.key?(param_name)
          next
        end

        actual_kwargs[param_name] = param_spec[:default]
      end

      # Validate parameters against tool specification
      validated_kwargs = {}
      tool_spec.params.each do |param_name, param_spec|
        value = actual_kwargs[param_name]

        # Check required parameters
        if param_spec.is_a?(Hash) && param_spec[:required] && !actual_kwargs.key?(param_name)
          raise ArgumentError, "missing required parameter: #{param_name}"
        end

        # Skip validation for missing optional parameters
        next unless actual_kwargs.key? param_name

        # Type validation
        if param_spec.is_a?(Hash) && param_spec[:type]
          validate_type param_name, value, param_spec[:type]
        end

        # Range validation for numbers
        if param_spec.is_a?(Hash) && value.is_a?(Numeric)
          validate_range param_name, value, param_spec
        end

        # String length validation
        if param_spec.is_a?(Hash) && value.is_a?(String)
          validate_string_length param_name, value, param_spec
        end

        # Array validation
        validate_array param_name, value, param_spec if param_spec.is_a?(Hash) && value.is_a?(Array)

        # Enum validation
        if param_spec.is_a?(Hash) && param_spec[:enum]
          validate_enum param_name, value, param_spec[:enum]
        end

        validated_kwargs[param_name] = value
      end

      # Validate forbidden parameters from SCHEMA
      schema_entry = schema[tool_name] || schema[tool_aliases.key(tool_name)]
      if schema_entry
        forbidden_params = schema_entry[:forbid].map(&:to_sym)
        forbidden_present = forbidden_params & actual_kwargs.keys
        unless forbidden_present.empty?
          raise ArgumentError, "forbidden parameters present: #{forbidden_present.join ', '}"
        end
      end

      tool_spec.implementation.call(**validated_kwargs)
    end
  end


  # Type validation helper
  # Type validation helper
  def validate_type(param_name, value, expected_type)
    case expected_type.to_s
    when 'String', 'string'
      raise ArgumentError, "#{param_name} must be a String" unless value.is_a? String
    when 'Integer', 'integer'
      raise ArgumentError, "#{param_name} must be an Integer" unless value.is_a? Integer
    when 'Number', 'number', 'Numeric'
      raise ArgumentError, "#{param_name} must be a Number" unless value.is_a? Numeric
    when 'Boolean', 'boolean'
      raise ArgumentError, "#{param_name} must be a Boolean" unless [true, false].include? value
    when 'Array', 'array'
      raise ArgumentError, "#{param_name} must be an Array" unless value.is_a? Array
    when 'Object', 'object', 'Hash'
      raise ArgumentError, "#{param_name} must be an Object/Hash" unless value.is_a? Hash
    end
  end


  # Range validation helper
  def validate_range(param_name, value, param_spec)
    if param_spec[:minimum] && value < param_spec[:minimum]
      raise ArgumentError, "#{param_name} must be >= #{param_spec[:minimum]}"
    end
    return unless param_spec[:maximum] && value > param_spec[:maximum]

    raise ArgumentError, "#{param_name} must be <= #{param_spec[:maximum]}"
  end


  # String length validation helper
  def validate_string_length(param_name, value, param_spec)
    if param_spec[:minLength] && value.length < param_spec[:minLength]
      raise ArgumentError, "#{param_name} must be at least #{param_spec[:minLength]} characters"
    end
    return unless param_spec[:maxLength] && value.length > param_spec[:maxLength]

    raise ArgumentError, "#{param_name} must be at most #{param_spec[:maxLength]} characters"
  end


  # Array validation helper
  def validate_array(param_name, value, param_spec)
    if param_spec[:minItems] && value.size < param_spec[:minItems]
      raise ArgumentError, "#{param_name} must have at least #{param_spec[:minItems]} items"
    end
    if param_spec[:maxItems] && value.size > param_spec[:maxItems]
      raise ArgumentError, "#{param_name} must have at most #{param_spec[:maxItems]} items"
    end

    # Validate array item types if specified
    return unless param_spec[:items] && param_spec[:items][:type]

    value.each_with_index do |item, index|
      validate_type "#{param_name}[#{index}]", item, param_spec[:items][:type]
      # Also validate range constraints for numeric items
      if item.is_a?(Numeric) && param_spec[:items].is_a?(Hash)
        validate_range "#{param_name}[#{index}]", item, param_spec[:items]
      end
    end
  end


  # Enum validation helper
  def validate_enum(param_name, value, enum_values)
    return if enum_values.include? value

    raise ArgumentError, "#{param_name} must be one of: #{enum_values.join ', '}"
  end


  # Generate complete INSTRUMENTA schema matching the static format
  def instrumenta_schema
    schema = []

    @tools.each do |name, tool|
      tool_name = name.to_s

      schema_entry = {
        type:     'function',
        function: {
          name:        tool_name,
          description: tool.description,
          parameters:  {
            type:       'object',
            properties: {},
            required:   []
          }
        }
      }

      # Build properties from tool params
      properties = {}
      tool.params.each do |param_name, param_spec|
        properties[param_name.to_s] = if param_spec.is_a? Hash
                                        param_spec.to_h.except(:required).each_with_object({}) do |(key, value), hash|
                                          hash[key] = case key
                                                      when :type
                                                        case value.to_s
                                                        when 'TrueClass' then 'boolean'
                                                        when 'Numeric' then 'number'
                                                        else value.to_s.downcase
                                                        end
                                                      else
                                                        value
                                                      end
                                        end
                                      else
                                        { type: param_spec.to_s }
                                      end
      end

      schema_entry[:function][:parameters][:properties] = properties
      schema << schema_entry
    end

    # Add aliases as separate entries
    # tool_aliases.each do |alias_name, real_name|
    #   next unless @tools[real_name.to_sym]
    #
    #   schema << {
    #     type:     'function',
    #     function: {
    #       name:        alias_name,
    #       description: @tools[real_name.to_sym].description,
    #       parameters:  schema.find { |s| s[:function][:name] == real_name }[:function][:parameters]
    #     }
    #   }
    # end

    schema
  end


  def schema
    @tools.each_with_object({}) do |(name, tool), schema|
      tool_name = name.to_s

      # Extract required parameters
      required_params = tool.params.select do |_, spec|
        spec.is_a?(Hash) && spec[:required]
      end.keys.map(&:to_sym)

      # Extract forbidden parameters (none by default, can be extended)
      forbidden_params = []

      schema[tool_name] = {
        req:    required_params,
        forbid: forbidden_params
      }
    end
  end


  def tool_aliases
    {
      'readfile'          => 'read_file',
      'patchfile'         => 'patch_file',
      'createfile'        => 'create_file',
      'runcommand'        => 'run_command',
      'renamefile'        => 'rename_file',
      'telluser'          => 'tell_user',
      'oracleconjuration' => 'oracle_conjuration',
      'rejectstep'        => 'reject_step',
      'completestep'      => 'complete_step',
      'recallnotes'       => 'recall_notes',
      'recallhistory'     => 'recall_history',
      'fileoverview'      => 'file_overview',
      'removenote'        => 'remove_note',
      'aegis'             => 'aegis',
      'createtask'        => 'create_task',
      'executetask'       => 'execute_task',
      'updatetask'        => 'update_task',
      'evaluatetask'      => 'evaluate_task',
      'listtasks'         => 'list_tasks',
      'removetask'        => 'remove_task'
    }
  end


  def handle(tool:, args: {}, context: nil, timeout: 120)    
    tool = tool.to_s
    tool = tool_aliases[tool] || tool
    args = symbolize(args || {})

    # Use tool-specific timeout if defined, otherwise fall back to provided timeout or default
    tool_timeout = if args[:timeout]
                     args[:timeout]
                   elsif @tools.key?(tool.to_sym) && @tools[tool.to_sym].timeout
                     @tools[tool.to_sym].timeout
                   else
                     timeout
                   end

    # Log tool execution with truncated arguments to avoid bloat
    truncated_args = args.transform_values { |v| v.to_s.truncate 200 }
    puts "[PRIMA_MATERIA][HANDLE][#{tool.upcase.gsub '_', '_'}]: args: "\
         "#{truncated_args.inspect} (timeout: #{tool_timeout})"

    out = if @tools.key? tool.to_sym
            HermeticExecutionDomain.execute timeout: tool_timeout do
              send(tool.to_sym, **args)
            end
          else
            HorologiumAeternum.system_error("Unknown tool #{tool}")
            { error: "Unknown tool #{tool}" }
          end
  rescue Oracle::StepTerminationException => e
    # Step completion is expected termination - handle differently based on context
    puts "[PRIMA_MATERIA][STEP_COMPLETE]: #{tool}: #{e.message.truncate(100)}"
    
    # For task step completion/rejection tools, return success instead of re-raising
    # This prevents "Hermetic execution failed" errors for expected step termination
    if tool.to_s.include?('task_') || tool.to_s.include?('complete_step') || tool.to_s.include?('reject_step')
      # puts { status: :success, message: e.message }.to_s
      raise e
    else
      # For Oracle context, let it propagate for proper handling
      raise e
    end
  rescue HermeticExecutionDomain::Error => e
    HorologiumAeternum.system_error("Hermetic execution failed for #{tool}", message: e.message.truncate(300))
    out = { error: "Hermetic execution failed for #{tool}: #{e.message.truncate(300)}" }
  rescue ArgumentError => e
    HorologiumAeternum.system_error("Bad args for #{tool}", message: "got: #{args.inspect.truncate 300}")
    out = { error: "Bad args for #{tool}: #{e.message}", got: args }
  rescue StandardError => e
    puts "[PRIMA_MATERIA][ERROR]: #{e.class}: #{e.message.truncate 200}"
    out = {}
  ensure
    truncated_result = out&.transform_values { |v| v.to_s.truncate 300 }
    puts "[PRIMA_MATERIA][HANDLE][#{tool.upcase.gsub '_', '_'}][RESULT]: "\
         "#{truncated_result.inspect}"
  end


  def symbolize(obj)
    case obj
    when Hash  then obj.each_with_object({}) { |(k, v), h| h[k.to_sym] = symbolize v }
    when Array then obj.map { |v| symbolize v }
    else obj
    end
  end


  # Get merged allowed commands (default + custom)
  def self.allowed_commands
    default_commands = ALLOW_CMDS
    custom_commands = CONFIG::allowed_commands
    puts "[PRIMA_MATERIA][ALLOWED_COMMANDS]: #{custom_commands.inspect}"
    # If custom commands include wildcard, allow everything
    return [//] if custom_commands.any? { |re| re == // }
    
    default_commands + custom_commands
  end
  

  ALLOW_CMDS   = [/^rspec\b/, /^rubocop\b/, /^git\b/, /^ls\b/, /^cat\b/, /^mkdir\b/,
                  /^\$TM_QUERY\b/, /^echo\b/, /^grep\b/, /^bundle exec ruby\b/,
                  /^bundle exec irb\b/, /^bundle exec rspec\b/, /^ruby\b/, /^irb\b/, /^cd\b/, 
                  /^curl\b/, /^ag\b/, /^find\b/, /^tail\b/, /^ast-grep\b/, /^which\b/, /^wc\b/,
                  /^oc\b/, /^file\b/, /^hexdump\b/].freeze
  DENY_PATHS   = [/\.aethercodex$/, /\.env$/, %r{\.git/}].freeze
  MAX_DIFF     = 800
  MAX_CMD_TIME = 10
end

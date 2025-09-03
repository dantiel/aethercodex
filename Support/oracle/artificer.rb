# frozen_string_literal: true

# Instrumentator provides hermetic, side-effect-free execution of instrumenta
# with proper message handling and error management. Designed for reuse across the system.
class Artificer
  TOOL_CALLS_ALIASES = {
    'toolcalls'  => 'tool_calls',
    'tools'      => 'tool_calls',
    'tool_name'  => 'name',
    'toolname'   => 'name',
    'args'       => 'arguments',
    'params'     => 'arguments',
    'parameters' => 'arguments'
  }.freeze


  # Exception to signal restart needed
  class RestartException < StandardError; end

  # Exception to signal step completion/rejection - terminates current reasoning
  class StepTerminationException < StandardError; end


  class << self
    # Execute a standard instrumenta call with hermetic principles
    # Returns [result, updated_messages, updated_tool_results]
    def execute_standard(instrumenta_call, messages, instrumenta_results, &execution_block)
      name = extract_instrumenta_name instrumenta_call
      args = extract_instrumenta_arguments instrumenta_call

      log_instrumenta_call 'INSTRUMENTA_CALL', name, args
      safe_context = create_safe_context instrumenta_results

      HermeticExecutionDomain.execute max_retries: 2, timeout: 3000 do
        result = execution_block.call name, args, safe_context
        updated_instrumenta_results = instrumenta_results + [{ id:     instrumenta_call['id'],
                                                               name:   name,
                                                               result: result }]
        updated_messages = messages + [{ role:         'tool',
                                         tool_call_id: instrumenta_call['id'],
                                         content:      result.to_json }]
        [result, updated_messages, updated_instrumenta_results]
      end
    rescue HermeticExecutionDomain::Error => e
      handle_hermetic_execution_error e, 'Hermetic execution failed'
    rescue StepTerminationException => e
      handle_step_termination_error e
    end


    # Execute a fallback instrumenta call with hermetic principles
    # Returns [result, updated_messages, updated_tool_results]
    def execute_fallback(instrumenta_call, messages, instrumenta_results, &execution_block)
      log_instrumenta_call 'FALLBACK_INSTRUMENTA_CALL', instrumenta_call[:name],
                           instrumenta_call[:args]
      safe_context = create_safe_context instrumenta_results

      HermeticExecutionDomain.execute max_retries: 2, timeout: 30 do
        result = execution_block.call instrumenta_call[:name], instrumenta_call[:args],
                                      safe_context
        instrumenta_call_id = instrumenta_call[:id] || SecureRandom.uuid
        updated_instrumenta_results = instrumenta_results + [{ id:     instrumenta_call_id,
                                                               name:   instrumenta_call[:name],
                                                               result: result }]
        updated_messages = messages + [{ role:         'tool',
                                         tool_call_id: instrumenta_call_id,
                                         content:      result.to_json }]
        [result, updated_messages, updated_instrumenta_results]
      end
    rescue HermeticExecutionDomain::Error => e
      handle_hermetic_execution_error e, 'Hermetic execution failed'
    rescue StepTerminationException => e
      handle_step_termination_error e
    end


    # Handle multiple instrumenta calls in sequence with proper message accumulation
    # Returns [results, updated_messages, updated_tool_results]
    def execute_instrumenta_calls(instrumenta_calls,
                                  messages,
                                  instrumenta_results,
                                  &execution_block)
      instrumenta_calls.reduce [[], messages,
                                instrumenta_results] do |(results, current_messages, current_instrumenta_results), instrumenta_call|
        result, new_messages, new_instrumenta_results = execute_standard(instrumenta_call,
                                                                         current_messages, current_instrumenta_results, &execution_block)
        [results + [result], new_messages, new_instrumenta_results]
      end
    end


    # Handle multiple fallback instrumenta calls in sequence
    # Returns [results, updated_messages, updated_tool_results]
    def execute_fallback_instrumenta_calls(instrumenta_calls,
                                           messages,
                                           instrumenta_results,
                                           &execution_block)
      instrumenta_calls.reduce [[], messages,
                                instrumenta_results] do |(results, current_messages, current_instrumenta_results), instrumenta_call|
        result, new_messages, new_instrumenta_results = execute_fallback(instrumenta_call,
                                                                         current_messages, current_instrumenta_results, &execution_block)
        [results + [result], new_messages, new_instrumenta_results]
      end
    end

    def extract_instrumenta_name(instrumenta_call)
      instrumenta_call['name'] || instrumenta_call[:name] ||
        instrumenta_call.dig('function', 'name') || instrumenta_call.dig(:function, :name)
    end


    def extract_instrumenta_arguments(instrumenta_call)
      args = instrumenta_call['arguments'] || instrumenta_call[:arguments] ||
             instrumenta_call.dig('function',
                                  'arguments') || instrumenta_call.dig(:function, :arguments) || {}

      args = ensure_json(args) if args.is_a? String
      args = args.transform_keys(&:to_sym)

      args
    end


    def extract_instrumenta_from_content(text)
      return [] unless text.present?

      jsons = text.scan(/^\s*```json\s*\n(.*?)^\s*```/m)

      jsons.hermetic_map do |json_match|
        json_text = json_match[0]
        obj = parse_json_safely json_text
        extract_instrumenta_from_parsed_object obj
      end.flatten.compact
    end
    

    private
    

    def log_tool_call(type, name, args)
      puts "[ORACLE][#{type}]: #{name} with args: #{args.to_s.truncate 100}"
    rescue StandardError => e
      HorologiumAeternum.system_error "Failed to log tool call: #{e.message.truncate 100}"
    end


    def extract_instrumenta_from_parsed_object(parsed_object)
      if parsed_object['tool_calls']
        parsed_object['tool_calls'].hermetic_map do |tool|
          tool.transform_keys { |key| TOOL_CALLS_ALIASES.safe_get(key) || key }
        end
      elsif parsed_object.keys.any? { |key| TOOL_CALLS_ALIASES.key? key }
        parsed_object.transform_keys { |key| TOOL_CALLS_ALIASES.safe_get(key) || key }
      end
    end


    # Helper methods for JSON parsing
    def parse_json_safely(json_text)
      JSON.parse json_text
    rescue StandardError
      {}
    end

     
    def ensure_json(raw)
      return raw if raw.is_a? Hash

      JSON.parse raw
    rescue JSON::ParserError
      { 'error' => raw.to_s }
    end


    def log_instrumenta_call(type, name, args)
      puts "[INSTRUMENTATOR][#{type}]: #{name} with args: #{args.to_s.truncate 100}"
    end


    def create_safe_context(tool_results)
      { tool_results: tool_results.dup.freeze }
    end


    def handle_hermetic_execution_error(error, message)
      # Don't log here - the error will be caught and handled by the calling context
      raise error
    end


    def handle_step_termination_error(error)
      # Don't log here - the error will be caught and handled by the calling context
      raise error
    end
  end
end
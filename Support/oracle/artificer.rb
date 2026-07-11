# frozen_string_literal: true

require_relative 'error_handler'
require_relative '../instrumentarium/hermetic_execution_domain'

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



  class << self
    # Execute a standard instrumenta call with hermetic principles
    # Returns [result, updated_messages, updated_tool_results]
    def execute_standard(instrumenta_call, messages, instrumenta_results, sink: nil, &execution_block)
      id = instrumenta_call['id']
      name = extract_instrumenta_name instrumenta_call
      args = extract_instrumenta_arguments instrumenta_call

      log_instrumenta_call 'INSTRUMENTA_CALL', name, args
      safe_context = create_safe_context instrumenta_results
      start_time = Time.now
      sink&.send_status 'tool_starting', { name:, args: args.to_s.truncate(120) }#, tool_name: name

      result = HermeticExecutionDomain.execute max_retries: 2, timeout: 86_400 do
        exec_result = execution_block.call name, args, safe_context
        exec_time = Time.now - start_time

        # Check for divine interruption signal - terminate current oracle call if detected
        if exec_result.is_a?(Hash) && exec_result.key?(:__divine_interrupt)
          break [:__divine_interrupt, exec_result, messages, instrumenta_results]
        end

        safe_result = safe_encode exec_result
        sink&.send_status 'tool_completed', { name:, execution_time: exec_time, result: safe_result.to_s.truncate(80) }#, tool_name: name
        updated_instrumenta_results = instrumenta_results + [{ id:, name:, result: safe_result, args:, execution_time: exec_time.round(3) }]
        updated_messages = messages + [{ role:         'tool',
                                         tool_call_id: id,
                                         content:      safe_result.to_json }]
        [exec_result, updated_messages, updated_instrumenta_results]
      end

      # Handle divine interruption signal
      if result.is_a?(Array) && result.first == :__divine_interrupt
        return [result[1], result[2], result[3]]
      end

      result
    rescue HermeticExecutionDomain::Error => e
      handle_hermetic_execution_error e, 'Hermetic execution failed'
    end


    # Execute a fallback instrumenta call with hermetic principles
    # Returns [result, updated_messages, updated_tool_results]
    def execute_fallback(instrumenta_call, messages, instrumenta_results, sink: nil, &execution_block)
      name = instrumenta_call[:name]
      log_instrumenta_call 'FALLBACK_INSTRUMENTA_CALL', name,
                           instrumenta_call[:args]
      safe_context = create_safe_context instrumenta_results
      start_time = Time.now
      sink&.send_status 'tool_starting', { name:, args: instrumenta_call[:args].to_s.truncate(120) }#, tool_name: name

      result = HermeticExecutionDomain.execute max_retries: 2, timeout: 86_400 do
        exec_result = execution_block.call name, instrumenta_call[:args], safe_context
        exec_time = Time.now - start_time

        # Check for divine interruption signal - terminate current oracle call if detected
        if exec_result.is_a?(Hash) && exec_result.key?(:__divine_interrupt)
          break [:__divine_interrupt, exec_result, messages, instrumenta_results]
        end

        safe_result = safe_encode exec_result
        sink&.send_status 'tool_completed', { name:, execution_time: exec_time, result: safe_result.to_s.truncate(80) }#, tool_name: name
        instrumenta_call_id = instrumenta_call[:id] || SecureRandom.uuid
        updated_instrumenta_results = instrumenta_results + [{ id:     instrumenta_call_id,
                                                               name:,
                                                               result: safe_result,
                                                               args:   instrumenta_call[:args],
                                                               execution_time: exec_time.round(3) }]
        updated_messages = messages + [{ role:         'tool',
                                         tool_call_id: instrumenta_call_id,
                                         content:      safe_result.to_json }]
        [exec_result, updated_messages, updated_instrumenta_results]
      end

      # Handle divine interruption signal
      if result.is_a?(Array) && result.first == :__divine_interrupt
        return [result[1], result[2], result[3]]
      end

      result
    rescue HermeticExecutionDomain::Error => e
      handle_hermetic_execution_error e, 'Hermetic execution failed'
    end


    # Handle multiple instrumenta calls in sequence with proper message accumulation
    # Returns [results, updated_messages, updated_tool_results]
    def execute_instrumenta_calls(instrumenta_calls,
                                  messages,
                                  instrumenta_results,
                                  content,
                                  sink: nil,
                                  &exec_call)
      instrumenta_results << { content: }
      instrumenta_calls.reduce [[], messages, instrumenta_results] do
      |(results, current_messages, prev_instrumenta_results), instrumenta_call|
        result, new_messages, new_instrumenta_results =
          execute_standard(instrumenta_call, current_messages, prev_instrumenta_results, sink:, &exec_call)
        [results + [result], new_messages, new_instrumenta_results]
      end
    end


    # Handle multiple fallback instrumenta calls in sequence
    # Returns [results, updated_messages, updated_tool_results]
    def execute_fallback_instrumenta_calls(instrumenta_calls,
                                           messages,
                                           instrumenta_results,
                                           sink: nil,
                                           &execution_block)
      instrumenta_calls.reduce [[], messages,
                                instrumenta_results] do |(results, current_messages, prev_instrumenta_results), instrumenta_call|
        result, new_messages, new_instrumenta_results = execute_fallback(instrumenta_call,
                                                                         current_messages, prev_instrumenta_results, sink:, &execution_block)
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

      clean = clean_json_raw raw
      JSON.parse clean
    rescue JSON::ParserError => e
      repaired = repair_json_quotes(clean) || {}
      return repaired unless repaired.empty?

      log_json_parse_error e, clean
      {}
    end

    def clean_json_raw(raw)
      clean = (raw.respond_to?(:dup) ? raw.dup : raw.to_s)
      clean.force_encoding('UTF-8') if clean.encoding == Encoding::ASCII_8BIT
      clean.valid_encoding? ? clean : clean.scrub
    end

    def log_json_parse_error(error, clean)
      col = error.message[/column (\d+)/, 1]&.to_i
      snippet = col ? clean.to_s[[col - 40, 0].max..col + 40] : clean.to_s.truncate(200)
      HorologiumAeternum.system_error 'Failed to parse tool arguments JSON',
                                      message: "#{error.message.truncate(190)} | near: …#{snippet}…"
    end

    # Repair JSON with unescaped quotes inside string values.
    def repair_json_quotes(json_str)
      return nil unless json_str.is_a?(String) && json_str.start_with?('{')

      fixed = json_str.gsub(/(?<=[^\\])"(?=[^,}\]:\s])/) { '\\"' }
      return nil if fixed == json_str

      JSON.parse fixed
    rescue JSON::ParserError
      nil
    end


    def log_instrumenta_call(type, name, args)
      puts "[INSTRUMENTATOR][#{type}]: #{name} with args: #{args.to_s.truncate 100}"
    end


    def create_safe_context(tool_results)
      { tool_results: tool_results.dup.freeze }
    end


    def handle_hermetic_execution_error(error, _message)
      # Don't log here - the error will be caught and handled by the calling context
      raise error
    end


    # Recursively encode strings to UTF-8, replacing invalid bytes
    def safe_encode(value)
      case value
      when String then value.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
      when Hash   then value.transform_values { |v| safe_encode v }
      when Array  then value.map { |v| safe_encode v }
      else value
      end
    end
  end
end
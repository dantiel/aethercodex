# frozen_string_literal: true

# Support/oracle.rb
require 'faraday'
require 'json'
require 'time'
require 'fileutils'
require_relative 'mnemosyne'
require_relative 'aetherflux'
require_relative 'coniunctio'
require_relative 'metaprogramming_utils'



# Enhanced Oracle with Hermetic Debugging
# This module provides advanced debugging capabilities for the Atlantean Oracle
# Includes patch expansion, error tracking, and astral plane monitoring
# Version: 2.1.0-hermetic
class Oracle
  SYSTEM_PROMPT = File.read "#{__dir__}/aether_codex.system_instructions.md"
  SYSTEM_PROMPT_BRIEFING = <<~BRIEFING
    Focus on autonomous execution: Read files, plan briefly if needed, then chain all required tools
    (e.g., read_file → recall_notes → patch) in one go. Do not seek confirmation—apply changes and
    proceed to verify (e.g., run tests) without pausing. Prioritize precision and action over
    dialogue. !!DONT OUTPUT JSON IN CONTENT!! Do what you have been asked. Just do it.
  BRIEFING
  # Temperature change threshold for restart
  TEMPERATURE_DELTA_THRESHOLD = 0.2
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
    def deep_symbolize(obj)
      case obj
      when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_sym] = deep_symbolize v }
      when Array then obj.map { |v| deep_symbolize v }
      else obj
      end
    end


    def ask(prompt, ctx)
      a, arts, = divination prompt, ctx do |name, args|
        PrimaMateria.handle({ 'tool' => name, 'args' => args })
      end
      [a, arts]
    end


    def divination(prompt, ctx, tools:, max_depth: 80, reasoning: false, msg_uuid: nil, &exec)
      # Capture initial temperature for restart checks
      initial_temperature = (Mnemosyne.aegis[:temperature] || 1.0).to_f

      msgs = base_messages prompt, ctx
      tool_results = []
      arts = { prelude: [] }
      answer = nil
      depth = 0
      execution_context = { tool_results: tool_results }

      # Stream initial status
      if defined? HorologiumAeternum
        sleep 0.1 # Brief pause for UI responsiveness
        HorologiumAeternum.thinking 'Consulting the hermetic oracle...', uuid: msg_uuid
      end

      loop do
        depth += 1

        # Check for temperature change and restart if significant
        current_temperature = (Mnemosyne.aegis[:temperature] || 1.0).to_f
        if TEMPERATURE_DELTA_THRESHOLD < (current_temperature - initial_temperature).abs
          HorologiumAeternum.thinking 'Temperature change detected. Restarting oracle...'
          raise RestartException, 'Temperature change detected. Restarting oracle.'
        end

        body = build_body_with_messages_and_tools msgs,
                                                  tools: tools.instrumenta_schema,
                                                  want_json: false,
                                                  reasoning: reasoning
        raw = post body, if reasoning then 300 else 120 end
        raise StandardError, raw[:error] unless raw.is_a? String || raw[:error].nil?

        json = ensure_json raw
        log_json json: json

        choice = json.dig('choices', 0) || {}
        msg = choice['message'] || {}
        content = msg['content'].to_s
        tcalls = msg['tool_calls'] || []
        arts[:reasoning_content] = msg['reasoning_content'].to_s if msg['reasoning_content']

        assistant_msg = { role: 'assistant', content: content }
        assistant_msg[:tool_calls] = tcalls if tcalls.any?
        msgs << assistant_msg

        arts[:prelude] << content unless content.strip.empty?

        if arts[:reasoning_content]
          HorologiumAeternum.thinking 'Oracle Reasoning',
                                      arts[:reasoning_content]
        end
        sleep 0.1 if defined? HorologiumAeternum

        if tcalls.any?
          if defined?(HorologiumAeternum) && !content.strip.empty?
            HorologiumAeternum.oracle_revelation content
          end

          tcalls.each do |tc|
            execute_standard_tool_call(tc, msgs, tool_results, execution_context, exec)
          end
          # TODO: make an optional 'continue' mechanism e.g. using a button or some repetition recognition, the problem is that by too many tools the context will be full or the ai might be stuck in a loop for some stupid reason.
          break if depth >= max_depth

          next
        end

        # Fallback: JSON in content
        tools_from_content = extract_tool_calls_from_content content

        if tools_from_content.any?
          if defined?(HorologiumAeternum) and !content.strip.empty?
            HorologiumAeternum.oracle_revelation content
          end

          arts[:tools] = tools_from_content

          # Stream plan if available
          if defined?(HorologiumAeternum) && arts[:plan]
            HorologiumAeternum.thinking "Plan: #{arts[:plan].join ' → '}"
          end

          # Pass execution context to tool calls for awareness of previous results
          tools_from_content.each do |tool_call|
            execute_fallback_tool_call(tool_call, msgs, tool_results, execution_context, exec)
          end

          break if depth >= max_depth

          execution_context[:tool_results] = tool_results
          next
        else
          answer = content
          arts.merge! tools: extract_tool_calls_from_content(answer.to_s)
          break
        end
      end

      [answer || '<<empty>>', arts, tool_results]
    rescue Oracle::RestartException => e
      puts "[ORACLE][RESTART_EXCEPTION]: #{e.inspect} passing on"
      raise
    rescue Oracle::StepTerminationException => e
      # Normal termination due to step completion/rejection - return current state
      puts "[ORACLE][STEP_TERMINATION]: #{e.message} - terminating reasoning"
      [answer || '<<step terminated>>', arts, tool_results]
    rescue StandardError => e
      log_json(error: e.message || e, backtrace: e.backtrace, info: e.inspect)
      puts "[ORACLE][DIVINATION][ERROR]: #{e.inspect}"
      response = safe_parse e.message

      if response.empty?
        HorologiumAeternum.server_error e.message
      else
        response = deep_symbolize response
        error_type = case response[:error][:code]
                     when 'invalid_request_error' then 'Invalid Request'
                     else 'Server Error' end
        HorologiumAeternum.server_error response[:error][:message], error_type
      end
      [{ error: e.message || e }, { patch: nil, tasks: nil, tools: [], prelude: [] }, tool_results]
    end

    def execute_standard_tool_call(tc, msgs, tool_results, execution_context, exec)
      name = tc.dig 'function', 'name'
      args = deep_symbolize safe_parse(tc.dig('function', 'arguments'))
      if args[:name] and args[:args]
        name = args[:name]
        args = args[:args]
      end
      begin
        # Create safe context without circular references for standard tool calls
        safe_context = {
          previous_tool_results: tool_results.dup,
          execution_id: execution_context[:execution_id] || SecureRandom.uuid
        }
        enhanced_args = args.merge(context: safe_context) if args.is_a? Hash
        res = exec.call name, enhanced_args || args
        tool_results << { id: tc['id'], name: name, result: res }
        execution_context[:tool_results] = tool_results
        msgs << { role: 'tool', tool_call_id: tc['id'], content: res.to_json }
      rescue Oracle::StepTerminationException => e
        # Step completion/rejection signaled - terminate reasoning immediately
        puts "[ORACLE][STEP_TERMINATION]: #{e.message}"
        raise
      end
    end

    def execute_fallback_tool_call(tool_call, msgs, tool_results, execution_context, exec)
      # Pass execution context to tool calls for awareness of previous results
      # Create safe context without circular references
      safe_context = {
        previous_tool_results: tool_results.dup,
        execution_id: execution_context[:execution_id] || SecureRandom.uuid
      }
      
      # Generate ID for fallback tool calls if missing
      tool_call_id = tool_call[:id] || SecureRandom.uuid
      
      if tool_call[:arguments].is_a? Hash
        enhanced_args = tool_call[:arguments].merge(context: safe_context)
      end
      res = exec.call tool_call[:name], enhanced_args || tool_call[:arguments]
      tool_results << { id: tool_call_id, name: tool_call[:name], result: res }
      msgs << { role: 'tool', tool_call_id: tool_call_id, content: res.to_json }
    rescue Oracle::StepTerminationException => e
      # Step completion/rejection signaled - terminate reasoning immediately
      puts "[ORACLE][STEP_TERMINATION]: #{e.message}"
      raise
    end


    def conjuration(prompt, context, tools:, msg_uuid:, &)
      # Capture initial temperature for restart checks
      initial_temperature = (Mnemosyne.aegis[:temperature] || 1.0).to_f

      # Delegate tool calls to Oracle.reason with the provided block
      answer, arts, tool_results = divination(prompt, context, tools:, reasoning: true, msg_uuid:,
                                              &)

      # Return the structured output
      [answer, arts, tool_results]
    rescue StandardError => e
      # puts e.inspect
      HorologiumAeternum.system_error 'Conjuration failed', e.message
      { error: "Conjuration failed: #{e.message}" }
    end


    def terminate_thread
      Thread.current.kill if Thread.current.alive?
    end

    #
    # def extract_tools_from_content(parsed)
    #   return [] unless parsed.is_a?(Hash) && parsed['tools'].is_a?(Array)
    #
    #   parsed['tools'].map do |t|
    #     { 'tool' => normalize_tool_name(t['tool'] || t[:tool]),
    #       'args' => deep_symbolize(t['args'] || {}) }
    #   end
    # end


    def base_messages(prompt, ctx)
      # INTRODUCE NEW SECONDARY CUSTOM SYSTEM PROMPT AFTER SYSTEMPROMPT FOR EXAMPLE (E.G. VIA PARAMETER)
      [
        { role: 'system', content: SYSTEM_PROMPT },
        *ctx[:history],
        { role: 'system', content: "Context:\n#{ctx[:extra_context].to_json}" },
        { role: 'system', content: SYSTEM_PROMPT_BRIEFING },
        { role: 'system', content: "HERMETIC MANIFEST (Optional project guidance mutable by user and oracle) hermetic.manifest.md:\n#{ctx[:extra_context][:hermetic_manifest]}" },
        { role: 'user', content: prompt }
      ]
    end


    def build_body_with_messages_and_tools(messages, tools: [], want_json: false, reasoning: false)
      cfg = load_cfg

      model, max_tokens =
        if reasoning
          [cfg['reasoning-model'] || 'deepseek-reasoner', 64_000]
        else
          [cfg['model'] || 'deepseek-chat', 8192]
        end

      temperature = (Mnemosyne.aegis[:temperature] || 1.0).to_f
      # if temperature < 0.34
      #   temperature *= 3.333
      # else
      #   temperature += 0.7
      # end
      # temperature = [temperature, 0, 1.7].sort[1]
      puts "USING TEMPERATURE=#{temperature}"

      { model:, messages:, max_tokens:, tools:, temperature: }
    end


    def complete(ctx)
      prompt = "Provide a code completion for the cursor based on context:\n#{ctx[:snippet]}"
      body = build_body prompt, ctx
      raw = post body
      json = ensure_json raw
      log_json json: json
      json.dig('choices', 0, 'message', 'content') || ''
    rescue StandardError => e
      log_json error: e.message, backtrace: e.backtrace
      ''
    end


    def build_body(prompt, ctx)
      cfg = load_cfg
      {
        model:       cfg['model'] || 'reasoning-1',
        messages:    [{ role: 'system', content: SYSTEM_PROMPT },
                      { role: 'user', content: prompt },
                      { role: 'user', content: "Context: #{ctx.to_json}" }],
        # response_format: { type: 'json_object' },
        tools:       Instrumenta.instrumenta_schema,
        max_tokens:  2048,
        temperature: 0.7
      }
    end


    def post(body, timeout = 120)
      # puts "POST body=#{body.inspect} timeout#{timeout}"
      cfg = load_cfg

      key = cfg['api-key'] || ENV.fetch('DEEPSEEK_API_KEY', nil)
      endpoint = cfg['api-url'] || ENV.fetch('DEEPSEEK_API_URL', nil)
      raise 'Missing DeepSeek API key' if key.to_s.strip.empty?

      conn = Faraday.new do |f|
        f.request :json
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end

      resp = conn.post endpoint do |req|
        req.headers['Authorization'] = "Bearer #{key}"
        req.headers['Content-Type'] = 'application/json'
        req.body = body.to_json
        req.options.timeout = timeout
        req.options.open_timeout = timeout / 2
      end

      resp.body
    rescue Faraday::TimeoutError => e
      # Convert timeout to specific error type that can be handled gracefully
      raise Timeout::Error, "API request timed out after #{timeout} seconds: #{e.message}"
    rescue Faraday::ConnectionFailed => e
      raise "Connection Failed: #{e.wrapped_exception}"
    rescue Faraday::UnprocessableEntityError => e
      puts "[POST][ERROR]: #{e.inspect}"
      raise "Unprocessable Entity Error: #{e.response[:body] || e.wrapped_exception}"
    #    { type: 'Unprocessable Entity Error', error: e.response && e.response[:body] }
    rescue Faraday::Error => e
      # { error:  }
      raise (e.response && e.response[:body]) || e.message
    end


    def ensure_json(raw)
      return raw if raw.is_a? Hash

      JSON.parse raw
    rescue JSON::ParserError
      { 'error' => raw.to_s }
    end


    def extract_tool_calls_from_content(text)
      jsons = text.scan(/^\s*```json\s*\n(.*?)^\s*```/m)
      tool_calls = jsons.reduce [] do |tool_calls, json|
        obj = JSON.parse json[0]
        # puts "obj=#{obj.inspect}"
        if obj['tool_calls']
          tool_calls + obj['tool_calls'].map do |tool|
            tool.transform_keys { |key| TOOL_CALLS_ALIASES[key] || key }
          end
        elsif obj.keys.intersect? TOOL_CALLS_ALIASES.keys
          tool_calls << obj.transform_keys { |key| TOOL_CALLS_ALIASES[key] || key }
        else
          tool_calls
        end
      rescue JSON::ParserError => e
        puts "Error parsing artifacts: #{e.message}"
        tool_calls
      end

      deep_symbolize tool_calls
    end


    def safe_parse(str)
      JSON.parse str
    rescue StandardError
      {}
    end


    def log_json(obj)
      logf = File.expand_path '../.tm-ai/limen.log', __dir__
      FileUtils.mkdir_p File.dirname(logf)
      File.open(logf, 'a') { |f| f.puts "#{Time.now.iso8601} #{obj.to_json}" }
    rescue StandardError => e
      warn "log_json failed: #{e.message}"
    end


    def load_cfg
      # TODO: search for .aethercodex also in ~/ and merge files
      path = File.expand_path '.aethercodex', __dir__
      if File.exist? path then YAML.load_file path else {} end
    end
  end
end
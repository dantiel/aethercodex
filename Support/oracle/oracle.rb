# frozen_string_literal: true

require 'time'
require 'fileutils'
require 'timeout'
require 'socket'
require_relative '../instrumentarium/metaprogramming_utils'
require_relative '../instrumentarium/hermetic_execution_domain'
require_relative '../instrumentarium/horologium_aeternum'
require_relative '../mnemosyne/mnemosyne'
require_relative 'conduit'
require_relative 'coniunctio'
require_relative 'artificer'
require_relative 'error_handler'



def log_json(**kwargs)
  if kwargs.key? :json
    puts "[ORACLE][INFO]: #{kwargs[:json].transform_values { |v| v.to_s.truncate 300 }.inspect}"
  else
    # Handle error logging format
    message = '[ORACLE][ERROR]: '
    message += "error: #{kwargs[:error].to_s.truncate 200}" if kwargs[:error]
    if kwargs.key? :backtrace
      message += ", backtrace: #{kwargs[:backtrace].first(3).join(' | ').truncate 200}"
    end
    message += ", info: #{kwargs[:info].to_s.truncate 200}" if kwargs[:info]
    puts message
  end
end



using MetaprogrammingUtils



# Hermetic Oracle for AI-assisted coding with functional purity
class Oracle
  SYSTEM_PROMPT = File.read "#{__dir__}/aether_codex.system_instructions.md"
  REASONING_PROMPT = File.read "#{__dir__}/aether_codex.reasoning_instructions.md"
  SYSTEM_PROMPT_BRIEFING = <<~BRIEFING
    Focus on autonomous execution: Read files, plan briefly if needed, then chain all required tools
    (e.g., read_file → recall_notes → patch) in one go. Do not seek confirmation—apply changes and
    proceed to verify (e.g., run tests) without pausing. Prioritize precision and action over
    dialogue. !!DONT OUTPUT JSON IN CONTENT!! Do what you have been asked. Just do it.
  BRIEFING
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
    # Public API Methods
    def ask(prompt, context)
      divination(prompt, context, tools: nil) do |name, args|
        PrimaMateria.handle(tool: name, args:, context:)
      end
        .then { |a, arts, _| [a, arts] }
    end


    def divination(prompt, ctx, tools: nil, max_depth: 80, reasoning: false, msg_uuid: nil, &exec)
      initial_temperature = initialize_divination_state
      msgs = base_messages prompt, ctx, reasoning
      tool_results = []
      arts = { prelude: [] }

      stream_initial_status msg_uuid

      answer = execute_divination_loop(initial_temperature, msgs, tools, reasoning, tool_results,
                                       arts, max_depth, &exec)

      [answer || '<<empty>>', arts, tool_results]
    rescue Oracle::RestartException => e
      ErrorHandler.handle_restart_exception e
    rescue Oracle::StepTerminationException => e
      ErrorHandler.handle_step_termination_exception e, answer, arts, tool_results
    rescue StandardError => e
      ErrorHandler.handle_divination_error e, tool_results
    end

    private

    def execute_divination_loop(initial_temperature,
                                msgs,
                                tools,
                                reasoning,
                                tool_results,
                                arts,
                                max_depth,
                                &exec)
      answer = nil
      
      puts "[ORACLE][DIVINATION_LOOP]: Reasoning mode: #{reasoning}"
      puts "[ORACLE][DIVINATION_LOOP]: Tools: #{tools.inspect}"

      (1..max_depth).each do |_depth|
        check_temperature_restart initial_temperature

        json = Conduit.generate_ai_response msgs, tools, reasoning
        content, tcalls, arts = Conduit.extract_response_data json, arts
        
        puts "[ORACLE][DIVINATION_LOOP]: Response content: #{content.to_s.truncate(100)}"
        puts "[ORACLE][DIVINATION_LOOP]: Tool calls found: #{tcalls.any?}"

        msgs << (add_assistant_message msgs, content, tcalls)
        arts = collect_prelude_content arts, content
        stream_reasoning_content arts

        # In reasoning mode, we should NOT process tool calls - reasoning models only provide reasoning
        if reasoning
          answer = content
          break
        else
          next if process_tool_calls tcalls, msgs, tool_results, content, exec, arts

          answer = content
          break
        end
      end

      answer
    end


    def process_tool_calls(tcalls, msgs, tool_results, content, exec, arts)
      if tcalls.any?
        new_msgs, new_tool_results = handle_standard_tool_calls tcalls, msgs, tool_results,
                                                                content, exec
        msgs.replace new_msgs
        tool_results.replace new_tool_results
        return true
      end

      # In reasoning mode, skip tool call extraction entirely
      tools_from_content = Artificer.extract_instrumenta_from_content content
      if tools_from_content.any?
        puts "[ORACLE][DEBUG]: Found #{tools_from_content.size} tools in content (fallback mode)"
        new_msgs, new_tool_results = handle_fallback_tool_calls tools_from_content, msgs,
                                                                tool_results, content, exec, arts
        msgs.replace new_msgs
        tool_results.replace new_tool_results
        return true
      end     

      false
    end


    def conjuration(prompt, context, tools: nil, msg_uuid:, &block)
      initial_temperature = (Mnemosyne.aegis[:temperature] || 1.0).to_f
      result = divination(prompt, context, tools:, reasoning: true, msg_uuid:, &block)
      result
    rescue StandardError => e
      error_details = Conduit.extract_deepseek_error_details e
      error_message = error_details[:message] || e.message
      HorologiumAeternum.system_error "Conjuration failed: #{error_message.truncate 100}"
      { error: "Conjuration failed: #{error_message}", details: error_details }
    end

    public :conjuration


    def complete(ctx)
      Conduit.complete ctx
    end


    # Message Construction
    def base_messages(prompt, ctx, reasoning)
      hermetic_manifest = ctx.dig(:extra_context, :hermetic_manifest).to_s
      
      system_prompt = reasoning ? REASONING_PROMPT : SYSTEM_PROMPT
      
      puts "[ORACLE][DEBUG]: Reasoning mode: #{reasoning}"
      puts "[ORACLE][DEBUG]: System prompt length: #{system_prompt.length}"
      puts "[ORACLE][DEBUG]: System prompt preview: #{system_prompt[0..200]}..."
      
      messages = [
        { role: 'system', content: system_prompt },
        *ctx[:history],
        { role: 'user', content: prompt }
      ]
      
      # Only include briefing in non-reasoning mode to avoid conflicting instructions
      unless reasoning
        messages.insert(3, { role: 'system', content: SYSTEM_PROMPT_BRIEFING })
      end
      
      puts "[ORACLE][DEBUG]: Messages being sent:"
      messages.each_with_index do |msg, i|
        puts "[ORACLE][DEBUG]: Message #{i}: role=#{msg[:role]}, content_length=#{msg[:content].to_s.length}"
        if msg[:role] == 'system' && msg[:content].to_s.length > 100
          puts "[ORACLE][DEBUG]: System content preview: #{msg[:content].to_s[0..100]}..."
        end
      end
      
      messages
    end


    def hermetic_manifest_message(manifest)
      'HERMETIC MANIFEST (Optional project guidance mutable by user and oracle) ' \
        "hermetic.manifest.md:\n#{manifest}"
    end


    # Core Divination Flow
    def stream_reasoning_content(arts)
      nil unless arts[:reasoning_content].present? && defined?(HorologiumAeternum)
    rescue StandardError => e
      error_msg = "Failed to stream reasoning content: #{e.message.truncate 100}"
      HorologiumAeternum.system_error error_msg
    end


    def stream_initial_status(msg_uuid)
      return unless defined?(HorologiumAeternum)

      sleep 0.1
      HorologiumAeternum.thinking 'Consulting the hermetic oracle...', uuid: msg_uuid
    end


    def check_temperature_restart(initial_temperature)
      current_temperature = (Mnemosyne.aegis[:temperature] || 1.0).to_f
      return unless TEMPERATURE_DELTA_THRESHOLD < (current_temperature - initial_temperature).abs

      HorologiumAeternum.thinking 'Temperature change detected. Restarting oracle...'
      raise RestartException, 'Temperature change detected. Restarting oracle.'
    end


    def add_assistant_message(_msgs, content, tcalls)
      assistant_msg = { role: 'assistant', content: }
      assistant_msg[:tool_calls] = tcalls if tcalls.present?
      assistant_msg
    rescue StandardError => e
      HorologiumAeternum.system_error "Failed to add assistant message: #{e.message.truncate 100}"
      { role: 'assistant', content: '' }
    end


    def collect_prelude_content(arts, content)
      arts[:prelude] << content if content.present?
      arts
    rescue StandardError => e
      HorologiumAeternum.system_error "Failed to collect prelude content: #{e.message.truncate 100}"
      arts
    end


    def initialize_divination_state
      (Mnemosyne.aegis[:temperature] || 1.0).to_f
    end


    # Tool Call Handling
    def handle_standard_tool_calls(tools_from_content, msgs, tool_results, content, exec)
      if defined?(HorologiumAeternum) && content.present?
        HorologiumAeternum.oracle_revelation content
      end

      results, new_msgs, new_tool_results = Artificer.execute_instrumenta_calls(
        tools_from_content, msgs, tool_results, &exec
      )
      [new_msgs, new_tool_results]
    end


    def handle_fallback_tool_calls(tools_from_content, msgs, tool_results, content, exec, arts)
      if defined?(HorologiumAeternum) && content.present?
        HorologiumAeternum.oracle_revelation content
      end

      arts[:tools] = tools_from_content
      if defined?(HorologiumAeternum) && arts[:plan].present?
        HorologiumAeternum.thinking "Plan: #{arts[:plan].join ' → '}"
      end

      results, new_msgs, new_tool_results = Artificer.execute_fallback_instrumenta_calls(
        tools_from_content, msgs, tool_results, &exec
      )
      [new_msgs, new_tool_results]
    rescue StandardError => e
      error_msg = "Failed to handle fallback tool calls: #{e.message.truncate 100}"
      HorologiumAeternum.system_error error_msg
      [msgs, tool_results]
    end


    # Exception Handling
    def handle_restart_exception(exception)
      HorologiumAeternum.system_error "Restart exception: #{exception.message.truncate 100}"
      raise
    rescue StandardError => e
      error_msg = "Failed to handle restart exception: #{e.message.truncate 100}"
      HorologiumAeternum.system_error error_msg
      raise exception
    end


    def handle_step_termination_exception(exception, answer, arts, tool_results)
      HorologiumAeternum.system_error "Step termination: #{exception.message.truncate 100}"
      [answer || '<<step terminated>>', arts, tool_results]
    end


    def handle_divination_error(exception, tool_results = [])
      log_json(error: exception.message || exception, backtrace: exception.backtrace,
               info: exception.inspect)

      error_details = Conduit.extract_deepseek_error_details exception

      [{ error: error_details[:message] || exception.message, details: error_details },
       { patch: nil, tasks: nil, tools: [], prelude: [] }, tool_results]
    rescue StandardError => e
      [{ error: "Critical error in error handling: #{e.message}" },
       { patch: nil, tasks: nil, tools: [], prelude: [] }, tool_results]
    end


    # Configuration and Utilities
    def load_cfg
      Conduit.load_cfg
    end
  end
end
# frozen_string_literal: true

require 'bundler/setup'
require 'time'
require 'fileutils'
require 'timeout'
require 'socket'
require 'digest'
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
    puts "[ORACLE][INFO]: #{kwargs[:json].transform_values { |v| v.to_s.truncate 500 }.inspect}"
  else
    # Handle error logging format
    message = '[ORACLE][ERROR]: '
    message += "error: #{kwargs[:error].to_s.truncate 600}" if kwargs[:error]
    if kwargs.key? :backtrace
      message += ", backtrace: #{kwargs[:backtrace].first(3).join(' | ').truncate 600}"
    end
    message += ", info: #{kwargs[:info].to_s.truncate 600}" if kwargs[:info]
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

  # Class variables for reminder system
  @@reminder_store = {}
  @@reminder_counter = 0


  class << self
    # Store a reminder to prevent divination exit
    def store_reminder(session_id, reminder_message)
      @@reminder_store[session_id] ||= []
      @@reminder_store[session_id] << {
        id:        @@reminder_counter += 1,
        message:   reminder_message,
        timestamp: Time.now
      }
      # Keep only last 5 reminders per session
      @@reminder_store[session_id] = @@reminder_store[session_id].last 5
    end


    # Get all reminders for a session
    def get_reminders(session_id)
      @@reminder_store[session_id] || []
    end


    # Clear reminders for a session
    def clear_reminders(session_id)
      @@reminder_store.delete session_id
    end


    # Public API Methods
    def ask(prompt, context)
      divination(prompt, context, tools: nil) do |name, args|
        PrimaMateria.handle(tool: name, args:, context:)
      end
        .then { |a, arts, _| [a, arts] }
    end


    def divination(prompt_or_messages,
                   context,
                   tools: nil,
                   max_depth: 180,
                   reasoning: false,
                   msg_uuid: nil,
                   &exec)
      set_temperature = set_temperature_from_context context
      messages = base_messages prompt_or_messages, context, reasoning
      tool_results = []
      arts = { prelude: [] }

      stream_initial_status msg_uuid

      result = execute_divination_loop(messages, tools, reasoning, tool_results, arts, set_temperature,
                                       context[:prevent_termination_reminder], max_depth, &exec)

      # Check if we got a divine interruption signal instead of a regular answer
      if result.is_a?(Hash) && result.key?(:__divine_interrupt)
        # Return the divine interruption signal directly (just the hash, not the array)
        return result
      end

      [result || '<<empty>>', arts, tool_results]
    rescue Oracle::RestartException => e
      raise Oracle::RestartException.new (ErrorHandler.handle_restart_exception e)
    rescue StandardError => e
      ErrorHandler.handle_divination_error e, tool_results
    end


    def execute_divination_loop(messages,
                                tools,
                                reasoning,
                                tool_results,
                                arts,
                                set_temperature,
                                prevent_termination_reminder,
                                max_depth,
                                &exec)
      answer = nil
      reminder = nil

      # puts "[ORACLE][DIVINATION_LOOP]: Reasoning mode: #{reasoning}"
      puts "[ORACLE][DIVINATION_LOOP]: Tools: #{tools.inspect}"

      (1..max_depth).each do |_depth|
        json = Conduit.generate_ai_response [*messages, reminder].compact, tools, reasoning, set_temperature
        content, tcalls, arts = Conduit.extract_response_data json, arts

        puts "[ORACLE][DIVINATION_LOOP]: Full Response content: #{content}"
        # puts "[ORACLE][DIVINATION_LOOP]: Response content: #{content.to_s.truncate(100)}"
        puts "[ORACLE][DIVINATION_LOOP]: Tool calls found: #{tcalls.any?}"

        messages << (add_assistant_message messages, content, tcalls)
        arts = collect_prelude_content arts, content
        stream_reasoning_content arts

        # In reasoning mode, we should NOT process tool calls - reasoning models only provide reasoning
        unless reasoning
          tool_call_result = process_tool_calls tcalls, messages, tool_results, content, exec, arts

          puts "TOOL CALL RESULT: #{tool_call_result.inspect}"
          # Check if tool call returned a divine interruption signal
          if tool_call_result.is_a?(Hash) && tool_call_result.key?(:__divine_interrupt)
            puts '[ORACLE][DIVINATION]: detected divine interrupt'
            # Return the divine interruption signal to terminate the current oracle call
            return tool_call_result
          end

          next if true == tool_call_result

        end
        # Check for prevent_termination_reminder in context - add reminder if present
        if prevent_termination_reminder&.any?
          reminders = prevent_termination_reminder
          reminder = reminders.last
          puts "[ORACLE][DIVINATION]: reminder set: #{reminder}, remaining reminders: #{reminders - 1}"

          if reminder
            prevent_termination_reminder = reminders.drop 1
            next
          end
        end

        answer = content
        break
      end

      answer
    end


    def process_tool_calls(tcalls, messages, tool_results, content, exec, arts)
      if tcalls.any?
        new_messages, new_tool_results, divine_interrupt = handle_standard_tool_calls tcalls, messages, tool_results,
                                                                                  content, exec
        if divine_interrupt
          # Return divine interruption signal to terminate current oracle call
          return divine_interrupt
        end

        messages.replace new_messages
        tool_results.replace new_tool_results
        return true
      end

      # In reasoning mode, skip tool call extraction entirely
      tools_from_content = Artificer.extract_instrumenta_from_content content
      if tools_from_content.any?
        puts "[ORACLE][DEBUG]: Found #{tools_from_content.size} tools in content (fallback mode)"
        new_messages, new_tool_results, divine_interrupt = handle_fallback_tool_calls tools_from_content, messages,
                                                                                  tool_results, content, exec, arts
        if divine_interrupt
          # Return divine interruption signal to terminate current oracle call
          return divine_interrupt
        end

        messages.replace new_messages
        tool_results.replace new_tool_results
        return true
      end

      false
    end


    def conjuration(prompt, context, msg_uuid:, tools: nil, &block)
      set_temperature = set_temperature_from_context context
      result = divination(prompt, context, tools:, reasoning: true, msg_uuid:, &block)
      result
    rescue StandardError => e
      error_details = Conduit.extract_deepseek_error_details e
      error_message = error_details[:message] || e.message
      HorologiumAeternum.system_error "Conjuration failed: #{error_message.truncate 100}"
      { error: "Conjuration failed: #{error_message}", details: error_details }
    end

    public :conjuration


    def complete(context)
      Conduit.complete context
    end


    # Message Construction
    def base_messages(prompt_or_messages, context, reasoning)
      prompt, custom_messages = if prompt_or_messages.is_a? String
                                  [prompt_or_messages, nil]
                                else
                                  [nil, prompt_or_messages]
                                end

      hermetic_manifest = context.dig :extra_context, :hermetic_manifest

      system_prompt = reasoning ? REASONING_PROMPT : SYSTEM_PROMPT

      puts "[ORACLE][DEBUG]: Reasoning mode: #{reasoning}"
      # puts "[ORACLE][DEBUG]: System prompt length: #{system_prompt.length}"
      # puts "[ORACLE][DEBUG]: System prompt preview: #{system_prompt[0..200]}..."

      messages = if custom_messages
                   # For task execution with complete message structure - use it directly
                   puts '[ORACLE][DEBUG]: Using custom message structure for task execution'
                   [
                     { role: 'system', content: system_prompt },
                     hermetic_manifest,
                     *custom_messages
                   ]
                 else
                   # Normal chat: include history and briefing
                   [
                     { role: 'system', content: system_prompt },
                     hermetic_manifest,
                     *context[:history],
                     ({ role: 'system', content: SYSTEM_PROMPT_BRIEFING } unless reasoning),
                     { role: 'user', content: prompt }
                   ]
                 end.compact


      puts '[ORACLE][DEBUG]: Messages being sent:'
      messages.each_with_index do |msg, i|
        puts "[ORACLE][DEBUG]: Message #{i}: role=#{msg[:role]}, " \
             "content_length=#{msg[:content].to_s.length}, " \
             "content=#{msg[:content].to_s.truncate 50}"
      end

      messages
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


    # def check_temperature_restart(initial_temperature)
    #   current_temperature = (Mnemosyne.aegis[:temperature] || 1.0).to_f
    #   return unless TEMPERATURE_DELTA_THRESHOLD < (current_temperature - initial_temperature).abs
    #
    #   HorologiumAeternum.thinking 'Temperature change detected.。.'
    #   # raise RestartException, 'Temperature change detected. Restarting oracle.'
    # end


    def add_assistant_message(_messages, content, tcalls)
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


    def set_temperature_from_context(context = nil)
      # Use temperature from context if provided, otherwise use Aegis temperature
      context_temperature = context&.dig :extra_context, :temperature
      context_temperature.to_f if context_temperature
      # context_temperature || (Mnemosyne.aegis[:temperature] || 1.0).to_f
    end


    # Tool Call Handling
    def handle_standard_tool_calls(tools_from_content, messages, tool_results, content, exec)
      if defined?(HorologiumAeternum) && content.present?
        HorologiumAeternum.oracle_revelation content
      end

      results, new_messages, new_tool_results = Artificer.execute_instrumenta_calls(
        tools_from_content, messages, tool_results, &exec
      )

      # Check for divine interruption in results - return signal directly
      divine_interrupt = divine_interruption_signal_from_tool_result results
      return [new_messages, new_tool_results, divine_interrupt] if divine_interrupt

      [new_messages, new_tool_results, nil]
    end

    private

    # Generate a unique session ID based on context
    def generate_session_id(context)
      # Use task_id if available, otherwise create hash of context
      task_id = context.dig :extra_context, :task_context, :task_id
      return "task_#{task_id}" if task_id

      # Fallback: hash of relevant context elements
      context_hash = Digest::MD5.hexdigest [
        context.dig(:extra_context, :file),
        context.dig(:extra_context, :selection),
        Time.now.to_i / 60 # Round to nearest minute
      ].compact.join('|')
      "session_#{context_hash}"
    end


    def handle_fallback_tool_calls(tools_from_content, messages, tool_results, content, exec, arts)
      if defined?(HorologiumAeternum) && content.present?
        HorologiumAeternum.oracle_revelation content
      end

      arts[:tools] = tools_from_content
      if defined?(HorologiumAeternum) && arts[:plan].present?
        HorologiumAeternum.thinking "Plan: #{arts[:plan].join ' → '}"
      end

      results, new_messages, new_tool_results = Artificer.execute_fallback_instrumenta_calls(
        tools_from_content, messages, tool_results, &exec
      )

      # Check for divine interruption in results - return signal directly
      divine_interrupt = divine_interruption_signal_from_tool_result results
      
      # puts "DIVINE_INTERRUPTION_SIGNAL_FROM_TOOL_RESULT=#{divine_interrupt.inspect}"
      return [new_messages, new_tool_results, divine_interrupt] if divine_interrupt

      [new_messages, new_tool_results, nil]
    rescue StandardError => e
      error_msg = "Failed to handle fallback tool calls: #{e.message.truncate 100}"
      HorologiumAeternum.system_error error_msg
      [messages, tool_results]
    end


    def handle_step_termination_exception(exception, answer, arts, tool_results)
      HorologiumAeternum.system_error "Step termination: #{exception.message.truncate 100}"
      [answer || '<<step terminated>>', arts, tool_results]
    end


    # Extract divine interruption signal from tool execution results
    def divine_interruption_signal_from_tool_result(results)
      # puts "divine_interruption_signal_from_tool_result #{results.inspect}"
      return nil unless results.is_a? Array

      results.find do |result|
        result.is_a?(Hash) &&
          result.key?(:__divine_interrupt)
      end
    end

    public :divine_interruption_signal_from_tool_result




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

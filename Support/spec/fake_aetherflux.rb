# frozen_string_literal: true

# Fake Aetherflux for testing - simulates oracle conjuration without API calls
class FakeAetherflux
  def initialize
    @responses = {}
    @default_response = { status: :success, response: "Simulated oracle response" }
    @conjuration_count = 0
    @capture_mode = false
    @captured_conjurations = []
    @task_states = {}  # Track task states for side effects
  end

  # Enable capture mode to store conjuration parameters
  def set_capture_mode(enabled = true)
    @capture_mode = enabled
    @captured_conjurations.clear if enabled
  end

  # Get captured conjuration parameters
  def captured_conjurations
    @captured_conjurations.dup
  end

  # Clear captured conjurations
  def clear_captured_conjurations
    @captured_conjurations.clear
  end

  # Configure responses for specific prompts
  def configure_response(prompt_pattern, response)
    @responses[prompt_pattern] = response
  end

  # Set default response for all conjurations
  def set_default_response(response)
    @default_response = response
  end

  # Simulate oracle conjuration with opus_instrumenta side effects
  def channel_oracle_conjuration(params, tools: nil, context: nil)
    prompt = if params[:messages]
               # Extract content from messages for pattern matching
               messages_content = params[:messages].map { |msg| msg[:content] }.join("\n")
               "MESSAGES_MODE: #{messages_content}"
             else
               params[:prompt]
             end
    system_prompt = params[:system]
    
    # Capture conjuration parameters if in capture mode
    if @capture_mode
      @captured_conjurations << {
        prompt: prompt,
        system: system_prompt,
        tools: tools,
        context: context,
        has_messages: params[:messages].present?
      }
    end
    
    # Find matching response or use default
    response = find_matching_response(prompt) || @default_response
    
    # If response is a proc/lambda, call it
    if response.respond_to?(:call)
      response = response.call
    end
    
    # Process tool calls for side effects (mimics opus_instrumenta.rb behavior)
    # This must happen BEFORE returning the response to intercept tool calls
    if response[:response] && response[:response].is_a?(String)
      tool_response = process_tool_calls(response[:response], context)
      response = tool_response if tool_response
    end
    
    @conjuration_count += 1
    
    # Log for debugging
    if ENV['DEBUG_TASK_ENGINE']
      puts "\n=== FAKE AETHERFLUX CONJURATION (#{@conjuration_count}/100) ==="
      puts "PROMPT LENGTH: #{prompt&.length || 0} chars"
      puts "SYSTEM LENGTH: #{system_prompt&.length || 0} chars"
      puts "TOOLS COUNT: #{tools.respond_to?(:size) ? tools.size : 'N/A'}"
      puts "CONTEXT KEYS: #{context&.keys&.join(', ')}" if context
      puts "RESPONSE STATUS: #{response[:status]}"
      puts "RESPONSE LENGTH: #{response[:response]&.length || 0} chars"
      puts "=============================================="
    end
    
    response
  end

  # Simulate oracle divination (same as conjuration for testing purposes)
  def channel_oracle_divination(params, tools: nil, context: nil, **)
    channel_oracle_conjuration(params, tools: tools, context: context)
  end

  # Process tool calls for side effects (mimics opus_instrumenta.rb)
  def process_tool_calls(response_text, context)
    # Extract task_id and step from context for side effects
    task_id = context&.[](:task_id)
    step = context&.[](:step_index)  # Use step_index from context
    
    return unless task_id && step
    
    # Initialize task state tracking
    @task_states[task_id] ||= { current_step: 0, completed_steps: [] }
    
    # Check for task_complete_step tool call (must include parentheses)
    if response_text.include?('task_complete_step()') || response_text.include?('complete_step()')
      @task_states[task_id][:completed_steps] << step
      @task_states[task_id][:current_step] = step + 1
      
      # Modify the response to indicate tool call was processed
      # This allows the engine to handle it appropriately
      return { status: :success, response: response_text, tool_call_processed: :complete_step }
    end
    
    # Check for task_reject_step tool call (must include parentheses)
    if response_text.include?('task_reject_step(') || response_text.include?('reject_step(')
      # Extract target step from tool call if specified
      target_step_match = response_text.match(/target_step[\s:]*([0-9]+)/)
      target_step = target_step_match ? target_step_match[1].to_i : (step - 1)
      
      @task_states[task_id][:current_step] = target_step
      
      # Modify the response to indicate tool call was processed
      return { status: :success, response: response_text, tool_call_processed: :reject_step, target_step: target_step }
    end
    
    # Return original response if no tool calls were processed
    nil
  end

  # Get current task state for testing
  def task_state(task_id)
    @task_states[task_id] || { current_step: 0, completed_steps: [] }
  end

  # Clear task state for testing
  def clear_task_state(task_id)
    @task_states.delete(task_id)
  end

  private

  def find_matching_response(prompt)
        # First check for reminder patterns (highest priority)
        if prompt.is_a?(String) && prompt.include?("PREVENT TERMINATION REMINDER")
          @responses.each do |pattern, response|
            if pattern.is_a?(String) && pattern.include?("PREVENT TERMINATION REMINDER")
              return response
            end
          end
        end
    
    # Then check all other patterns
    @responses.each do |pattern, response|
      # Check if pattern is a string and prompt includes it
      if pattern.is_a?(String) && prompt.include?(pattern)
        return response
      # Check if pattern is a regex and matches prompt
      elsif pattern.is_a?(Regexp) && prompt.match?(pattern)
        return response
      end
      
      # Special handling for MESSAGES_MODE - check if pattern is contained within the message content
      if prompt.start_with?("MESSAGES_MODE:") && pattern.is_a?(String)
        message_content = prompt["MESSAGES_MODE:".length..-1]
        if message_content.downcase.include?(pattern.downcase)
          return response
        end
      end
    end
    
    # If no pattern matches, check if we have a default response for messages mode
    if prompt == "MESSAGES_MODE"
      # Try to find a response for any step pattern
      @responses.each do |pattern, response|
        if pattern.is_a?(String) && pattern.include?("STEP:")
          return response
        end
      end
      
      # Also try to find response for "CURRENT STEP: " patterns
      @responses.each do |pattern, response|
        if pattern.is_a?(String) && pattern.include?("CURRENT STEP:")
          return response
        end
      end
    end
    
    nil
  end
end

# Exceptions for tool-based workflow control (mimics opus_instrumenta.rb)
class StepCompleted < StandardError
  attr_reader :step, :message
  
  def initialize(step, message)
    @step = step
    @message = message
    super(message)
  end
end

class StepRejected < StandardError
  attr_reader :current_step, :target_step, :message
  
  def initialize(current_step, target_step, message)
    @current_step = current_step
    @target_step = target_step
    @message = message
    super(message)
  end
end
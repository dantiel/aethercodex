# frozen_string_literal: true

# Fake Aetherflux for testing - simulates oracle conjuration without API calls
class FakeAetherflux
  def initialize
    @responses = {}
    @default_response = { status: :success, response: "Simulated oracle response" }
    @conjuration_count = 0
    @capture_mode = false
    @captured_conjurations = []
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

  # Simulate oracle conjuration
  def channel_oracle_conjuration(params, tools: nil, context: nil)
    prompt = params[:prompt]
    system_prompt = params[:system]
    
    # Capture conjuration parameters if in capture mode
    if @capture_mode
      @captured_conjurations << {
        prompt: prompt,
        system: system_prompt,
        tools: tools,
        context: context
      }
    end
    
    # Find matching response or use default
    response = find_matching_response(prompt) || @default_response
    
    # If response is a proc/lambda, call it
    if response.respond_to?(:call)
      response = response.call
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

  private

  def find_matching_response(prompt)
    @responses.each do |pattern, response|
      # Check if pattern is a string and prompt includes it
      if pattern.is_a?(String) && prompt.include?(pattern)
        return response
      # Check if pattern is a regex and matches prompt
      elsif pattern.is_a?(Regexp) && prompt.match?(pattern)
        return response
      end
    end
    nil
  end
end
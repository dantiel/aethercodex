# frozen_string_literal: true

# Fake Aetherflux for testing MagnumOpusEngine — simulates oracle with divine interruption support
class FakeAetherflux
  attr_reader :captured_conjurations, :conjuration_count

  def initialize
    @responses = {}
    @default_response = { status: :success, response: 'Simulated oracle response' }
    @conjuration_count = 0
    @capture_mode = false
    @captured_conjurations = []
  end

  # ── Configuration ──────────────────────────────────────────

  def set_capture_mode(enabled = true)
    @capture_mode = enabled
    @captured_conjurations.clear if enabled
  end

  def clear_captured_conjurations
    @captured_conjurations.clear
  end

  def configure_response(prompt_pattern, response)
    @responses[prompt_pattern] = response
  end

  def set_default_response(response)
    @default_response = response
  end

  # ── Main oracle interface ──────────────────────────────────

  # Returns [response_hash, arts, tool_results] — 3-element array matching real Aetherflux
  def channel_oracle_divination(params, tools: nil, context: nil, timeout: nil)
    prompt = extract_prompt(params)
    system_prompt = params[:system_prompt] || params[:system]

    capture(params, tools, context) if @capture_mode

    response = resolve_response(prompt)

    # Run the proc/lambda if the response is callable
    if response.respond_to?(:call)
      begin
        response = response.call
      rescue StandardError => e
        # Simulate error response format
        return [{ status: :network_error, response: e.message }, nil, []]
      end
    end

    @conjuration_count += 1

    # Process divine interruption signals from tool calls embedded in response text
    response = process_divine_interruptions(response, context)

    # Return [response, arts=nil, tool_results=[]]
    [response, nil, extract_tool_results(response)]
  end

  # Compatibility alias
  def channel_oracle_conjuration(params, tools: nil, context: nil, **)
    channel_oracle_divination(params, tools: tools, context: context)
  end

  # ── Divine interruption simulation ─────────────────────────

  private

  def process_divine_interruptions(response, context)
    return response unless response.is_a?(Hash) && response[:response].is_a?(String)
    return response unless context

    text = response[:response]

    # Simulate task_complete_step() — returns __divine_interrupt signal
    if text.match?(/task_complete_step\s*\(/)
      result = if (m = text.match(/task_complete_step\s*\(\s*(?:result:\s*)?["']?(.+?)["']?\s*\)/))
                 m[1]
               else
                 text
               end
      return { __divine_interrupt: :step_completed, result: result }
    end

    # Simulate task_reject_step(reason, restart_from_step)
    if text.match?(/task_reject_step\s*\(/)
      reason = if (m = text.match(/reason:\s*["'](.+?)["']/))
                 m[1]
               elsif (m = text.match(/reason:\s*(.+?)(?:,|\)|\z)/))
                 m[1].strip
               else
                 text
               end
      restart_from = if (m = text.match(/restart_from_step:\s*(\d+)/))
                       m[1].to_i
                     end
      return { __divine_interrupt: :step_rejected, reason: reason, restart_from_step: restart_from }
    end

    response
  end

  def extract_tool_results(response)
    return [] unless response.is_a?(Hash) && response[:__divine_interrupt]
    [{ name: response[:__divine_interrupt].to_s, result: response.inspect }]
  end

  def extract_prompt(params)
    if params[:messages]
      params[:messages].map { |msg| msg[:content] }.join("\n")
    else
      params[:prompt].to_s
    end
  end

  def capture(params, tools, context)
    @captured_conjurations << {
      prompt: extract_prompt(params),
      system: params[:system_prompt] || params[:system],
      tools: tools,
      context: context,
      original_params: params.dup
    }
  end

  def resolve_response(prompt)
    # Check configured patterns
    @responses.each do |pattern, response|
      return response if pattern.is_a?(String) && prompt.include?(pattern)
      return response if pattern.is_a?(Regexp) && prompt.match?(pattern)
    end
    @default_response
  end
end

# Backward compatibility — these were used by older tests
class StepCompleted < StandardError
  attr_reader :step, :message
  def initialize(step, message = nil)
    @step = step
    @message = message
    super(message || "Step #{step} completed")
  end
end

class StepRejected < StandardError
  attr_reader :current_step, :target_step, :message
  def initialize(current_step, target_step, message = nil)
    @current_step = current_step
    @target_step = target_step
    @message = message
    super(message || "Step #{current_step} rejected, returning to step #{target_step}")
  end
end
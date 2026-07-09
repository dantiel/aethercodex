# frozen_string_literal: true

# Conduit Anthropic Helper - Extended functions for Anthropic API compatibility
# Handles message format conversion and tool schema rewriting for Claude models
module ConduitAnthropicHelper
  # Anthropic beta header for extended features
  ANTHROPIC_BETA_HEADERS = {
    'anthropic-beta' => 'max-tokens-3-5-sonnet-2024-07-15'
  }.freeze

  # Anthropic version compatibility
  ANTHROPIC_VERSION = '2023-06-01'

  extend self

  # Build Anthropic-compatible request body
  # Anthropic uses:
  # - messages array (no system messages in the array)
  # - separate top-level system parameter
  # - tool schema uses input_schema instead of parameters
  # - max_tokens is required
  def build_anthropic_messages(messages)
    system_instruction = nil
    anthropic_messages = messages.map do |msg|
      if msg[:role] == 'system'
        system_instruction = msg[:content]
        nil
      elsif msg[:role] == 'tool'
        # Anthropic uses tool_result role or nested in user message
        {
          role: 'user',
          content: [{
            type: 'tool_result',
            tool_use_id: msg[:tool_call_id],
            content: msg[:content]
          }]
        }
      elsif msg[:role] == 'assistant' && msg[:tool_calls]
        # Create content blocks including tool_use
        content_blocks = [{ type: 'text', text: msg[:content] || '' }]
        msg[:tool_calls].each do |tc|
          content_blocks << {
            type: 'tool_use',
            id: tc[:id],
            name: tc.dig(:function, :name),
            input: JSON.parse(tc.dig(:function, :arguments) || '{}')
          }
        rescue JSON::ParserError
          content_blocks << {
            type: 'tool_use',
            id: tc[:id],
            name: tc.dig(:function, :name),
            input: {}
          }
        end
        { role: 'assistant', content: content_blocks }
      elsif msg[:content].is_a?(String)
        { role: msg[:role], content: [{ type: 'text', text: msg[:content] }] }
      else
        msg
      end
    end.compact

    [anthropic_messages, system_instruction]
  end

  # Rewrite tools to Anthropic format
  # Uses input_schema instead of parameters
  def rewrite_tools_to_anthropic_format(tools)
    return nil if tools.nil? || tools.empty?

    tools.map do |tool|
      func = tool[:function] || tool
      {
        name: func[:name],
        description: func[:description],
        input_schema: func[:parameters] || { type: 'object', properties: {} }
      }
    end
  end

  # Build complete Anthropic request body
  def build_anthropic_body(model, messages, tools, temperature, system_instruction, max_tokens = 4096)
    anthropic_messages, extracted_system = build_anthropic_messages(messages)
    system = system_instruction || extracted_system
    anthropic_tools = rewrite_tools_to_anthropic_format(tools)

    body = {
      model: model,
      messages: anthropic_messages,
      max_tokens: max_tokens,
      temperature: temperature
    }

    body[:system] = system if system && !system.to_s.empty?
    body[:tools] = anthropic_tools if anthropic_tools && !anthropic_tools.empty?

    body
  end

  # Convert Anthropic response to OpenAI format
  def parse_anthropic_response_to_openai_format(response)
    return nil unless response[:content]

    content_parts = []
    tool_calls = []

    response[:content].each do |block|
      case block[:type]
      when 'text'
        content_parts << block[:text]
      when 'tool_use'
        tool_calls << {
          id: block[:id],
          type: 'function',
          function: {
            name: block[:name],
            arguments: block[:input].to_json
          }
        }
      end
    end

    openai_response = {
      id: response[:id],
      model: response[:model],
      choices: [{
        index: 0,
        message: {
          role: 'assistant',
          content: content_parts.join
        },
        finish_reason: response[:stop_reason] == 'tool_use' ? 'tool_calls' : 'stop'
      }]
    }

    openai_response[:choices][0][:message][:tool_calls] = tool_calls unless tool_calls.empty?
    openai_response
  end
end

# Extend Conduit class with Anthropic support methods
class Conduit
  extend ConduitAnthropicHelper
end

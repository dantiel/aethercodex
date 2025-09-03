# frozen_string_literal: true

# Message Processor for handling message construction and processing
class MessageProcessor
  SYSTEM_PROMPT = File.read "#{__dir__}/aether_codex.system_instructions.md"
  SYSTEM_PROMPT_BRIEFING = <<~BRIEFING
    Focus on autonomous execution: Read files, plan briefly if needed, then chain all required tools
    (e.g., read_file → recall_notes → patch) in one go. Do not seek confirmation—apply changes and
    proceed to verify (e.g., run tests) without pausing. Prioritize precision and action over
    dialogue. !!DONT OUTPUT JSON IN CONTENT!! Do what you have been asked. Just do it.
  BRIEFING

  class << self
    def base_messages(prompt, ctx)
      [
        { role: 'system', content: SYSTEM_PROMPT },
        *ctx[:history],
        { role: 'system', content: "Context:\n#{ctx[:extra_context].to_json}" },
        { role: 'system', content: SYSTEM_PROMPT_BRIEFING },
        { role:    'system',
          content: 'HERMETIC MANIFEST (Optional project guidance mutable by user and oracle) ' \
                   "hermetic.manifest.md:\n" + ctx[:extra_context][:hermetic_manifest].to_s },
        { role: 'user', content: prompt }
      ]
    end

    def add_assistant_message(messages, content, tool_calls)
      message = { role: 'assistant', content: }
      message[:tool_calls] = tool_calls if tool_calls.any?
      messages << message
    end

    def collect_prelude_content(arts, content)
      arts[:prelude] << content if content.present? && !content.strip.empty?
      arts
    end

    def extract_response_data(json, arts)
      choice = json.dig('choices', 0) || json.dig(:choices, 0) || {}
      message = choice['message'] || choice[:message] || {}

      content = message['content'] || message[:content] || ''
      tool_calls = message['tool_calls'] || message[:tool_calls] || []

      arts = arts.merge(
        reasoning: content,
        tool_calls: tool_calls
      )

      [content, tool_calls, arts]
    end

    def extract_tool_calls_from_content(text)
      return [] unless text.present?

      jsons = text.scan(/^\s*```json\s*\n(.*?)^\s*```/m)

      jsons.hermetic_map do |json_match|
        json_text = json_match[0]
        obj = parse_json_safely(json_text)
        extract_tools_from_parsed_object(obj)
      end.flatten.compact
    end

    def parse_json_safely(json_text)
      JSON.parse(json_text)
    rescue StandardError
      {}
    end

    def extract_tools_from_parsed_object(obj)
      return [] unless obj.is_a?(Hash)

      tool_calls = obj['tool_calls'] || obj[:tool_calls] ||
                   obj['tools'] || obj[:tools] || []

      tool_calls.map do |tool_call|
        next unless tool_call.is_a?(Hash)

        name = tool_call['name'] || tool_call[:name] ||
               tool_call.dig('function', 'name') || tool_call.dig(:function, :name)

        args = tool_call['arguments'] || tool_call[:arguments] ||
               tool_call.dig('function', 'arguments') || tool_call.dig(:function, :arguments) || {}

        next unless name

        { name:, args: }
      end.compact
    end

    def ensure_json(raw)
      return raw if raw.is_a?(Hash)

      JSON.parse(raw)
    rescue JSON::ParserError
      { 'error' => raw.to_s }
    end
  end
end
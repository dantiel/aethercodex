# frozen_string_literal: true

require 'faraday'
require 'json'
require 'tiktoken_ruby'
require 'yaml'
require_relative '../instrumentarium/horologium_aeternum'
require_relative '../instrumentarium/metaprogramming_utils'
require_relative '../instrumentarium/scriptorium'
require_relative '../mnemosyne/mnemosyne'
require_relative 'error_handler'
require_relative 'conduit_anthropic_helper'
using TokenExtensions


# Conduit - Hermetic conduit for DeepSeek API communication
# Channels cosmic energies through the digital aether for oracle divination
class Conduit
  @tokenizer = Tiktoken.encoding_for_model 'gpt-4'
  
  class << self
    THINKING_LEVELS = %w[max high normal fast].freeze

    def select_model(config, reasoning)
      case Mnemosyne.aegis[:thinking]
      when 'fast' then config[:fast_model] || 'deepseek-flash'
      when 'max', 'high', 'normal'
        config[:model] || 'deepseek-chat'
      else
        # nil or unknown — legacy fallback
        if reasoning
          rm = config[:reasoning_model]
          rm == true ? (config[:model] || 'deepseek-chat') : (rm || 'deepseek-reasoner')
        else
          config[:model] || 'deepseek-chat'
        end
      end
    rescue StandardError => e
      HorologiumAeternum.system_error "Failed to select model: #{e.message.truncate 100}"
      'deepseek-chat'
    end


    def use_thinking_mode?(_config, _reasoning)
      THINKING_LEVELS.take(3).include?(Mnemosyne.aegis[:thinking])
    end


    def reasoning_effort_from_aegis
      case Mnemosyne.aegis[:thinking]
      when 'max' then 'max'
      when 'high' then 'high'
      else nil # normal → API default; fast → n/a
      end
    end


    def is_deepseek_reasoning_model?(model_name)
      model_name.to_s.downcase.include?('reason') ||
        model_name.to_s.downcase.include?('deepseek-reasoner')
    rescue StandardError => e
      HorologiumAeternum.system_error "Failed to detect reasoning model: #{e.message.truncate 100}"
      false
    end


    def select_max_tokens(reasoning)
      reasoning ? 64_000 : 8192
    rescue StandardError => e
      HorologiumAeternum.system_error "Failed to select max tokens: #{e.message.truncate 100}"
      8192
    end


    def extract_api_key(config)
      config[:api_key] || ENV.fetch('DEEPSEEK_API_KEY', nil)
    rescue StandardError => e
      HorologiumAeternum.system_error "Failed to extract API key: #{e.message.truncate 100}"
      nil
    end


    def extract_api_endpoint(config)
      config[:api_url] || ENV.fetch('DEEPSEEK_API_URL', nil)
    rescue StandardError => e
      HorologiumAeternum.system_error "Failed to extract API endpoint: #{e.message.truncate 100}"
      'https://api.deepseek.com/v1/chat/completions'
    end


    def validate_api_key(key)
      raise 'Missing DeepSeek API key' if key.to_s.strip.empty?
    rescue StandardError => e
      HorologiumAeternum.system_error "Failed to validate API key: #{e.message.truncate 100}"
      raise e
    end


    def ensure_json(raw)
      return raw if raw.is_a? Hash

      JSON.parse raw
    rescue JSON::ParserError
      { 'error' => raw.to_s }
    end


    # Sanitize string for JSON serialization
    # Strips control characters that break JSON and ensures valid UTF-8
    def sanitize_json_string(str)
      return '' unless str.is_a?(String)

      # Remove control characters (0x00-0x1F except \t, \n, \r)
      # These are the only valid control chars in JSON strings
      str.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F]/, '')
         .encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
    rescue StandardError => e
      str.to_s
    end


    # API Request Building
    def build_body(prompt, ctx, reasoning: false)
      system_prompt = reasoning ? Oracle::REASONING_PROMPT : Oracle::SYSTEM_PROMPT
      {
        model:       CONFIG::CFG[:model] || 'deepseek-chat',
        messages:    [
          { role: 'system', content: system_prompt },
          { role: 'user', content: prompt },
          { role: 'user', content: "Context: #{ctx.to_json}" }
        ],
        tools:       nil,
        max_tokens:  2048,
        temperature: 0.7
      }
    rescue StandardError => e
      HorologiumAeternum.system_error "Failed to build completion body: #{e.message.truncate 100}"
      raise
    end


    def build_body_with_messages_and_tools(messages, tools: nil, reasoning: false, temperature: nil)
      model = select_model CONFIG::CFG, reasoning
      max_tokens = select_max_tokens reasoning
      temperature ||= (Mnemosyne.aegis[:temperature] || 1.0).to_f
      # For DeepSeek reasoning models, we must NOT include tools to enable advanced reasoning
      # Reasoning models cannot use tools, so we omit the tools field entirely
      # Also detect reasoning models by name pattern for future compatibility
      # Sanitize messages: DeepSeek API requires content to be string or list, never nil
      messages = sanitize_tool_call_messages(messages)
      messages = messages.map.with_index do |msg, idx|
        m = msg.dup
        content = m[:content]
        if content.nil?
          if m[:role] == 'assistant' && m[:tool_calls]
            m.delete(:content)
          else
            puts "[CONDUIT][SANITIZE] Message #{idx}: content is nil for role=#{m[:role]}, setting to ''"
            m[:content] = ''
          end
        elsif !content.is_a?(String) && !content.is_a?(Array)
          puts "[CONDUIT][SANITIZE] Message #{idx}: content is #{content.class} for role=#{m[:role]}, converting to string"
          m[:content] = content.to_s
        end
        # Also ensure tool_call_id is a string
        if m[:tool_call_id] && !m[:tool_call_id].is_a?(String)
          puts "[CONDUIT][SANITIZE] Message #{idx}: tool_call_id is #{m[:tool_call_id].class}, converting to string"
          m[:tool_call_id] = m[:tool_call_id].to_s
        end
        m
      end
      base_body = { model:, messages:, max_tokens:, temperature: }

      if use_thinking_mode?(CONFIG::CFG, reasoning)
        effort = reasoning_effort_from_aegis
        body = { tools:, thinking: { type: 'enabled' } }
        body[:reasoning_effort] = effort if effort
        base_body.merge(body).tap { |b| b.delete(:temperature) }
      elsif reasoning || is_deepseek_reasoning_model?(model)
        base_body.merge tools: nil
      else
        base_body.merge tools: tools
      end
    rescue StandardError => e
      HorologiumAeternum.system_error "Failed to build request body: #{e.message.truncate 100}"
      raise
    end


    # Validates that every assistant message with tool_calls has matching tool messages.
    # DeepSeek API strictly requires: assistant(tool_calls:[id1,id2]) must be immediately
    # followed by tool(id1), tool(id2) — one tool message per tool_call_id.
    # If orphaned tool_calls are found, strips them to prevent 400 API errors.
    def sanitize_tool_call_messages(messages)
      return messages unless messages.is_a?(Array)

      cleaned = []
      pending_tool_ids = []
      orphaned_count = 0

      messages.each do |msg|
        role = msg[:role]
        tool_calls = msg[:tool_calls]
        tool_call_id = msg[:tool_call_id]

        # Drain pending tool ids from tool messages
        if role == 'tool' && tool_call_id && pending_tool_ids.include?(tool_call_id)
          pending_tool_ids.delete(tool_call_id)
          cleaned << msg
          next
        end

        # If we encounter a new assistant with tool_calls while there are still
        # pending tool ids from a previous assistant, that assistant is orphaned.
        # Strip its tool_calls from the previous assistant immediately.
        if role == 'assistant' && tool_calls.is_a?(Array) && tool_calls.any?
          unless pending_tool_ids.empty?
            cleaned.reverse_each do |cmsg|
              next unless cmsg[:role] == 'assistant' && cmsg[:tool_calls].is_a?(Array)

              cmsg_tool_ids = cmsg[:tool_calls].map { |tc| tc['id'] || tc[:id] }
              overlap = cmsg_tool_ids & pending_tool_ids
              if overlap.any?
                remaining = cmsg[:tool_calls].reject { |tc| pending_tool_ids.include?(tc['id'] || tc[:id]) }
                orphaned_count += (cmsg[:tool_calls].size - remaining.size)
                if remaining.any?
                  cmsg[:tool_calls] = remaining
                else
                  cmsg.delete(:tool_calls)
                  cmsg[:content] = "[Tool calls removed — responses missing] #{cmsg[:content]}"
                end
                pending_tool_ids -= overlap
              end
              break if pending_tool_ids.empty?
            end
            orphaned_count += pending_tool_ids.size
            pending_tool_ids.clear
          end
          tool_calls.map { |tc| tc['id'] || tc[:id] }.each { |id| pending_tool_ids << id }
          cleaned << msg
        elsif role == 'tool'
          # Tool message with no matching pending id — skip it (stale)
          next
        else
          cleaned << msg
        end
      end

      unless pending_tool_ids.empty?
        # Find and strip tool_calls from the last assistant message(s) that have
        # unmatched pending ids. Walk backwards and patch.
        cleaned.reverse_each do |msg|
          next unless msg[:role] == 'assistant' && msg[:tool_calls].is_a?(Array)

          msg_tool_ids = msg[:tool_calls].map { |tc| tc['id'] || tc[:id] }
          overlap = msg_tool_ids & pending_tool_ids
          if overlap.any?
            remaining = msg[:tool_calls].reject { |tc| pending_tool_ids.include?(tc['id'] || tc[:id]) }
            orphaned_count += (msg[:tool_calls].size - remaining.size)
            if remaining.any?
              msg[:tool_calls] = remaining
            else
              msg.delete(:tool_calls)
              msg[:content] = "[Tool calls removed — responses missing] #{msg[:content]}"
            end
            pending_tool_ids -= overlap
          end
          break if pending_tool_ids.empty?
        end
      end

      if orphaned_count > 0
        HorologiumAeternum.system_error(
          "Sanitized #{orphaned_count} orphaned tool call(s) — messages had assistant tool_calls without matching tool responses"
        )
      end

      cleaned
    end


    # Unified message building that handles both normal chat and task execution
    # When messages array is provided, it's used directly (ignoring standard prompt)
    # When prompt is provided, it builds standard system + user message structure
    # Now supports multimodal (vision) content with images
    def build_body_for_execution(messages: nil,
                                 prompt: nil,
                                 tools: nil,
                                 reasoning: false,
                                 set_temperature: nil,
                                 attachments: nil)
      model = select_model CONFIG::CFG, reasoning
      max_tokens = select_max_tokens reasoning
      temperature = set_temperature || (Mnemosyne.aegis[:temperature] || 1.0).to_f

      puts "[CONDUIT]: temperature=#{temperature}"

      base_body = { model:, messages:, max_tokens:, temperature: }

      # Sanitize messages: DeepSeek API requires content to be string or list, never nil
      # Also strip control characters that break JSON serialization
      # Now also handles multimodal content (arrays with text + images)
      messages = transform_messages_for_vision(messages) if messages
      messages = sanitize_tool_call_messages(messages) if messages

      base_body = { model:, messages:, max_tokens:, temperature: }

      body = base_body.merge(if use_thinking_mode?(CONFIG::CFG, reasoning)
                               effort = reasoning_effort_from_aegis
                               body = { tools:, thinking: { type: 'enabled' } }
                               body[:reasoning_effort] = effort if effort
                               body.tap { |b| b.delete(:temperature) }
                             elsif reasoning || is_deepseek_reasoning_model?(model)
                               { tools: nil }
                             elsif :gemini == CONFIG::CFG[:api_type]&.to_sym
                               rewrite_tools_to_gemini_format tools
                             elsif :anthropic == CONFIG::CFG[:api_type]&.to_sym
                               rewrite_tools_to_anthropic_format tools
                             else
                               { tools: tools }
                             end)

      # Enforce payload size limits - auto-cleanup images if too large
      enforce_payload_limits(body)
    rescue StandardError => e
      HorologiumAeternum.system_error "Failed to build execution body: #{e.message.truncate 100}"
      raise
    end


    # Maximum safe payload size for Bedrock/Kimi (20MB to be safe)
    MAX_PAYLOAD_SIZE = 20 * 1024 * 1024  # 20MB

    # Enforces payload size limits by auto-compressing or removing older images
    # If payload exceeds limit, keeps only the most recent screenshot and compresses it
    # Adds a system message explaining what happened and suggesting solutions
    def enforce_payload_limits(body)
      return body unless body[:messages]

      json_body = body.to_json
      current_size = json_body.bytesize

      return body if current_size <= MAX_PAYLOAD_SIZE

      puts "[CONDUIT][PAYLOAD] Size #{current_size / 1024 / 1024}MB exceeds limit, cleaning up..."

      # Step 1: Find all image messages and keep only the most recent
      cleaned_messages, removed_count = cleanup_old_images(body[:messages])
      body[:messages] = cleaned_messages

      json_body = body.to_json
      current_size = json_body.bytesize

      # Step 2: If still too large, compress remaining images further
      if current_size > MAX_PAYLOAD_SIZE
        body[:messages] = compress_remaining_images(body[:messages])
        json_body = body.to_json
        current_size = json_body.bytesize
      end

      # Step 3: Add system notice if we removed anything
      if removed_count > 0 || current_size > MAX_PAYLOAD_SIZE
        notice = build_payload_notice(removed_count, current_size)
        body[:messages] << { role: 'system', content: notice }
      end

      puts "[CONDUIT][PAYLOAD] Final size: #{current_size / 1024}KB"
      body
    rescue StandardError => e
      puts "[CONDUIT][PAYLOAD] Cleanup failed: #{e.message}"
      body
    end


    # Removes older images from conversation, keeping only the most recent screenshot
    # Returns [cleaned_messages, removed_count]
    def cleanup_old_images(messages)
      return [messages, 0] unless messages.is_a?(Array)

      # Find indices of all messages containing images
      image_indices = []
      messages.each_with_index do |msg, idx|
        next unless msg[:content].is_a?(Array)

        has_image = msg[:content].any? do |part|
          part[:type] == 'image' || part[:type] == 'image_url' ||
            (part[:image_url] && part[:image_url][:url]&.start_with?('data:'))
        end
        image_indices << idx if has_image
      end

      return [messages, 0] if image_indices.empty?
      return [messages, 0] if image_indices.size <= 1  # Keep at least one

      # Keep only the most recent image (last one in the array)
      to_remove = image_indices[0...-1]  # All except the last

      cleaned = messages.map.with_index do |msg, idx|
        if to_remove.include?(idx)
          # Replace this message's image with a text note
          {
            role: msg[:role],
            content: "[Screenshot removed to reduce payload size. Size exceeded limit with multiple images.]"
          }
        else
          msg
        end
      end

      [cleaned, to_remove.size]
    end


    # Compresses any remaining images in messages using higher compression
    def compress_remaining_images(messages)
      messages.map do |msg|
        next msg unless msg[:content].is_a?(Array)

        new_content = msg[:content].map do |part|
          if part[:type] == 'image_url' && part.dig(:image_url, :url)&.start_with?('data:image')
            # Re-compress with higher compression ratio
            compressed = compress_image_data(part[:image_url][:url], max_size_bytes: 500_000)
            if compressed && compressed != part[:image_url][:url]
              puts "[CONDUIT][COMPRESS] Reduced image from #{part[:image_url][:url].size / 1024}KB"
              { type: 'image_url', image_url: { url: compressed } }
            else
              part
            end
          else
            part
          end
        end

        { **msg, content: new_content }
      end
    end


    # Helper to compress image data that's already base64 encoded
    # Decodes base64 -> temp file -> re-encode with compression
    def compress_image_data(data_uri, max_size_bytes: 500_000)
      return data_uri unless data_uri.is_a?(String) && data_uri.size > max_size_bytes

      # Extract mime type and base64 data
      match = data_uri.match(/data:(image\/[^;]+);base64,(.+)/)
      return data_uri unless match

      mime_type = match[1]
      extension = mime_type == 'image/jpeg' ? 'jpg' : mime_type.split('/').last

      require 'tempfile'
      tempfile = Tempfile.new(['recompress', ".#{extension}"])
      tempfile.binmode
      tempfile.write(Base64.strict_decode64(match[2]))
      tempfile.close

      # Re-encode through VisionCoordinator which handles compression
      result = VisionCoordinator.load_and_encode({
        path: tempfile.path,
        format: extension,
        mime_type: 'image/jpeg'
      })

      if result[:data_uri] && result[:data_uri].size < data_uri.size
        puts "[CONDUIT][COMPRESS] #{data_uri.size / 1024}KB → #{result[:data_uri].size / 1024}KB"
        result[:data_uri]
      else
        data_uri
      end
    rescue StandardError => e
      puts "[CONDUIT][COMPRESS] Failed: #{e.message}"
      data_uri
    ensure
      tempfile.unlink if tempfile.respond_to?(:unlink) && File.exist?(tempfile.path)
    end


    # Builds a helpful notice message for the agent explaining what happened
    def build_payload_notice(removed_count, final_size)
      tips = [
        "Use smaller area: take_screenshot(mode: 'area', x: 0, y: 0, width: 800, height: 600)",
        "Use JPG format: take_screenshot(format: 'jpg')",
        "Capture only relevant region instead of full screen",
      ]

      notice = <<~NOTICE
        ⚠️ **Payload Size Management Activated**

        Your request contained multiple screenshots that exceeded API payload limits.

        **What happened:**
        - #{removed_count} older screenshot(s) were removed to prevent API error
        - Only the most recent screenshot was retained
        - Current payload size: #{final_size / 1024}KB

        **How to avoid this:**
        #{tips.map { |t| "• #{t}" }.join("\n")}

        **If you need multiple views:**
        Take screenshots one at a time and analyze each before taking the next.
      NOTICE

      notice.strip
    end

    # Transform messages to support multimodal/vision content
    # Detects image arrays and formats them per-provider requirements
    def transform_messages_for_vision(messages)
      return [] unless messages

      provider = CONFIG::CFG[:api_type]&.to_sym || :openai
      messages.map do |msg|
        transform_single_message_for_vision(msg.dup, provider)
      end
    rescue StandardError => e
      puts "[CONDUIT][VISION] Failed to transform messages: #{e.message}"
      messages
    end

    # Transform a single message based on provider requirements
    def transform_single_message_for_vision(msg, provider)
      content = msg[:content]

      # If content is already a string, return as-is
      return msg unless content.is_a?(Array)

      # Content is multimodal (array with text + images)
      # Transform based on provider
      case provider
      when :anthropic
        transform_for_anthropic(msg, content)
      when :gemini
        transform_for_gemini(msg, content)
      when :openai, nil
        transform_for_openai(msg, content)
      when :deepseek
        # DeepSeek API only supports text content — strip image parts
        text_parts = content.select { |p| p[:type] == 'text' }
        msg[:content] = text_parts.map { |p| p[:text] }.join('\n')
        msg
      else
        # Default: return simplified text representation
        text_parts = content.select { |p| p[:type] == 'text' }
        msg[:content] = text_parts.map { |p| p[:text] }.join('\\n')
        msg
      end
    end

    # Transform multimodal content for OpenAI API
    def transform_for_openai(msg, content_parts)
      # OpenAI requires content as an array with text and image_url objects
      openai_content = content_parts.map do |part|
        case part[:type]
        when 'text'
          { type: 'text', text: sanitize_json_string(part[:text] || part[:content] || '') }
        when 'image'
          { type: 'image_url', image_url: { url: part.dig(:source, :data) || part[:data_uri] || '' } }
        when 'image_url'
          # Already in OpenAI format from Artificer
          { type: 'image_url', image_url: { url: part.dig(:image_url, :url) || part[:image_url] || '' } }
        else
          { type: 'text', text: sanitize_json_string(part.to_s) }
        end
      end

      msg[:content] = openai_content
      msg
    end

    # Transform multimodal content for Anthropic API
    def transform_for_anthropic(msg, content_parts)
      # Anthropic uses 'content' array with specific structure
      anthropic_content = content_parts.map do |part|
        case part[:type]
        when 'text'
          { type: 'text', text: sanitize_json_string(part[:text] || part[:content] || '') }
        when 'image'
          source = part[:source] || part
          {
            type: 'image',
            source: {
              type: source[:type] || 'base64',
              media_type: source[:media_type] || part[:mime_type] || 'image/png',
              data: source[:data] || part[:data_uri]&.split(',', 2)&.last || ''
            }
          }
        else
          { type: 'text', text: sanitize_json_string(part.to_s) }
        end
      end

      msg[:content] = anthropic_content
      msg
    end

    # Transform multimodal content for Gemini API
    def transform_for_gemini(msg, content_parts)
      # Gemini uses 'parts' array inside content
      gemini_parts = content_parts.map do |part|
        case part[:type]
        when 'text'
          { text: sanitize_json_string(part[:text] || part[:content] || '') }
        when 'image'
          source = part[:source] || part
          {
            inline_data: {
              mime_type: source[:media_type] || part[:mime_type] || 'image/png',
              data: source[:data] || part[:data_uri]&.split(',', 2)&.last || ''
            }
          }
        else
          { text: sanitize_json_string(part.to_s) }
        end
      end

      msg[:content] = { parts: gemini_parts }
      msg
    end


    # API Communication
    def post(body, timeout = 120)
      key = extract_api_key CONFIG::CFG
      endpoint = extract_api_endpoint CONFIG::CFG
      openai_project = CONFIG::CFG[:'openai-project'] || CONFIG::CFG['openai-project']
      headers = openai_project ? { 'OpenAI-Project' => openai_project.to_s } : {}
      puts "[CONDUIT] POST #{endpoint}"
      puts "[CONDUIT] HEADERS: #{headers.inspect.truncate(120)}" unless headers.empty?
      validate_api_key key

      connection = create_faraday_connection
      response = execute_api_request connection, endpoint, key, body, timeout, headers

      return response if response.is_a?(String) # synthetic error from 400/500 handler

      response.body
    rescue Faraday::TimeoutError => e
      handle_timeout_error e, timeout
    rescue Faraday::ConnectionFailed, EOFError => e
      if :retry == handle_connection_error(e)
        puts 'RETRY'
        retry
      end
    rescue Faraday::UnprocessableEntityError => e
      handle_unprocessable_entity_error e
    rescue Faraday::Error => e
      handle_generic_faraday_error e
    rescue StandardError => e
      handle_api_error e
    end


    # Parses a response from the Gemini API and transforms it into an OpenAI-compatible format
    # that the original `extract_response_data` function can understand. It reconstructs
    # the `choices` and `message` structure.
    #
    # @param gemini_response [Hash] The parsed JSON response from the Gemini API.
    # @return [Hash] A hash structured like an OpenAI API response.
    def parse_gemini_response_to_openai_format(gemini_response)
      # Basic error handling for an empty or invalid response.
      candidate = gemini_response['candidates']&.first
      if candidate.nil? || candidate.dig('content', 'parts').nil?
        return { 'choices' => [{ 'message' => { 'content' => '', 'tool_calls' => [] } }] }
      end

      parts = candidate.dig('content', 'parts') || []

      full_text_content = ''
      reasoning_content = ''
      tool_calls = []

      parts.each do |part|
        # If the part contains text, process it.
        if (text = part['text'])
          # Check for and extract the reasoning block, which is a convention used by this adapter.
          if text.include?('<reasoning>') && text.include?('</reasoning>')
            reasoning_content = text.match(%r{<reasoning>(.*?)</reasoning>}m)&.captures&.first&.strip
            # Add the text outside the reasoning block to the main content.
            full_text_content += text.gsub(%r{<reasoning>.*?</reasoning>}m, '').strip
          else
            full_text_content += text
          end
        end

        # If the part contains a function call, translate it back to OpenAI's `tool_calls` format.
        next unless (function_call = part['functionCall'])

        tool_calls << {
          'id'       => "call_#{SecureRandom.hex 8}", # OpenAI format requires an ID, so we generate one.
          'type'     => 'function',
          'function' => {
            'name'      => function_call['name'],
            'arguments' => function_call['args'].to_json # Convert args object back to a JSON string.
          }
        }
      end

      # Build the final OpenAI-like structure that `extract_response_data` can parse.
      {
        'choices' => [
          {
            'message' => {
              'content'           => full_text_content.strip,
              'tool_calls'        => tool_calls,
              'reasoning_content' => reasoning_content # Add the extracted reasoning.
            }
          }
        ]
      }
    end


    # Converts an array of OpenAI-formatted tool definitions into the structure
    # required by the Google Gemini API.
    #
    # @param tools [Array<Hash>] An array of tools in OpenAI's format.
    # @return [Hash] A hash containing the `:functionDeclarations` for the Gemini API.
    def rewrite_tools_to_gemini_format(tools)
      return nil if tools.nil? || tools.empty?

      declarations = tools.map do |tool|
        next unless 'function' == tool[:type].to_s && tool[:function]

        function_data = tool[:function]
        parameters = function_data[:parameters]

        # Recursively convert all JSON schema type values to uppercase.
        # upcase_schema_types(parameters)

        {
          name:        function_data[:name],
          description: function_data[:description],
          parameters:  parameters
        }
      end.compact

      { tools: [{ functionDeclarations: declarations }] }
    end


    # A recursive helper method to traverse a JSON schema hash and convert all
    # values for the `type` key to uppercase. It also handles nullable types.
    #
    # @param schema [Hash, Object] The schema or sub-schema to transform.
    # @return [void] This method modifies the hash in place.
    def upcase_schema_types(schema)
      return unless schema.is_a? Hash

      # Handle nullable types (e.g., type: ['string', 'null']) which is a
      # common pattern in OpenAI schemas but not valid in Gemini's.
      if schema[:type].is_a? Array
        # Find and remove 'null' to handle nullability
        schema[:nullable] = true if schema[:type].delete 'null'
        # The primary type is whatever is left in the array (should be one item).
        schema[:type] = schema[:type].first
      end

      # Convert the type of the current object to uppercase.
      schema[:type] = schema[:type].to_s.upcase if schema.key? :type

      # If the object has properties, recurse into each property.
      if schema[:properties].is_a? Hash
        schema[:properties].each_value { |prop_schema| upcase_schema_types prop_schema }
      end

      # If the object is an array, recurse into its `items` definition.
      upcase_schema_types schema[:items] if schema.key? :items
    end


    # This is the new, dedicated rewrite function. It takes a simple array of
    # message hashes and transforms it into the structured Gemini format.
    #
    # @param messages [Array<Hash>] A flat array of message objects, each with a :role and :content.
    # @return [Hash] A hash containing the `:system_instruction` and `:contents` ready for the Gemini API.
    def rewrite_to_gemini_format(messages)
      system_instruction_parts = []
      gemini_contents = []

      messages.each do |msg|
        role_str = msg[:role].to_s

        # Any message with a 'system' role contributes to the system instructions.
        if 'system' == role_str
          system_instruction_parts << msg[:content]
          next
        end

        # --- Tool & Function Call Conversion ---

        # 1. Convert an OpenAI-style assistant message with `tool_calls`
        if 'assistant' == role_str && msg[:tool_calls]
          msg[:tool_calls].each do |tool_call|
            function_name = tool_call.dig :function, :name
            # Add a check to ensure the function name is not empty.
            next if function_name.nil? || function_name.empty?

            # OpenAI arguments are a JSON string; Gemini's are a parsed object.
            args = JSON.parse(tool_call.dig(:function, :arguments) || '{}')
            gemini_contents << {
              role:  'model',
              parts: [{
                functionCall: {
                  name: function_name,
                  args: args
                }
              }]
            }
          end
          next # Proceed to the next message in the input list
        end

        # 2. Convert an OpenAI-style `tool` response message
        if 'tool' == role_str
          function_name = msg[:name] || msg[:tool_call_id]
          # Add a check to ensure the function name (from name or tool_call_id) is not empty.
          next if function_name.nil? || function_name.empty?

          # OpenAI content is a JSON string; Gemini's `response.content` is a parsed object.
          response_content = JSON.parse(msg[:content].to_s || '{}')
          gemini_contents << {
            role:  'function',
            parts: [{
              functionResponse: {
                name:     function_name,
                response: {
                  content: response_content
                }
              }
            }]
          }
          next # Proceed to the next message
        end

        # --- Regular Message Handling ---
        next unless msg[:content] # Skip assistant messages that only contained tool_calls

        current_role = 'assistant' == role_str ? 'model' : 'user'
        current_content = msg[:content].to_s # Ensure content is a string

        last_message = gemini_contents.last

        # Merge with the previous message if the role is the same AND it's a text part.
        if last_message && last_message[:role] == current_role && last_message[:parts][0][:text]
          last_message[:parts][0][:text] += "\n\n#{current_content}"
        else
          # Otherwise, add a new message to the contents array.
          gemini_contents << {
            role:  current_role,
            parts: [{ text: current_content }]
          }
        end
      end

      # Finalize and return the payload.
      final_system_instruction = {
        parts: [{ text: system_instruction_parts.compact.join("\n\n") }]
      }

      {
        system_instruction: final_system_instruction,
        contents:           gemini_contents
      }
    end


    # Max retries for tool_calls format errors from DeepSeek et al.
    TOOL_CALLS_RETRY_MAX = 3

    # Pattern matching the DeepSeek "tool_calls must be followed by tool messages" error
    TOOL_CALLS_FORMAT_ERROR_RE = /
      tool_calls.*must\s+be\s+followed\s+by\s+tool\s+messages |
      insufficient\s+tool\s+messages\s+following\s+tool_calls |
      tool_call_id.*not\s+found |
      orphaned\s+tool_calls?
    /ix

    def execute_api_request(connection, endpoint, api_key, body, timeout, headers = {})
      retries = 0

      begin
        json_body = body.to_json
        JSON.parse(json_body) # Validate

        response = connection.post endpoint do |request|
          if :gemini == CONFIG::CFG[:api_type].to_sym
            request.headers['X-goog-api-key'] = api_key.to_s
          elsif :anthropic == CONFIG::CFG[:api_type].to_sym
            request.headers['x-api-key'] = api_key.to_s
            request.headers['anthropic-version'] = '2023-06-01'
          else
            request.headers['Authorization'] = "Bearer #{api_key}"
          end
          request.headers['Content-Type'] = 'application/json'

          # Apply custom headers from .aethercodex config (e.g., OpenAI-Project)
          headers.each { |k, v| request.headers[k.to_s] = v.to_s }

          request.body = json_body
          request.options.timeout = timeout
          request.options.open_timeout = timeout / 2
        end

        unless 200 == response.status
          error_message = ErrorHandler.handle_http_status_codes response
          if error_message.is_a?(String)
            # Retry tool_calls format errors: raise so the rescue block below
            # (which has valid `retry` context) handles sanitization + retry.
            if retries < TOOL_CALLS_RETRY_MAX && error_message.match?(TOOL_CALLS_FORMAT_ERROR_RE)
              raise Faraday::ClientError.new(error_message, { status: 400, body: error_message })
            end
            HorologiumAeternum.system_error('API request malformed — sending error back to model',
                                            message: error_message.truncate(300))
            return { 'choices' => [{ 'message' => { 'content' => "❌ API Error: #{error_message}" } }] }.to_json
          end
        end

        response
      rescue Faraday::ClientError, Faraday::ServerError => e
        error_message = ErrorHandler.handle_faraday_client_error e
        if error_message.is_a?(String)
          # Retry tool_calls format errors after sanitizing messages
          if retries < TOOL_CALLS_RETRY_MAX && error_message.match?(TOOL_CALLS_FORMAT_ERROR_RE)
            retries += 1
            HorologiumAeternum.system_error(
              "Tool calls format error — sanitizing messages and retrying (#{retries}/#{TOOL_CALLS_RETRY_MAX})",
              message: error_message.truncate(200)
            )
            sanitize_body_messages!(body)
            retry
          end
          HorologiumAeternum.system_error('API request error — sending back to model for self-correction',
                                          message: error_message.truncate(300))
          return { 'choices' => [{ 'message' => { 'content' => "❌ API Error: #{error_message}" } }] }.to_json
        end
      rescue Faraday::ConnectionFailed, EOFError => e
        if :retry == handle_connection_error(e)
          puts 'RETRY'
          retry
        end
      rescue StandardError => e
        HorologiumAeternum.system_error "Failed to execute API request: #{e.message.truncate 100}"
        raise e
      end
    end


    # Mutates body[:messages] in-place: strips orphaned tool_calls that lack
    # matching tool responses, preventing DeepSeek "tool_calls must be followed
    # by tool messages" errors.
    def sanitize_body_messages!(body)
      return unless body.is_a?(Hash) && body[:messages].is_a?(Array)

      before = body[:messages].size
      body[:messages] = sanitize_tool_call_messages(body[:messages])
      after = body[:messages].size
      HorologiumAeternum.system_error(
        "Re-sanitized messages: #{before - after} removed (#{before} → #{after})"
      ) if before != after
    end
    

    def complete(ctx)
      prompt = "Provide a code completion for the cursor based on context:\n#{ctx[:snippet]}"
      body = build_body prompt, ctx
      raw = post body
      json = ensure_json raw
      # log_json json: json
      json.dig('choices', 0, 'message', 'content') || ''
    rescue StandardError => e
      log_json error: e.message, backtrace: e.backtrace
      ''
    end


    def generate_ai_response(messages, tools, reasoning, set_temperature, attachments = nil)
      # Handle nil tools case - use empty array for instrumenta_schema
      instrumenta_schema = tools.respond_to?(:instrumenta_schema) ? tools.instrumenta_schema : []

      # Use unified message building - when messages array is provided, it's used directly
      # This allows task execution to provide complete message structure without interference
      body = build_body_for_execution(messages:,
                                      tools: instrumenta_schema, reasoning:, set_temperature:,
                                      attachments:)

      # puts '[ORACLE][CONDUIT][GENERATE_AI_RESPONSE]: ' \
      #      "#{messages.map do |msg|
      #        msg.transform_values do |v|
      #          v.to_s.truncate 200
      #        end
      #      end.inspect}, #{tools}"
      # puts "[ORACLE][CONDUIT][BODY]: model=#{body[:model]}, max_tokens=#{body[:max_tokens]}, temperature=#{body[:temperature]}"
      # puts "[ORACLE][CONDUIT][BODY_MESSAGES_COUNT]: #{body[:messages].size}"
      # puts "[ORACLE][CONDUIT][BODY_MESSAGES_FIRST]: #{body[:messages].first.transform_values do |v|
      #   v.to_s.truncate(100)
      # end.inspect}"
      # puts "[ORACLE][CONDUIT][BODY_MESSAGES_LAST]: #{body[:messages].last.transform_values do |v|
      #   v.to_s.truncate(100)
      # end.inspect}"
 # !> assigned but unused variable - max_tokens
      start_time = Time.now
      max_tokens = select_max_tokens reasoning
      puts '[CONDUIT][GENERATE_AI_RESPONSE]: ' \
           "sending... token usage #{body.to_s.tok_len}/128000 " \
           "(#{((body.to_s.tok_len.to_f/128000)*100).round}%)"

      post(body, reasoning ? 600 : 300)
        .then { |raw| ensure_json raw }
        .then { |json| :anthropic == CONFIG::CFG[:api_type]&.to_sym ? parse_anthropic_response_to_openai_format(json) : json }
        .tap do |json|
          execution_time = Time.now - start_time
          puts "[CONDUIT][GENERATE_AI_RESPONSE]: response after #{execution_time.round 2}s"

          log_json(json: json.transform_values do |v|
            v.to_s.truncate 200
          end)
        end
    rescue StandardError => e
      handle_api_error e
    end


    def extract_response_data(json, arts)
      json = parse_gemini_response_to_openai_format json if :gemini == CONFIG::CFG[:api_type].to_sym

      choice = (json['choices'] || []).first || {}
      msg = choice['message'] || {}
      content = msg['content'].to_s
      tcalls = msg['tool_calls'] || []
      arts[:reasoning_content] = msg['reasoning_content'].to_s if msg['reasoning_content']
      [content, tcalls, arts]
    rescue StandardError => e
      HorologiumAeternum.system_error "Failed to extract response data: #{e.message.truncate 100}"
      ['', [], arts]
    end


    # Connection Management
    def create_faraday_connection
      Faraday.new do |faraday|
        faraday.request :json
        faraday.response :raise_error
        faraday.adapter Faraday.default_adapter
      end
    rescue StandardError => e
      error_msg = "Failed to create Faraday connection: #{e.message.truncate 100}"
      HorologiumAeternum.system_error error_msg
      raise e
    end


    # Error Handling (Simplified using ErrorHandler)
    def handle_timeout_error(error, timeout)
      raise Timeout::Error, "API request timed out after #{timeout} seconds: #{error.message}"
    rescue StandardError => e
      HorologiumAeternum.system_error "Failed to handle timeout error: #{e.message.truncate 100}"
      raise error
    end


    def handle_connection_error(error)
      if error.cause.is_a?(EOFError) || error.wrapped_exception.is_a?(EOFError) || error.is_a?(EOFError)
        puts 'EOFError'
        puts "#{error.wrapped_exception}, #{error.cause}"
        # EOF reached - log and restart the request
        HorologiumAeternum.system_error "EOF reached - restarting request: #{error.message.truncate 100}"
        # Retry the entire post method
      else
        puts error.inspect.truncate 500
        raise "Connection Failed: #{error.wrapped_exception}"
      end
      :retry
    end


    def handle_unprocessable_entity_error(error)
      raise "Unprocessable Entity Error: #{error.response[:body] || error.wrapped_exception}"
    end


    def handle_generic_faraday_error(error)
      raise (error.response && error.response[:body]) || error.message
    end


    def handle_api_error(error)
      raise error
    end


    def extract_deepseek_error_details(exception)
      ErrorHandler.extract_deepseek_error_details exception
    end


    def parse_api_error_response(response_body)
      ErrorHandler.parse_api_error_response response_body
    end
  end
end
# ~> <internal:/Users/d/.rvm/rubies/ruby-3.1.7/lib/ruby/3.1.0/rubygems/core_ext/kernel_require.rb>:85:in `require': cannot load such file -- faraday (LoadError)
# ~> 	from <internal:/Users/d/.rvm/rubies/ruby-3.1.7/lib/ruby/3.1.0/rubygems/core_ext/kernel_require.rb>:85:in `require'
# ~> 	from -:3:in `<main>'
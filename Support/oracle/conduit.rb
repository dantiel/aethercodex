# frozen_string_literal: true
require 'faraday'
require 'json'
require 'yaml'
require_relative '../mnemosyne/mnemosyne'
require_relative '../instrumentarium/horologium_aeternum'
require_relative 'error_handler'
require_relative '../instrumentarium/metaprogramming_utils'
require_relative '../instrumentarium/scriptorium'



# Conduit - Hermetic conduit for DeepSeek API communication
# Channels cosmic energies through the digital aether for oracle divination
class Conduit
  class << self
    def select_model(config, reasoning)
      if reasoning
        config[:reasoning_model] || 'deepseek-reasoner'
      else
        config[:model] || 'deepseek-chat'
      end
    rescue StandardError => e
      HorologiumAeternum.system_error "Failed to select model: #{e.message.truncate 100}"
      'deepseek-chat'
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
      base_body = { model:, messages:, max_tokens:, temperature: }

      if reasoning || is_deepseek_reasoning_model?(model)
        base_body.merge tools: nil
      else
        base_body.merge tools: tools
      end
    rescue StandardError => e
      HorologiumAeternum.system_error "Failed to build request body: #{e.message.truncate 100}"
      raise
    end


    # Unified message building that handles both normal chat and task execution
    # When messages array is provided, it's used directly (ignoring standard prompt)
    # When prompt is provided, it builds standard system + user message structure
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

      # Apply Gemini-specific formatting if using Gemini API
      base_body = if :gemini == CONFIG::CFG[:api_type]&.to_sym
                    # Use the existing rewrite_to_gemini_format method from Oracle
                    gemini_format = rewrite_to_gemini_format messages
                    # Gemini uses different structure with system_instruction and contents
                    gemini_format.merge({
                      generationConfig: { temperature:, maxOutputTokens: max_tokens }
                    })
                  else
                    { model:, max_tokens:, temperature:, messages: messages }
                  end

      if reasoning || is_deepseek_reasoning_model?(model)
        base_body.merge tools: nil
      else
        base_body.merge (if :gemini == CONFIG::CFG[:api_type]&.to_sym
          rewrite_tools_to_gemini_format tools
        else
          { tools: tools }
        end)
      end
    rescue StandardError => e
      HorologiumAeternum.system_error "Failed to build execution body: #{e.message.truncate 100}"
      raise
    end


    # API Communication
    def post(body, timeout = 120)
      key = extract_api_key CONFIG::CFG
      endpoint = extract_api_endpoint CONFIG::CFG
      validate_api_key key

      connection = create_faraday_connection
      response = execute_api_request connection, endpoint, key, body, timeout

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
            reasoning_content = text.match(/<reasoning>(.*?)<\/reasoning>/m)&.captures&.first&.strip
            # Add the text outside the reasoning block to the main content.
            full_text_content += text.gsub(/<reasoning>.*?<\/reasoning>/m, '').strip
          else
            full_text_content += text
          end
        end

        # If the part contains a function call, translate it back to OpenAI's `tool_calls` format.
        if (function_call = part['functionCall'])
          tool_calls << {
            'id' => "call_#{SecureRandom.hex(8)}", # OpenAI format requires an ID, so we generate one.
            'type' => 'function',
            'function' => {
              'name' => function_call['name'],
              'arguments' => function_call['args'].to_json # Convert args object back to a JSON string.
            }
          }
        end
      end

      # Build the final OpenAI-like structure that `extract_response_data` can parse.
      {
        'choices' => [
          {
            'message' => {
              'content' => full_text_content.strip,
              'tool_calls' => tool_calls,
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
        next unless tool[:type].to_s == 'function' && tool[:function]

        function_data = tool[:function]
        parameters = function_data[:parameters]

        # Recursively convert all JSON schema type values to uppercase.
        # upcase_schema_types(parameters)

        {
          name: function_data[:name],
          description: function_data[:description],
          parameters: parameters
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
      return unless schema.is_a?(Hash)

      # Handle nullable types (e.g., type: ['string', 'null']) which is a
      # common pattern in OpenAI schemas but not valid in Gemini's.
      if schema[:type].is_a?(Array)
        # Find and remove 'null' to handle nullability
        if schema[:type].delete('null')
          schema[:nullable] = true
        end
        # The primary type is whatever is left in the array (should be one item).
        schema[:type] = schema[:type].first
      end

      # Convert the type of the current object to uppercase.
      schema[:type] = schema[:type].to_s.upcase if schema.key?(:type)

      # If the object has properties, recurse into each property.
      if schema[:properties].is_a?(Hash)
        schema[:properties].each_value { |prop_schema| upcase_schema_types(prop_schema) }
      end

      # If the object is an array, recurse into its `items` definition.
      upcase_schema_types(schema[:items]) if schema.key?(:items)
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
        if role_str == 'system'
          system_instruction_parts << msg[:content]
          next
        end

        # --- Tool & Function Call Conversion ---

        # 1. Convert an OpenAI-style assistant message with `tool_calls`
        if role_str == 'assistant' && msg[:tool_calls]
          msg[:tool_calls].each do |tool_call|
            function_name = tool_call.dig(:function, :name)
            # Add a check to ensure the function name is not empty.
            next if function_name.nil? || function_name.empty?

            # OpenAI arguments are a JSON string; Gemini's are a parsed object.
            args = JSON.parse(tool_call.dig(:function, :arguments) || '{}')
            gemini_contents << {
              role: 'model',
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
        if role_str == 'tool'
          function_name = msg[:name] || msg[:tool_call_id]
          # Add a check to ensure the function name (from name or tool_call_id) is not empty.
          next if function_name.nil? || function_name.empty?

          # OpenAI content is a JSON string; Gemini's `response.content` is a parsed object.
          response_content = JSON.parse(msg[:content].to_s || '{}')
          gemini_contents << {
            role: 'function',
            parts: [{
              functionResponse: {
                name: function_name,
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

        current_role = (role_str == 'assistant') ? 'model' : 'user'
        current_content = msg[:content].to_s # Ensure content is a string

        last_message = gemini_contents.last

        # Merge with the previous message if the role is the same AND it's a text part.
        if last_message && last_message[:role] == current_role && last_message[:parts][0][:text]
          last_message[:parts][0][:text] += "\n\n#{current_content}"
        else
          # Otherwise, add a new message to the contents array.
          gemini_contents << {
            role: current_role,
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
        contents: gemini_contents
      }
    end
    
    
    def execute_api_request(connection, endpoint, api_key, body, timeout)
      puts "BLA #{CONFIG::CFG.inspect}"
      puts "BLA #{api_key}"
      response = connection.post endpoint do |request|
        if :gemini == CONFIG::CFG[:api_type].to_sym
          request.headers['X-goog-api-key'] = "#{api_key}"
        else
          request.headers['Authorization'] = "Bearer #{api_key}"
        end
        request.headers['Content-Type'] = 'application/json'
        request.body = body.to_json
        request.options.timeout = timeout
        request.options.open_timeout = timeout / 2
      end

      ErrorHandler.handle_http_status_codes response unless 200 == response.status

      response
    rescue Faraday::ClientError => e
      ErrorHandler.handle_faraday_client_error e
    rescue Faraday::ConnectionFailed, EOFError => e
      if :retry == handle_connection_error(e)
        puts 'RETRY'
        retry
      end
    rescue StandardError => e
      HorologiumAeternum.system_error "Failed to execute API request: #{e.message.truncate 100}"
      raise e
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
      post(body, reasoning ? 600 : 300)
        .then { |raw| ensure_json raw }
        .tap do |json|
        log_json(json: json.transform_values do |v|
          v.to_s.truncate(200)
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
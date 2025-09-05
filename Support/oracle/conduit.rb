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
    # Configuration and Utilities
    def load_cfg
      path = File.expand_path '../.aethercodex', __dir__
      puts "[CONDUIT][LOAD CFG]: loading path: #{path} exist?=#{File.exist? path}"
      if File.exist? path
        config = YAML.load_file(path)
        config.respond_to?(:deep_symbolize_keys) ? config.deep_symbolize_keys : {}
      else
        {}
      end
    rescue StandardError => e
      HorologiumAeternum.system_error "Failed to load config: #{e.message[0..100]}"
      {}
    end


    def select_model(config, reasoning)
      if reasoning
        config['reasoning-model'] || 'deepseek-reasoner'
      else
        config['model'] || 'deepseek-chat'
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
      config[:'api-key'] || ENV.fetch('DEEPSEEK_API_KEY', nil)
    rescue StandardError => e
      HorologiumAeternum.system_error "Failed to extract API key: #{e.message.truncate 100}"
      nil
    end


    def extract_api_endpoint(config)
      config[:'api-url'] || ENV.fetch('DEEPSEEK_API_URL', nil)
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
      cfg = load_cfg
      system_prompt = reasoning ? Oracle::REASONING_PROMPT : Oracle::SYSTEM_PROMPT
      {
        model:       cfg['model'] || 'deepseek-chat',
        messages:    [
          { role: 'system', content: system_prompt },
          { role: 'user', content: prompt },
          { role: 'user', content: "Context: #{ctx.to_json}" }
        ],
        tools:       [],
        max_tokens:  2048,
        temperature: 0.7
      }
    rescue StandardError => e
      HorologiumAeternum.system_error "Failed to build completion body: #{e.message.truncate 100}"
      raise
    end


    def build_body_with_messages_and_tools(messages, tools: [], reasoning: false)
      cfg = load_cfg
      model = select_model cfg, reasoning
      max_tokens = select_max_tokens reasoning
      temperature = (Mnemosyne.aegis[:temperature] || 1.0).to_f

      # For DeepSeek reasoning models, we must NOT include tools to enable advanced reasoning
      # Reasoning models cannot use tools, so we omit the tools field entirely
      # Also detect reasoning models by name pattern for future compatibility
      base_body = { model:, messages:, max_tokens:, temperature: }
      
      if reasoning || is_deepseek_reasoning_model?(model)
        base_body
      else
        base_body.merge(tools: tools)
      end
    rescue StandardError => e
      HorologiumAeternum.system_error "Failed to build request body: #{e.message.truncate 100}"
      raise
    end


    # API Communication
    def post(body, timeout = 120)
      cfg = load_cfg
      key = extract_api_key cfg
      endpoint = extract_api_endpoint cfg
      validate_api_key key

      connection = create_faraday_connection
      response = execute_api_request connection, endpoint, key, body, timeout

      response.body
    rescue Faraday::TimeoutError => e
      handle_timeout_error e, timeout
    rescue Faraday::ConnectionFailed => e
      handle_connection_error e
    rescue Faraday::UnprocessableEntityError => e
      handle_unprocessable_entity_error e
    rescue Faraday::Error => e
      handle_generic_faraday_error e
    rescue StandardError => e
      handle_api_error e
    end


    def execute_api_request(connection, endpoint, api_key, body, timeout)
      response = connection.post endpoint do |request|
        request.headers['Authorization'] = "Bearer #{api_key}"
        request.headers['Content-Type'] = 'application/json'
        request.body = body.to_json
        request.options.timeout = timeout
        request.options.open_timeout = timeout / 2
      end

      ErrorHandler.handle_http_status_codes response unless 200 == response.status

      response
    rescue Faraday::ClientError => e
      ErrorHandler.handle_faraday_client_error e
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


    def generate_ai_response(msgs, tools, reasoning)
      # Handle nil tools case - use empty array for instrumenta_schema
      tools_schema = tools.respond_to?(:instrumenta_schema) ? tools.instrumenta_schema : []
      body = build_body_with_messages_and_tools(msgs, tools: tools_schema, reasoning:)
      puts "[ORACLE][CONDUIT][GENERATE_AI_RESPONSE]: "\
           "#{msgs.map{ |msg| msg.transform_values{ |v| v.to_s.truncate(200) }}.inspect}, #{tools}"
      puts "[ORACLE][CONDUIT][BODY]: model=#{body[:model]}, max_tokens=#{body[:max_tokens]}, temperature=#{body[:temperature]}"
      puts "[ORACLE][CONDUIT][BODY_MESSAGES_COUNT]: #{body[:messages].size}"
      puts "[ORACLE][CONDUIT][BODY_MESSAGES_FIRST]: #{body[:messages].first.transform_values{ |v| v.to_s.truncate(100) }.inspect}"
      puts "[ORACLE][CONDUIT][BODY_MESSAGES_LAST]: #{body[:messages].last.transform_values{ |v| v.to_s.truncate(100) }.inspect}"
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
      choice = (json['choices'] || []).first || {}
      msg = choice['message'] || {}
      content = msg['content'].to_s
      tcalls = msg['tool_calls'] || []
      arts[:reasoning_content] = msg['reasoning_content'].to_s if msg['reasoning_content']
      [content, tcalls, arts]
    rescue StandardError => e
      HorologiumAeternum.system_error "Failed to extract response data: #{e.message.truncate(100)}"
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
      raise "Connection Failed: #{error.wrapped_exception}"
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
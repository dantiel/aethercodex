# frozen_string_literal: true

require 'json'
require_relative '../instrumentarium/horologium_aeternum'



# Hermetic Error Handler - Centralized error handling for Oracle and Conduit
class ErrorHandler
  class << self
    # Oracle Error Handling
    def handle_divination_error(error, tool_results)
      error_message = error.message.truncate 300
      backtrace = error.backtrace&.first(3)&.join "\n"
      
      puts "[ORACLE][HANDLE_DIVINATION_ERROR]: #{error.inspect}"
      
      HorologiumAeternum.system_error("Divination failed: #{error_message}", backtrace:)

      if error_message.include?('invalid_request_error') &&
         error_message.include?('insufficient tool messages')

        return ['<<empty>>', { error: 'Tool execution protocol violation' }, tool_results]
      end

      ['<<empty>>', { error: "Divination failed: #{error_message}" }, tool_results]
    end


    # Exception Handling
    def handle_restart_exception(exception)
      # For temperature change restarts, we want to continue execution rather than fail
      if exception.message.include?('Temperature change detected')
        HorologiumAeternum.thinking "Temperature change handled gracefully - continuing execution"
        return ['<<temperature change handled>>', {}, []]
      else
        HorologiumAeternum.system_error "Restart exception: #{exception.message.truncate 100}"
        raise
      end
    rescue StandardError => e
      error_msg = "Failed to handle restart exception: #{e.message.truncate 100}"
      HorologiumAeternum.system_error error_msg
      raise exception
    end
    


    def handle_hermetic_execution_error(error, context_message)
      HorologiumAeternum.system_error \
        "#{context_message}: #{error.message.truncate 100}"

      raise error
    end




    # Conduit Error Handling (Extracted from Conduit)
    def handle_http_status_codes(response)
      status = response.status
      error_info = parse_api_error_response response.body

      base_message = status_code_base_message status
      detailed_message = add_error_details base_message, error_info
      full_message = add_solution_guidance detailed_message, status

      raise full_message
    end


    def handle_faraday_client_error(error)
      status = error.response&.dig :status
      error_info = parse_api_error_response(error.response[:body]) if error.response

      base_message = status_code_base_message(status) || "API Request Failed: #{error.message}"
      detailed_message = add_error_details base_message, error_info
      full_message = add_solution_guidance detailed_message, status

      raise full_message
    end


    def extract_deepseek_error_details(exception)
      extract_from_json_message(exception) ||
        extract_from_faraday_response(exception) ||
        extract_basic_error_info(exception)
    end


    def parse_api_error_response(response_body)
      return {} unless response_body

      parsed = safe_json_parse response_body.to_s
      return {} unless parsed.is_a? Hash

      error_info = parsed['error'] || parsed
      {
        'message' => error_info['message'] || error_info['error'] || error_info['detail'],
        'code'    => error_info['code'],
        'type'    => error_info['type']
      }.compact
    rescue JSON::ParserError
      extract_basic_error_info_from_string response_body
    end

    private

    def status_code_base_message(status)
      case status
      when 400 then 'Invalid Format: Invalid request body format.'
      when 401 then 'Authentication Fails: Invalid API key.'
      when 402 then 'Insufficient Balance: You have run out of API credits.'
      when 403 then 'Forbidden: Access denied.'
      when 404 then 'Not Found: The requested resource does not exist.'
      when 408 then 'Request Timeout: The server timed out waiting for the request.'
      when 422 then 'Invalid Parameters: Your request contains invalid parameters.'
      when 429 then 'Rate Limit Reached: You are sending requests too quickly.'
      when 500 then 'Server Error: DeepSeek API is experiencing technical difficulties.'
      when 502 then 'Bad Gateway: The API gateway is experiencing issues.'
      when 503 then 'Server Overloaded: The server is overloaded due to high traffic.'
      when 504 then 'Gateway Timeout: The API gateway timed out.'
      when 500..599 then "Server Error: DeepSeek API is experiencing issues (HTTP #{status})."
      end
    end


    def add_error_details(base_message, error_info)
      return base_message unless error_info && error_info['message']

      "#{base_message} #{error_info['message']}"
    end


    def add_solution_guidance(message, status)
      case status
      when 400, 422
        format_solution(message, 'modify your request according to the error hints. ' \
                                 'Refer to DeepSeek API Docs for format details.')
      when 401
        format_solution(message,
                        'check your API key configuration. If you don\'t have one, ' \
                        'create an API key first at https://platform.deepseek.com/api_keys')
      when 402
        format_solution(message, 'check your account balance and add funds at ' \
                                 'https://platform.deepseek.com/top_up')
      when 429
        format_solution(message, 'pace your requests reasonably. Consider temporarily ' \
                                 'switching to alternative LLM service providers if needed.')
      when 500, 502, 503, 504
        format_solution(message, 'retry your request after a brief wait and contact ' \
                                 'support if the issue persists.')
      else
        "#{message} Please try again."
      end
    end


    def format_solution(message, solution)
      "#{message} Please #{solution}"
    end


    def safe_json_parse(string)
      JSON.parse string
    rescue JSON::ParserError
      nil
    end


    def extract_from_json_message(exception)
      response = safe_json_parse exception.message
      return unless response.is_a?(Hash) && response['error']

      error = response['error']
      {
        code:    error['code'],
        message: error['message'],
        type:    error['type'],
        param:   error['param'],
        status:  error['status']
      }.compact
    end


    def extract_from_faraday_response(exception)
      return unless exception.respond_to?(:response) && exception.response.is_a?(Hash)

      body = exception.response[:body]
      error_response = safe_json_parse body.to_s
      return unless error_response.is_a?(Hash) && error_response['error']

      error = error_response['error']
      {
        code:    error['code'],
        message: error['message'],
        type:    error['type'],
        param:   error['param'],
        status:  error['status']
      }.compact
    end


    def extract_basic_error_info(exception)
      {
        message: exception.message,
        type:    exception.class.name
      }
    end


    def extract_basic_error_info_from_string(response_body)
      return {} unless response_body.is_a? String

      response_body.include?('error') ? { 'message' => response_body } : {}
    end
  end
end
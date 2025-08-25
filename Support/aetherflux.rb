# frozen_string_literal: true

class String
  def truncate(max_length, omission = '...')
    if length > max_length
      truncated_string = self[0...(max_length - omission.length)]
      truncated_string += omission
      truncated_string
    else
      self
    end
  end
end

# Support/aetherflux.rb
require_relative 'coniunctio'
require_relative 'oracle'
require_relative 'scriptorium'



# Real-time streaming handler for WebSocket responses
# This ensures status updates appear immediately during AI tool execution
class Aetherflux
  class << self
    def channel_oracle_divination(params, tools:, context: nil)
      # Start status updates immediately
      msg_uuid = HorologiumAeternum.divination 'Initializing astral connection...'

      # Build context
      enhanced_params = params.merge(context: context) if context
      ctx = Coniunctio.build params

      # Process with real-time streaming and restart handling
      begin
        answer, arts, tool_results =
          Oracle.divination(params[:prompt], ctx, tools:, msg_uuid:) do |name, args|
            puts '[AETHER FLUX][CHANNEL ORACLE DIVINATION]: ' \
                 "TRY HANDLE TOOL=#{name}, ARGS=#{args.inspect.truncate 200}"
            result = tools.handle({ 'tool' => name, 'args' => args })
            puts "[AETHER FLUX][CHANNEL ORACLE DIVINATION]: TOOL RESULT=#{result}"
            sleep 0.1
            result
          end
      rescue Oracle::RestartException => e
        HorologiumAeternum.thinking 'Restarting oracle process...'
        retry
      end

      raise StandardError, answer unless answer.is_a? String

      logs = []

      html = Scriptorium.html_with_syntax_highlight answer.to_s

      HorologiumAeternum.oracle_revelation answer.to_s unless answer.to_s.strip.empty?

      tool_count = tool_results.length

      HorologiumAeternum.completed Scriptorium.html(
        "🎯 Response ready with **#{tool_count}** tools executed"
      )
      
      Mnemosyne.record params, answer if params[:record]

      # Return proper status structure for task engine (same format as conjuration)
      {
        status: :success,
        response: {
          reasoning:    arts[:reasoning],
          answer:       answer,
          html:         html,
          patch:        arts[:patch],
          tasks:        arts[:tasks],
          tools:        arts[:tools],
          tool_results: tool_results,
          logs:         logs,
          next_step:    arts[:next_step]
        }
      }
    rescue TypeError => e
      puts "[AETHER FLUX][TYPE ERROR]: #{e.inspect}"
      {
        status: :failure,
        response: "Type error: #{e.full_message || e.message}"
      }
    rescue StandardError => e
      error_message = e.message.to_s
      puts "[AETHER FLUX][ERROR]: #{e.inspect}"
      Mnemosyne.record params, "Error: #{error_message}" if params[:record]
      
      # Classify errors for better handling in task engine
      # Prioritize specific error types over generic text matching to prevent misclassification
      status = if e.is_a?(Timeout::Error)
                 :timeout  # Genuine timeout errors only
               elsif error_message.include?("maximum context length") ||
                     error_message.include?("context length") ||
                     (error_message.include?("invalid_request_error") &&
                      error_message.include?("context"))
                 :context_length_error
               elsif error_message.include?("rate limit") ||
                     error_message.include?("rate_limit") ||
                     error_message.include?("rate_limit_exceeded")
                 :rate_limit_error
               elsif error_message.include?("network") ||
                     error_message.include?("connection") ||
                     e.is_a?(Net::OpenTimeout) ||
                     e.is_a?(Net::ReadTimeout)
                 :network_error
               elsif error_message.include?("read timeout") ||
                     error_message.include?("Read timed out")
                 :network_error  # Handle specific timeout messages
               else
                 :failure
               end
      
      {
        status: status,
        response: "#{status.to_s.humanize}: #{error_message}"
      }
    end


    def channel_oracle_conjuration(params, tools:, context: nil)
      puts "[AETHER FLUX][ORACLE CONJURATION]: #{params.inspect} tools=#{tools.schema}"
      msg_uuid = HorologiumAeternum.divination 'Initializing astral connection...'
      
      # Pass through context to the oracle
      enhanced_params = params.merge(context: context) if context
      ctx = Coniunctio.build enhanced_params || params
      # Handle restarts during conjuration
      begin
        answer, arts, tool_results =
          Oracle.conjuration(params[:prompt], ctx, tools:, msg_uuid:) do |name, args|
            puts "[AETHER FLUX][CHANNEL ORACLE CONJURATION]: TRY HANDLE TOOL=#{name}"
            puts "[AETHER FLUX][CHANNEL ORACLE CONJURATION]: ARGS=#{args.inspect}"
            result = tools.handle({ 'tool' => name, 'args' => args })
            puts "[AETHER FLUX][CHANNEL ORACLE CONJURATION]: TOOL RESULT=#{result}"
            sleep 0.1
            result
          end
      rescue Oracle::RestartException => e
        HorologiumAeternum.thinking 'Restarting oracle process due to temperature change...'
        retry
      end

      logs = []
      arts ||= {}
      tool_results ||= []

      html = Scriptorium.html_with_syntax_highlight answer.to_s
      # Mnemosyne.record(params, answer) if params['record']

      HorologiumAeternum.oracle_revelation answer.to_s unless answer.to_s.strip.empty?

      tool_count = tool_results.length

      HorologiumAeternum.completed "🎯 Response ready with **#{tool_count}** tools executed"

      # Return proper status structure for task engine
      {
        status: :success,
        response: {
          reasoning:    arts[:reasoning],
          answer:       answer,
          html:         html,
          patch:        arts[:patch],
          tasks:        arts[:tasks],
          tools:        arts[:tools],
          tool_results: tool_results,
          logs:         logs,
          next_step:    arts[:next_step]
        }
      }
    rescue StandardError => e
      puts "[AETHER FLUX][CHANNEL ORACLE CONJURATION][ERROR]: #{e.inspect.truncate 200}"
      HorologiumAeternum.server_error "Oracle reasoning stream failed: #{e.message}"
      { 
        status: :failure,
        response: "Oracle reasoning stream failed: #{e.message}"
      }
    ensure
      Mnemosyne.record params, answer if params[:record]
    end
  end
end
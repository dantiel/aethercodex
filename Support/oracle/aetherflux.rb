# frozen_string_literal: true

require_relative '../instrumentarium/scriptorium'
require_relative '../instrumentarium/metaprogramming_utils'
require_relative '../instrumentarium/hermetic_execution_domain'
require_relative 'coniunctio'
require_relative 'oracle'

using MetaprogrammingUtils

# Aetherflux channel for oracle communication with functional purity
class Aetherflux
  class << self
    def channel_oracle_divination(params, tools:, context: nil, **kwargs)
      msg_uuid = HorologiumAeternum.divination 'Initializing astral connection...'
      # Merge any additional keyword arguments into the context
      merged_context = context ? context.merge(kwargs) : kwargs
      ctx = Coniunctio.build(params.merge(context: merged_context))

      begin
        answer, arts, tool_results = Oracle.divination(params[:prompt], ctx, tools:,
msg_uuid:) do |name, args, tool_ctx|
          tools.handle tool: name, args:, context: tool_ctx
        end
      rescue Oracle::RestartException
        HorologiumAeternum.thinking 'Restarting oracle process...'
        retry
      end

      raise StandardError, answer unless answer.is_a? String

      html = Scriptorium.html_with_syntax_highlight answer.to_s
      HorologiumAeternum.oracle_revelation answer.to_s unless answer.to_s.strip.empty?
      HorologiumAeternum.completed Scriptorium.html("🎯 Response ready with **#{tool_results.length}** tools executed")
      Mnemosyne.record params, answer if params[:record]

      {
        status:   :success,
        response: {
          reasoning:    arts[:reasoning],
          answer:       answer,
          html:         html,
          patch:        arts[:patch],
          tasks:        arts[:tasks],
          tools:        arts[:tools],
          tool_results: tool_results,
          logs:         [],
          next_step:    arts[:next_step]
        }
      }
    rescue TypeError => e
      { status: :failure, response: "Type error: #{e.full_message || e.message}" }
    rescue HermeticExecutionDomain::TimeoutError => e
      { status: :timeout, response: "Timeout: #{e.message.truncate 100}" }
    rescue HermeticExecutionDomain::RateLimitError => e
      { status: :rate_limit_error, response: "Rate limit: #{e.message.truncate 100}" }
    rescue HermeticExecutionDomain::NetworkError => e
      { status: :network_error, response: "Network error: #{e.message.truncate 100}" }
    rescue HermeticExecutionDomain::ContextLengthError => e
      { status:   :context_length_error,
        response: "Context length exceeded: #{e.message.truncate 100}" }
    rescue HermeticExecutionDomain::ToolExecutionError => e
      { status: :failure, response: "Tool execution error: #{e.message.truncate 100}" }
    rescue StandardError => e
      error_message = e.message.to_s
      Mnemosyne.record params, "Error: #{error_message}" if params[:record]

      status = classify_error error_message, e
      { status: status, response: "#{status.to_s.humanize}: #{error_message}", backtrace: e.backtrace }
    end


    def channel_oracle_conjuration(params, tools:, context: nil, timeout: nil)
      msg_uuid = HorologiumAeternum.divination 'Initializing astral connection...'
      ctx = Coniunctio.build(context ? params.merge(context: context) : params)

      begin
        # For reasoning, we must use empty tools array to enable DeepSeek advanced reasoning
        # The reasoning model cannot execute tools, so we provide empty array
        # This is handled automatically in Conduit based on model detection
        answer, arts, tool_results = Oracle.conjuration(params[:prompt], ctx, tools: tools,
msg_uuid:) do |name, args, tool_ctx|
          # Tool execution is handled normally, but tools will be filtered in Conduit
          # for reasoning models to enable advanced reasoning capabilities
          if tools.respond_to?(:handle)
            tools.handle tool: name, args:, context: tool_ctx, timeout: timeout
          else
            { error: "No tools available for execution" }
          end
        end
      rescue Oracle::RestartException
        HorologiumAeternum.thinking 'Restarting oracle process due to temperature change...'
        retry
      end

      html = Scriptorium.html_with_syntax_highlight answer.to_s
      # HorologiumAeternum.oracle_revelation answer.to_s unless answer.to_s.strip.empty?
      # HorologiumAeternum.completed "🎯 Response ready with **#{tool_results.length}** tools executed"

      {
        status:   :success,
        response: {
          reasoning:    arts[:reasoning],
          answer:       answer,
          html:         html,
          patch:        arts[:patch],
          tasks:        arts[:tasks],
          tools:        arts[:tools],
          tool_results: tool_results,
          logs:         [],
          next_step:    arts[:next_step]
        }
      }
    rescue StandardError => e
      HorologiumAeternum.server_error "Oracle reasoning stream failed: #{e.message}"
      { status: :failure, response: "Oracle reasoning stream failed: #{e.message}" }
    ensure
      Mnemosyne.record params, answer if params[:record]
    end

    private

    def classify_error(error_message, error)
      if error.is_a? Timeout::Error
        :timeout
      elsif error_message.include?('maximum context length') ||
            error_message.include?('context length') ||
            (error_message.include?('invalid_request_error') &&
             error_message.include?('context'))

        :context_length_error

      elsif error_message.include?('rate limit') ||
            error_message.include?('rate_limit') ||
            error_message.include?('rate_limit_exceeded')

        :rate_limit_error

      elsif error_message.include?('network') ||
            error_message.include?('connection') ||
            error.is_a?(Net::OpenTimeout) ||
            error.is_a?(Net::ReadTimeout) ||
            error_message.include?('read timeout') ||
            error_message.include?('Read timed out')

        :network_error

      else
        :failure
      end
    end
  end
end
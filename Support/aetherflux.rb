# frozen_string_literal: true

# Support/aetherflux.rb
require_relative 'arcanum'
require_relative 'oracle'

# Real-time streaming handler for WebSocket responses
# This ensures status updates appear immediately during AI tool execution
class Aetherflux
  class << self
    def channel_oracle_divination(params, websocket, tools:)
      # Ensure HorologiumAeternum is connected to this WebSocket
      HorologiumAeternum.set_websocket websocket unless websocket.nil?

      # Start status updates immediately
      msg_uuid = HorologiumAeternum.divination 'Initializing astral connection...'

      # Build context
      ctx = Arcanum.build params

      # Process with real-time streaming and restart handling
      begin
        answer, arts, tool_results =
          Oracle.divination(params[:prompt], ctx, tools:, msg_uuid:) do |name, args|
            puts '[AETHER FLUX][CHANNEL ORACLE DIVINATION]: ' \
                 "TRY HANDLE TOOL=#{name}, ARGS=#{args.inspect}"
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

      {
        method: 'answer',
        result: {
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
      { method:    'answer',
        result:    'error',
        error:     e.full_message || e.message,
        backtrace: e.backtrace }
    rescue StandardError => e
      puts "[AETHER FLUX][ERROR]: #{e.inspect}"
      Mnemosyne.record params, "Error: #{e.message || e.message[:error]}" if params[:record]
      { method: 'answer', result: 'error', error: e.message || e.message[:error] }
    end


    def channel_oracle_conjuration(params, tools:, context: nil)
      puts "[AETHER FLUX][ORACLE CONJURATION]: #{params.inspect} tools=#{tools.schema}"
      msg_uuid = HorologiumAeternum.divination 'Initializing astral connection...'
      
      ctx = Arcanum.build params
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
      puts "[AETHER FLUX][CHANNEL ORACLE CONJURATION][ERROR]: #{e.inspect}"
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

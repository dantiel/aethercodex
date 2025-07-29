# frozen_string_literal: true

LOG = File.open(File.expand_path('../../.tm-ai/gatekeeper.log', __FILE__), 'a')
LOG.sync = true
$stdout = $stderr = LOG

require 'json'; require 'yaml'
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('Gemfile', __dir__)
begin
  require 'bundler/setup'
  Bundler.require(:default) if Bundler.respond_to?(:require)
rescue LoadError, NoMethodError
end

require 'sinatra'
require 'faye/websocket'
require 'thin'
require_relative 'mnemosyne'
require_relative 'file_manager'
require_relative 'live_status'
require_relative 'context_builder'
require_relative 'ai_client'
require_relative 'command_executor'
require_relative 'toolbox'
require_relative 'markdown_renderer'
require_relative 'streaming_handler'


CFG_PATH = File.expand_path('../.deepseekrc', __FILE__)
CFG = File.exist?(CFG_PATH) ? YAML.load_file(CFG_PATH) : {}
PORT = (ENV['AETHER_PORT'] || CFG['port'] || 4567).to_i


Faye::WebSocket.load_adapter('thin')
set :server, 'thin'
set :port, PORT

# Daemon persistence protocol
if ARGV.include?('--daemon') || ENV['AETHER_DAEMON']
  Process.daemon(true, false)
  at_exit { File.delete(File.expand_path('../../.tm-ai/gatekeeper.pid', __FILE__)) rescue nil }
end

trap('TERM') { exit }


# Optional landing page not required if you inline HTML in command
get '/' do
  File.read(File.expand_path('ui/chamber.html', __dir__)) rescue 'OK'
end


# Simple HTTP API endpoint for command-line usage
# TODO not in use
post '/api' do
  content_type :json
  begin
    req = JSON.parse request.body.read
    res = handle_request req
    res.to_json
  rescue => e
    { method: 'error', result: { error: e.message, backtrace: e.backtrace } }.to_json
  end
end


get '/ws' do  
  puts "[WS] try open"
  
  last_pong = Time.now
  ws = Faye::WebSocket.new(request.env)

  ping_timer = EventMachine.add_periodic_timer(15) { 
    warn "💓"
    ws.send('💓') if ws
  } if defined? EventMachine
  last_pong = Time.now
  timeout_timer = EventMachine.add_periodic_timer(5) { ws.close if ws && (Time.now - last_pong) > 30 }

  ws.on :open do |_e|
    warn "[WS] open"
    warn "[WS] open #{ENV['TM_PROJECT_DIRECTORY']}"
    last_pong = Time.now
    LiveStatus.set_websocket(ws)
  end

  ws.on :error do |event|
    LiveStatus.server_error event.message
    warn "[WS] error #{event.message}"
    ws.close if ws
    ws = nil
  end

  ws.on :message do |event|
    begin
      if event.data == '💓'
        warn "ping received"
        last_pong = Time.now
      else
        req = JSON.parse(event.data)
      
        if req['method'] == 'askAI'
          Thread.new do
            begin
              warn "[WS] message: #{req['params'].inspect}"
            
              res = StreamingHandler.handle_askAI_streaming(req['params'], ws)
              ws.send res.to_json
            rescue => e
              warn "[WS][THREAD][ERROR]#{e.inspect}"
              ws.send({ method: 'error', result: { error: e.message, backtrace: e.backtrace } }.to_json)
            end
          end
        else
          res = handle_request req
          ws.send res.to_json
        end
      end
    rescue => e
      warn "[WS][ERROR] #{e.inspect}"
      ws.send({ method: 'error', result: { error: e.message, backtrace: e.backtrace } }.to_json)
    end
    
    warn '[WS] message done'
  end
  
  ws.on :close do |event|
    warn "[WS] closed code=#{event.code} reason=#{event.reason}"
    EventMachine.cancel_timer(ping_timer) if ping_timer
    EventMachine.cancel_timer(timeout_timer) if timeout_timer
    LiveStatus.set_websocket nil
    ws = nil
  end

  ws.rack_response
end


# ---- Core dispatcher ----
def handle_request(req)
  case req['method']
  when 'askAI'      then do_ask req['params']
  when 'tool'       then do_tool req['params']
  when 'complete'   then do_complete req['params']
  when 'manageTask' then do_tasks req['params']
  when 'readFile'   then do_read req['params']
  when 'patchFile'  then do_patch req['params']
  when 'runCommand' then do_run req['params']
  when 'error'      then { method: 'error', result: { error: "Internal server error" } }
  else { method: 'error', result: { error: "Unknown method: #{req['method']}" } }
  end
end


def do_ask(p)
  LiveStatus.thinking('Initializing astral connection...')
  ctx = ContextBuilder.build p
    
  # Enhanced streaming callback for real-time tool feedback
  answer, arts, tool_results = 
    AIClient.ask_with_tools(p['prompt'], ctx) { |name, args| 
      # LiveStatus.tool_starting(name, args)
      # LiveStatus.processing("Executing #{name}...")
      result = Toolbox.handle({ 'tool' => name, 'args' => args })
      # LiveStatus.tool_completed(name, result)
      
      # Brief pause to ensure UI updates are processed
      sleep 0.05
      result }

  LiveStatus.ai_response("Processing response artifacts...")
  
  logs = []
  (arts[:prelude] || []).each { |t| 
    logs << { type: 'prelude', data: MarkdownRenderer.html_with_syntax_highlight(t.to_s) } }
  tool_results.each do |r|
    if r[:result].is_a?(Hash) && r[:result][:say]
      logs << { type: 'say', data: r[:result][:say] }
    end
  end
  
  html = MarkdownRenderer.html_with_syntax_highlight(answer.to_s)
  Mnemosyne.record(p, answer) if p['record']

  tool_count = tool_results.length
  LiveStatus.completed("Response ready with #{tool_count} tools executed")

  { method: 'answer',
    result: { answer: answer, 
              html: html, 
              patch: arts[:patch], 
              tasks: arts[:tasks],
              tools: arts[:tools], 
              tool_results: tool_results, 
              logs: logs,
              next_step: arts[:next_step] } }
end


def do_tool(p)
  result = Toolbox.handle(p)
  { method: 'toolResult', result: result }
end


def do_complete(p)
  ctx = ContextBuilder.build p
  snippet = AIClient.complete(ctx)
  { method: 'completion', result: { snippet: snippet } }
end


def do_tasks(p)
  { method: 'tasks', result: { ok: true, msg: 'Task system TBD' } }
end


def do_read(p)
  result = FileManager.read(p['path'], p['range'] || [])
  { method: 'fileContent', result: result }
end


def do_patch(p)
  result = FileManager.apply_patch(p['path'], p['diff'])
  { method: 'patchResult', result: result }
end


def do_run(p)
  result = CommandExecutor.run(p['cmd'])
  { method: 'commandResult', result: result }
end

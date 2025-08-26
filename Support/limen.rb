# frozen_string_literal: true

LOG = File.open File.expand_path('../.tm-ai/limen.log', __dir__), 'a'
LOG.sync = true
$stdout = $stderr = LOG

require 'json'
require 'yaml'
ENV['BUNDLE_GEMFILE'] ||= File.expand_path 'Gemfile', __dir__
begin
  require 'bundler/setup'
  Bundler.require :default if Bundler.respond_to? :require
rescue LoadError, NoMethodError
end

require 'sinatra'
require 'faye/websocket'
require 'thin'
require_relative 'metaprogramming_utils'
require_relative 'mnemosyne'
require_relative 'argonaut'
require_relative 'horologium_aeternum'
require_relative 'coniunctio'
require_relative 'oracle'
require_relative 'verbum'
require_relative 'prima_materia'
require_relative 'scriptorium'
require_relative 'aetherflux'
require_relative 'instrumenta'



CFG_PATH = File.expand_path '.aethercodex', __dir__
CFG = File.exist?(CFG_PATH) ? YAML.load_file(CFG_PATH) : {}
PORT = (ENV['AETHER_PORT'] || CFG['port'] || 4567).to_i


Faye::WebSocket.load_adapter 'thin'
set :server, 'thin'
set :port, PORT

# Daemon persistence protocol
if ARGV.include?('--daemon') || ENV['AETHER_DAEMON']
  Process.daemon true, false
  at_exit do
    File.delete File.expand_path('../.tm-ai/limen.pid', __dir__)
  rescue StandardError
    nil
  end
end

trap('TERM') { exit }


# Optional landing page not required if you inline HTML in command
get '/' do
  File.read File.expand_path('ui/chamber.html', __dir__)
rescue StandardError
  'OK'
end


# Simple HTTP API endpoint for command-line usage
post '/api' do
  content_type :json
  begin
    req = JSON.parse request.body.read
    res = handle_request req
    res.to_json
  rescue StandardError => e
    { method: 'error', result: { error: e.message, backtrace: e.backtrace } }.to_json
  end
end


get '/ws' do
  puts '[WS] try open'

  last_pong = Time.now
  ws = Faye::WebSocket.new request.env
  HorologiumAeternum.set_websocket ws

  if defined? EventMachine
    ping_timer = EventMachine.add_periodic_timer 20 do
      warn '💓->'
      ws&.send '💓'
    end
  end

  timeout_timer = EventMachine.add_periodic_timer 5 do
    ws.close if ws && 42 < (Time.now - last_pong)
  end

  ws.on :open do |_e|
    warn '[WS] open'
    warn "[WS] open #{ENV.fetch 'TM_PROJECT_DIRECTORY', nil}"
    last_pong = Time.now
  end

  ws.on :error do |event|
    HorologiumAeternum.server_error event.message
    warn "[WS] error #{event.message}"
    ws&.close
    ws = nil
  end

  ws.on :message do |event|
    begin
      case event.data
      when '💓'
        warn 'ping received'
        last_pong = Time.now
      else
        req = JSON.parse event.data
        case req['method']
        when 'history'
          HorologiumAeternum.history Mnemosyne.fetch_history(limit: 20)
        when 'askAI'
          startThinkingThread ws, req
        when 'stopThinking'
          warn 'stopThinking'
          stopThinkingThread true
        end
      end
    rescue StandardError => e
      warn "[WS][ERROR] #{e.inspect}"
      ws.send({ method: 'error', result: { error: e.message, backtrace: e.backtrace } }.to_json)
    end

    warn '[WS] message done'
  end

  ws.on :close do |event|
    warn "[WS] closed code=#{event.code} reason=#{event.reason}"
    EventMachine.cancel_timer ping_timer if ping_timer
    EventMachine.cancel_timer timeout_timer if timeout_timer
    HorologiumAeternum.set_websocket nil
    ws = nil
  end

  ws.rack_response
end


def startThinkingThread(ws, req)
  stopThinkingThread if @ask_thread

  @ask_thread = Thread.new do
    warn "[WS] message: #{req['params'].inspect}"
    
    res = Aetherflux.channel_oracle_divination( req['params'].transform_keys!(&:to_sym), tools: Instrumenta)
    raise res[:error] if 'error' == res[:result]

    # warn "[WS][DEBUG] #{res.inspect}"
    ws.send res.to_json
  rescue StandardError => e
    warn "[WS][THREAD][ERROR]#{e.inspect}"
    ws.send({ method: 'error', result: { error: e.message, backtrace: e.backtrace } }.to_json)
  end
end


def stopThinkingThread(send_msg = false)
  return if @ask_thread.nil?

  warn 'Thinking cancelled.'
  HorologiumAeternum.system_message 'Thinking cancelled.' if send_msg
  @ask_thread.kill
  @ask_thread = nil
end


# ---- Core dispatcher ----
def handle_request(req)
  puts "handle_request #{req.inspect}"
  case req['method']
  when 'askAI'      then do_ask req['params']
  when 'attach'     then do_attach req['params']
  when 'tool'       then do_tool req['params']
  when 'complete'   then do_complete req['params']
  when 'manageTask' then do_tasks req['params']
  when 'readFile'   then do_read req['params']
  when 'patchFile'  then do_patch req['params']
  when 'runCommand' then do_run req['params']
  when 'error'      then { method: 'error', result: { error: 'Internal server error' } }
  else { method: 'error', result: { error: "Unknown method: #{req['method']}" } }
  end
end


def do_ask(p)
  uuid = HorologiumAeternum.thinking 'Initializing astral connection...'
  ctx = Coniunctio.build p

  # Enhanced streaming callback for real-time tool feedback
  answer, arts, tool_results =
    Oracle.divination p['prompt'], ctx do |name, args|
    # HorologiumAeternum.tool_starting(name, args)
    # HorologiumAeternum.processing("Executing #{name}...")
    result = PrimaMateria.handle({ 'tool' => name, 'args' => args })
    # HorologiumAeternum.tool_completed(name, result)

    # Brief pause to ensure UI updates are processed
    sleep 0.05
    result
  end

  HorologiumAeternum.oracle_revelation 'Processing response artifacts...'

  logs = (arts[:prelude] || []).map do |t|
    { type: 'prelude', data: Scriptorium.html_with_syntax_highlight(t.to_s) }
  end
  tool_results.each do |r|
    logs << { type: 'say', data: r[:result][:say] } if r[:result].is_a?(Hash) && r[:result][:say]
  end

  html = Scriptorium.html_with_syntax_highlight answer.to_s
  Mnemosyne.record p, answer if p['record']

  tool_count = tool_results.length
  HorologiumAeternum.completed "Response ready with #{tool_count} tools executed"

  { method: 'answer',
    result: { answer:       answer,
              html:         html,
              patch:        arts[:patch],
              tasks:        arts[:tasks],
              tools:        arts[:tools],
              tool_results: tool_results,
              logs:         logs,
              next_step:    arts[:next_step] } }
end


def do_tool(p)
  result = PrimaMateria.handle p
  { method: 'toolResult', result: result }
end


def do_attach(p)
  puts "handle attachments #{p.inspect}"
  attachment_data = p.transform_keys!(&:to_sym)
  file = Argonaut.relative_path attachment_data[:file]
  puts "Argonaut.relative_path #{file}"
  file_content = if file and !attachment_data[:selection]
                   begin
                     Argonaut.read file
                   rescue StandardError => e
                     puts "Failed to read file: #{e.message}"
                     nil
                   end
                 end

  selection = attachment_data[:selection]
  # selection = selection[2, selection.length - 3] || ''
  # selection = "\"#{selection.gsub("\"","\\\"").gsub("\\\'","\'")}\"".undump

  attachment_data.merge! content: file_content,
                         lines: ((file_content || selection).count '\n'),
                         file: file,
                         selection: selection

  HorologiumAeternum.attach("Received attachment: #{attachment_data.inspect}",
                            **attachment_data)
  { method: 'attachment', result: { ok: true, **attachment_data } }
rescue StandardError => e
  puts "ERROR: #{e} , #{p.transform_keys(&:to_sym)}"
  { method: 'error', result: { error: e.message } }
end


def do_complete(p)
  ctx = Coniunctio.build p
  snippet = Oracle.complete ctx
  { method: 'completion', result: { snippet: snippet } }
end


def do_tasks(_p)
  { method: 'tasks', result: { ok: true, msg: 'Task system TBD' } }
end


def do_read(p)
  puts "DO_READ #{p['path']}"

  path = Argonaut.relative_path p['path']
  puts "PATHPTAH #{path}"

  result = Argonaut.readRange(path, p['range'] || [])
  { method: 'fileContent', result: result }
end


def do_patch(p)
  result = Argonaut.apply_patch p['path'], p['diff']
  { method: 'patchResult', result: result }
end


def do_run(p)
  result = Verbum.run p['cmd']
  { method: 'commandResult', result: result }
end
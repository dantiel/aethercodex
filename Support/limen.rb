# frozen_string_literal: true

require_relative 'config'
LOG = File.open CONFIG.log_file_path, 'a'
LOG.sync = true
$stdout = $stderr = LOG

require 'json'
ENV['BUNDLE_GEMFILE'] ||= File.expand_path 'Gemfile', __dir__
begin
  require 'bundler/setup'
  Bundler.require :default if Bundler.respond_to? :require
rescue LoadError, NoMethodError
end

require 'sinatra'
require 'faye/websocket'
require 'thin'
require_relative 'instrumentarium/metaprogramming_utils'
require_relative 'instrumentarium/horologium_aeternum'
require_relative 'instrumentarium/prima_materia'
require_relative 'instrumentarium/scriptorium'
require_relative 'instrumentarium/instrumenta'
require_relative 'instrumentarium/verbum'
require_relative 'mnemosyne/mnemosyne'
require_relative 'argonaut/argonaut'
require_relative 'oracle/coniunctio'
require_relative 'oracle/oracle'
require_relative 'oracle/aetherflux'
require_relative 'markdown_preview'
require_relative 'config'



Faye::WebSocket.load_adapter 'thin'
set :server, 'thin'
set :port, ENV['AETHER_PORT'] || CONFIG.port
set :bind, '0.0.0.0'

# Daemon persistence protocol
if ARGV.include?('--daemon') || ENV['AETHER_DAEMON']
  Process.daemon true, false
  at_exit do
    File.delete CONFIG.pid_file_path
  rescue StandardError
    nil
  end
end

trap('TERM') { exit }


# Optional landing page not required if you inline HTML in command
get '/' do
  File.read File.expand_path('pythia/chamber.html', __dir__)
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
  puts '[LIMEN][WS]: try open'

  last_pong = Time.now
  ws = Faye::WebSocket.new request.env
  HorologiumAeternum.set_websocket ws

  if defined? EventMachine
    ping_timer = EventMachine.add_periodic_timer 20 do
      # warn '[LIMEN][WS]: 💓->'
      ws&.send '💓'
    end
  end

  timeout_timer = EventMachine.add_periodic_timer 5 do
    ws.close if ws && 42 < (Time.now - last_pong)
  end

  ws.on :open do |_e|
    warn '[LIMEN][WS]: open'
    warn "[LIMEN][WS]: open #{ENV.fetch 'TM_PROJECT_DIRECTORY', nil}"
    last_pong = Time.now
  end

  ws.on :error do |event|
    HorologiumAeternum.server_error event.message
    warn "[LIMEN][WS]: error #{event.message}"
    ws&.close
    ws = nil
  end

  ws.on :message do |event|
    begin
      case event.data
      when '💓'
        # warn '[LIMEN][WS]: ping received'
        last_pong = Time.now
      else
        req = (JSON.parse event.data).deep_symbolize_keys
        
        case req[:method].to_sym
        when :history
          HorologiumAeternum.history Mnemosyne.fetch_history(limit: 20)
        when :previewMarkdown
          do_preview_markdown req[:params]
        when :askAI
          startThinkingThread ws, req
        when :stopThinking
          stopThinkingThread true
        end
      end
    rescue StandardError => e
      warn "[LIMEN][WS][ERROR]: #{e.inspect}"
      ws.send({ method: 'error', result: { error: e.message, backtrace: e.backtrace } }.to_json)
    end

    # warn '[LIMEN][WS]: message done'
  end

  ws.on :close do |event|
    warn "[LIMEN][WS]: closed code=#{event.code} reason=#{event.reason}"
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
    params = req[:params]
    warn "[LIMEN][WS]: message: #{params.inspect}"
    
    res = Aetherflux.channel_oracle_divination(params, tools: Instrumenta)
    raise res[:error] if 'error' == res[:result]

    # warn "[WS][DEBUG] #{res.inspect}"
    ws.send res.to_json
  rescue StandardError => e
    warn "[LIMEN][WS][THREAD][ERROR]: #{e.inspect}"
    ws.send({ method: 'error', result: { error: e.message, backtrace: e.backtrace } }.to_json)
  end
end


def stopThinkingThread(send_msg = false)
  return if @ask_thread.nil?

  warn '[LIMEN]: Thinking cancelled.'
  HorologiumAeternum.system_message 'Thinking cancelled.' if send_msg
  @ask_thread.kill
  @ask_thread = nil
end


# ---- Core dispatcher ----
def handle_request(req)
  req = req.deep_symbolize_keys
  puts "[LIMEN][HANDLE_REQUEST]: #{req.inspect}"
  case req[:method].to_sym
  when :askAI           then do_ask req[:params]
  when :attach          then do_attach req[:params]
  when :tool            then do_tool req[:params]
  when :complete        then do_complete req[:params]
  when :manageTask      then do_tasks req[:params]
  when :readFile        then do_read req[:params]
  when :patchFile       then do_patch req[:params]
  when :runCommand      then do_run req[:params]
  when :previewMarkdown then do_preview_markdown req[:params]
  when :error           then { method: 'error', result: { error: 'Internal server error' } }
  else
    error = "Unknown method: #{req[:method]}"
    puts "[LIMEN][HANDLE_REQUEST][ERROR]: #{error}. #{req.inspect}"
    { method: 'error', result: { error: } }
  end
end


def do_ask(p)
  uuid = HorologiumAeternum.thinking 'Initializing astral connection...'
  
  # Handle both old single attachment format and new multiple attachments format
  attachments = p['attachments'] || []
  if p['file'] && attachments.empty?
    # Convert old format to new format for backward compatibility
    attachments = [{
      file: p['file'],
      selection: p['selection'],
      line: p['line'],
      column: p['column'],
      selection_range: p['selection_range']
    }]
  end
  
  # Send each attachment to frontend for preview
  attachments.each do |attachment|
    do_attach(attachment.transform_keys(&:to_sym))
  end
  
  ctx = Coniunctio.build p.merge(attachments: attachments)

  # Enhanced streaming callback for real-time tool feedback
  answer, arts, tool_results =
    Oracle.divination p['prompt'], ctx do |name, args|
    # HorologiumAeternum.tool_starting(name, args)
    # HorologiumAeternum.processing("Executing #{name}...")
    result = PrimaMateria.handle(tool: name, args:)
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
  
  # Record the entry with tool calls if recording is enabled
  if p['record']
    Mnemosyne.record(
      prompt: p['prompt'],
      answer: answer,
      tags: p['tags'],
      file: p['file'],
      attachments: attachments,
      tool_calls: ToolCallRecorder.get_current_entry_tool_calls
    )
  end

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


def do_tool(tool_data)
  result = Instrumenta.handle **tool_data
  { method: 'toolResult', result: result }
end


def do_attach(attachment_data)
  puts "handle attachments #{attachment_data.inspect}"
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
                         lines: ((file_content || selection).count "\n"),
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


def do_preview_markdown(p)
  file_path = p[:file_path]
  
  full_path = File.join Argonaut.project_root, file_path
  
  unless File.exist? full_path
    return {
      method: 'previewMarkdown',
      result: {
        error: "File not found: #{full_path}",
        content: "File not found: #{full_path}",
        html: "<p>File not found: #{full_path}</p>"
      }
    }
  end
  
  # Read the markdown file
  content = File.read full_path
  
  # Render markdown to HTML using scriptorium basic renderer (unescaped HTML)
  html = AetherCodexMarkdownPreview.convert_to_html content
  
  # Extract title from first heading or use filename
  title = File.basename full_path, '.md'
  if content.match /^#+\s+(.+)$/
    title = $1.strip
  end
  
  {
    method: 'previewMarkdown',
    result: {
      content: content,
      html: html,
      title: title,
      file_path: full_path
    }
  }
end


def do_run(p)
  result = Verbum.run p['cmd']
  { method: 'commandResult', result: result }
end
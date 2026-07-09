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
require_relative 'oracle/continuum_weaver'
puts "FIM Completion loaded successfully" if defined?(Rails)
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




# Hermetic pair programming live update endpoint
post '/hermetic_live_update' do
  content_type :json
  begin
    payload = JSON.parse(request.body.read)
    
    # Process the live update
    result = process_hermetic_live_update(payload)
    
    { method: 'hermetic_live_update', result: result }.to_json
  rescue StandardError => e
    { method: 'error', result: { error: e.message } }.to_json
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
        when :resumeThinking
          resumeThinkingThread ws, req
        when :showStepResult
          task_id = req[:params][:task_id]
          step_number = req[:params][:step_number]
          result = get_step_result(task_id, step_number)
          ws.send(result.to_json)
        when :manageTask
          result = do_tasks(req[:params])
          ws.send(result.to_json)
        when :userResponse
          uuid = req[:params][:uuid]
          response = req[:params][:response]
          HorologiumAeternum.receive_user_response(uuid, response)
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

  @ask_ws = ws  # Store for stop/resume access
  @ask_thread = Thread.new do
    params = req[:params]
    warn "[LIMEN][WS]: message: #{params.inspect}"
    
    # Clear any previous pause state
    Thread.current[:paused] = false
    Thread.current[:pause_state] = nil
    
    res = Aetherflux.channel_oracle_divination(params, tools: Instrumenta)
    
    # Don't send result if paused — the resume will handle it
    unless Thread.current[:paused]
      raise res[:error] if 'error' == res[:result]
      # Wrap in 'answer' method so the frontend renders tool times, thinking time, etc.
      ws.send({ method: 'answer', result: res[:response] }.to_json)
    end
  rescue StandardError => e
    warn "[LIMEN][WS][THREAD][ERROR]: #{e.inspect}"
    ws.send({ method: 'error', result: { error: e.message, backtrace: e.backtrace } }.to_json)
  ensure
    # Clear thread reference on normal completion — prevents stale
    # @ask_thread from triggering a phantom pause on next message
    @ask_thread = nil
    @ask_ws = nil
  end
end


def stopThinkingThread(send_msg = false)
  return if @ask_thread.nil?

  warn '[LIMEN]: Thinking paused.'
  
  # Set pause flag on the thread — the divination loop checks this
  @ask_thread[:paused] = true
  
  # Give it a brief moment to notice the flag
  sleep 0.1
  
  state_id = nil
  if @ask_thread[:pause_state]
    # Send paused event with saved state to frontend
    state = @ask_thread[:pause_state]
    state_id = save_pause_state(state)
    HorologiumAeternum.system_message "Thinking paused. Resume state saved as ##{state_id}."
  else
    # Thread didn't save state in time — still send paused event (resume will re-send last msg)
    HorologiumAeternum.system_message 'Thinking paused (no saved state — resume will re-send query).'
  end
  
  # Always send paused event so frontend shows resume button
  if @ask_ws
    warn "[LIMEN]: Sending paused event (state_id=#{state_id.inspect})"
    @ask_ws.send({ method: 'paused', result: { state_id: state_id, message: 'Thinking paused. Click Resume to continue.' } }.to_json)
  else
    warn '[LIMEN]: @ask_ws is nil — cannot send paused event!'
  end
  
  @ask_thread = nil
  @ask_ws = nil
end


def resumeThinkingThread(ws, req)
  params = req[:params]
  state_id = params[:state_id]
  
  if state_id
    state = get_pause_state(state_id)
    
    unless state
      ws.send({ method: 'error', result: { error: "Pause state ##{state_id} not found or expired." } }.to_json)
      return
    end
    
    warn "[LIMEN][WS]: Resuming thinking from state ##{state_id}"
  else
    warn "[LIMEN][WS]: Resuming thinking without saved state — re-sending original query"
    state = nil
  end
  
  @ask_thread = Thread.new do
    Thread.current[:paused] = false
    Thread.current[:pause_state] = nil
    
    # Continue divination with saved state (or fresh if none)
    res = Aetherflux.channel_oracle_divination(
      state&.dig(:params) || params,
      tools: Instrumenta,
      resume_state: state
    )
    
    unless Thread.current[:paused]
      raise res[:error] if 'error' == res[:result]
      ws.send({ method: 'answer', result: res[:response] }.to_json)
    end
  rescue StandardError => e
    warn "[LIMEN][WS][THREAD][ERROR]: #{e.inspect}"
    ws.send({ method: 'error', result: { error: e.message, backtrace: e.backtrace } }.to_json)
  end
end


# Store pause state for resume
$pause_states = {}
$pause_state_counter = 0
$pause_state_mutex = Mutex.new

def sanitize_messages_for_api(messages)
  messages.map do |msg|
    m = msg.dup
    content = m[:content]

    # DeepSeek API: content must be a string or list (array), never nil
    if content.nil?
      # Assistant messages with only tool_calls should omit content entirely
      if m[:role] == 'assistant' && m[:tool_calls]
        m.delete(:content)
      else
        m[:content] = ''
      end
    elsif content.is_a?(Array)
      # Array content is valid for the API (e.g. multimodal) — keep as-is
      m[:content] = content.map do |part|
        if part.is_a?(Hash)
          part[:text] = part[:text].to_s if part[:text].nil?
          part
        else
          part.to_s
        end
      end
    elsif content.is_a?(Hash)
      m[:content] = content[:text].to_s if content[:text]
      m[:content] ||= content.to_json
    elsif !content.is_a?(String)
      m[:content] = content.to_s
    end

    m[:tool_call_id] = m[:tool_call_id].to_s if m[:tool_call_id]
    m
  end
end

def save_pause_state(state)
  $pause_state_mutex.synchronize do
    $pause_state_counter += 1
    id = $pause_state_counter
    state[:messages] = sanitize_messages_for_api(state[:messages]) if state[:messages]
    $pause_states[id] = state
    $pause_states.delete($pause_state_counter - 10) if $pause_state_counter > 10
    id
  end
end

def get_pause_state(id)
  $pause_state_mutex.synchronize do
    $pause_states[id]
  end
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
  when :task            then do_tasks req[:params]
  when :readFile        then do_read req[:params]
  when :patchFile       then do_patch req[:params]
  when :runCommand      then do_run req[:params]
  when :previewMarkdown then do_preview_markdown req[:params]
  when :generate_proactive_suggestions then do_generate_proactive_suggestions req[:params]
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

  answer, arts, tool_results =
    Oracle.divination p['prompt'], ctx do |name, args|
    result = PrimaMateria.handle(tool: name, args:)
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


def do_tasks(p)
  puts "[DEBUG] do_tasks received: #{p.inspect}"
  action = p[:action]
  task_id = p[:id]
  
  puts "[DEBUG] action: #{action.inspect}, task_id: #{task_id.inspect}"
  
  case action.to_sym
  when :get_step_result
    step_number = p['step']
    get_step_result task_id, step_number
  when :get
    get_task task_id
  when :pause
    pause_task task_id
  when :resume
    resume_task task_id
  when :cancel
    cancel_task task_id
  when :list
    list_tasks
  when :execute
    execute_task task_id
  else
    { method: 'task', result: { ok: false, error: "Unknown task action: #{action}" } }
  end
end


private


def get_step_result(task_id, step_number)
  # Get task evaluation which includes step results
  evaluation = Instrumenta.handle(tool: :evaluate_task, args: { task_id: task_id })
  
  if evaluation[:error]
    return { method: 'step_result', result: { ok: false, error: "Task #{task_id} not found: #{evaluation[:error]}" } }
  end
  
  # Use raw step results (markdown) for AI vision
  step_results = evaluation[:step_results] || {}
  step_result = step_results[step_number.to_s]
  
  if step_result.nil?
    return { method: 'step_result', result: { ok: false, error: "Step #{step_number} not found in task #{task_id}" } }
  end
  
  { method: 'step_result', result: { ok: true, task_id: task_id, step: step_number, result: step_result } }
end


def get_task(task_id)
  # Get full task evaluation
  evaluation = Instrumenta.handle(tool: :evaluate_task, args: { task_id: task_id })
  
  if evaluation[:error]
    return { method: 'task', result: { ok: false, error: "Task #{task_id} not found: #{evaluation[:error]}" } }
  end
  
  # Debug: check what evaluation contains
  puts "[DEBUG] Evaluation keys: #{evaluation.keys.inspect}"
  puts "[DEBUG] Evaluation step_results: #{evaluation[:step_results].inspect}"
  puts "[DEBUG] Evaluation step_results type: #{evaluation[:step_results].class}"
  
  # Return task data with step_results at the top level for frontend compatibility
  task_data = evaluation[:task] || {}
  
  # Use formatted step results for HTML display
  step_results = evaluation[:formatted_step_results] || evaluation[:step_results] || {}
  
  # If step_results is a string (placeholder), convert it to empty hash
  step_results = {} if step_results.is_a?(String) && step_results.include?('<p>step_results</p>')
  
  puts "[DEBUG] Final step_results: #{step_results.inspect}"
  puts "[DEBUG] Final step_results type: #{step_results.class}"
  
  {
    method: 'task',
    result: {
      ok: true,
      task_id: task_id,
      **task_data,
      step_results: step_results
    }
  }
end


def pause_task(task_id)
  # Pause task execution
  result = Instrumenta.handle(tool: :pause_task, args: { task_id: task_id })
  
  if result[:error]
    return { method: 'task', result: { ok: false, error: "Failed to pause task #{task_id}: #{result[:error]}" } }
  end
  
  { method: 'task', result: { ok: true, message: "Task #{task_id} paused" } }
end


def resume_task(task_id)
  # Resume task execution
  result = Instrumenta.handle(tool: :resume_task, args: { task_id: task_id })
  
  if result[:error]
    return { method: 'task', result: { ok: false, error: "Failed to resume task #{task_id}: #{result[:error]}" } }
  end
  
  { method: 'task', result: { ok: true, message: "Task #{task_id} resumed" } }
end


def cancel_task(task_id)
  # Cancel task execution
  result = Instrumenta.handle(tool: :cancel_task, args: { task_id: task_id })
  
  if result[:error]
    return { method: 'task', result: { ok: false, error: "Failed to cancel task #{task_id}: #{result[:error]}" } }
  end
  
  { method: 'task', result: { ok: true, message: "Task #{task_id} cancelled" } }
end


def execute_task(task_id)
  stopThinkingThread if @ask_thread

  @ask_thread = Thread.new do
    begin
      puts "[DEBUG]: Executing task #{task_id} in background thread"
      HorologiumAeternum.send('status', 'thinking', { ok: true, message: "#{task_id}: ars ars ars" })
      result = Instrumenta.handle(tool: :execute_task, args: { task_id: task_id })
      puts "[DEBUG]: Task execution completed: #{result}"
      HorologiumAeternum.send('task', 'completion', { ok: true, task_id: task_id, result: result })
    rescue => e
      puts "[DEBUG]: Task execution error: #{e.message}"
      HorologiumAeternum.send('task', 'error', { ok: false, task_id: task_id, error: e.message })
    end
  end
  
  { method: 'task', result: { ok: true, task_id: task_id, status: 'running_in_background' } }
end

# 
def list_tasks
  # Get list of all tasks using Mnemosyne
  tasks = Mnemosyne.manage_tasks(action: :list)

  if tasks.is_a?(Hash) && tasks[:error]
    return { method: 'task', result: { ok: false, error: "Failed to list tasks: #{tasks[:error]}" } }
  end
  
  { method: 'task', result: { ok: true, tasks: tasks || [] } }
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


# Hermetic pair programming live update processing
def process_hermetic_live_update(payload)
  puts "[HERMETIC_LIVE_UPDATE][#{payload['event']}] Processing: #{payload['path']} at line #{payload['cursor']}"
  
  # Store document state for change detection
  @hermetic_document_states ||= {}
  @hermetic_document_states[payload['path']] = {
    content: payload['content'],
    cursor: payload['cursor'],
    timestamp: payload['timestamp'],
    scope: payload['scope']
  }
  
  # Generate proactive suggestions
  do_generate_proactive_suggestions(payload)
  
  # Return empty result (WebSocket messaging handled internally)
  { method: 'hermetic_live_update', result: { status: 'processed' } }
end


# Generate proactive suggestions
# Thread management for proactive suggestions
@suggestion_thread = nil

# Generate proactive suggestions with thread cancellation
def do_generate_proactive_suggestions(params)
  puts "[PROACTIVE_SUGGESTIONS] Generating suggestions for: #{params['path']} at line #{params['cursor']}"
  
  # Cancel any existing suggestion thread
  if @suggestion_thread && @suggestion_thread.alive?
    puts "[PROACTIVE_SUGGESTIONS] Cancelling previous suggestion thread"
    @suggestion_thread.kill
  end
  
  # Start new suggestion thread
  @suggestion_thread = Thread.new do
    begin
      if defined?(ContinuumWeaver)
        puts "[PROACTIVE_SUGGESTIONS] Content size: #{params['content'].size}, Event: #{params['event']}"
        # Handle selection context
        selection_range = params['selection_range']
        selected_text = params['selected_text']
        
        event = if 'change' == params['event']
          'DocumentOpen'
        else
          params['event']
        end
        
        # Don't generate suggestions for DocumentOpen events - just close the panel
        if event == 'DocumentOpen'
          puts "[PROACTIVE_SUGGESTIONS] DocumentOpen event - closing panel"
          # Send close command to frontend
          if defined?(HorologiumAeternum)
            HorologiumAeternum.send(JSON.generate({
              type: "close_proactive_suggestions",
              message: "Document opened - panel closed"
            }))
          end
          next
        end
        
        suggestion = ContinuumWeaver.generate_proactive_suggestion(
          params['content'],
          params['cursor'].to_i,
          (params['cursor_column'] || 1).to_i,
          params['path'],
          params['scope'],
          event,
          selection_range,
          selected_text
        )
          
        # Send directly via WebSocket
        if defined?(HorologiumAeternum)
          puts "[PROACTIVE_SUGGESTIONS] Sending suggestion: #{suggestion&.size || 0} chars"
          
          HorologiumAeternum.send('proactive_suggestion', 'suggestion', {
            path: params['path'],
            cursor: params['cursor'],
            scope: params['scope'],
            content: params['content'],
            suggestion: suggestion,
            timestamp: Time.now.to_f
          })
        end
      else
        # Send error via WebSocket
        if defined?(HorologiumAeternum)
          HorologiumAeternum.send('proactive_suggestion', 'error', {
            path: params['path'],
            cursor: params['cursor'],
            scope: params['scope'],
            content: params['content'],
            suggestion: nil,
            error: "ContinuumWeaver not available",
            timestamp: Time.now.to_f
          })
        end
      end
    rescue => e
      puts "[PROACTIVE_SUGGESTIONS] Error: #{e.message}"
      puts e.backtrace.join("\n") if ENV['DEBUG']
      
      # Send error via WebSocket
      if defined?(HorologiumAeternum)
        HorologiumAeternum.send('proactive_suggestion', 'error', {
          path: params['path'],
          cursor: params['cursor'],
          scope: params['scope'],
          content: params['content'],
          suggestion: nil,
          error: "Generation failed: #{e.message}",
          timestamp: Time.now.to_f
        })
      end
    end
  end
end

# WebSocket instance accessor for live updates (not needed - handled by limen framework)
# def websocket
#   HorologiumAeternum.instance_variable_get(:@websocket)
# end
class Pythia
  constructor: ->
    @DEFAULT_PORT = 4567
    @isThinking = false
    @port = window.AETHER_PORT ? @DEFAULT_PORT
    @project_root = window.AETHER_PROJECT_ROOT ? null
    @ws = null
    @reconnectAttempts = 0
    @maxReconnectAttempts = 10
    @baseReconnectDelay = 1000  # 1 second
    @lastPongTime = null
    @attachment_context = null
    @lastLogTime = 0
    @messageBuffer = []
    @MESSAGE_THROTTLE_TIME = 1300
    @stored = null
    @connectWebSocketTimeout = null

  connectWebSocket: (uuid) =>
    console.log "connectWebSocket#{uuid}"
    try
      if @ws?.readyState == WebSocket.OPEN or @ws?.readyState == WebSocket.CONNECTING
        do @ws.close
        @ws = null
      
      uuid ||= do crypto.randomUUID
      @log 'system', uuid, "🔮 Initiating connection ritual to ws://127.0.0.1:#{@port}/ws..."
      @ws = new WebSocket "ws://127.0.0.1:#{@port}/ws"
      @setupWebSocketHandlers uuid
    catch e
      @log 'error', uuid, "🔮 Connection ritual failed: #{e.message}"
      setTimeout (=> @scheduleReconnect uuid), 1500

  setupWebSocketHandlers: (uuid) =>
    @ws.onopen = =>
      @lastPongTime = do Date.now
      @log 'system', uuid, '🗝️ Gate opened.'
      uuid = do crypto.randomUUID
      @reconnectAttempts = 0  # Reset on successful connection
      
      if @stored?.length < 3
        @ws.send JSON.stringify({ method: 'history', params: { limit: 7 }})
    
    @ws.onerror = (e) =>
      console.log e
      @log 'error', uuid, "🔮 Dimensional breach detected: #{e.message ? e.type ? 'connection error'}"
    
    @ws.onclose = (e) =>
      @log 'error', uuid, "🌀 Gate sealed code=#{e.code} reason=#{e.reason}"
      @scheduleReconnect uuid
      
    # Check for missed pongs every 30 seconds and close stale connections
    setInterval =>
      if @lastPongTime and (do Date.now - @lastPongTime) > 42000
        console.log 'missing pong detected, closing stale connection'
        do @ws.close
        @scheduleReconnect uuid
    , 42000
    
    @ws.onmessage = (e) =>
      if '💓' is e.data
        console.log "onping"
        @lastPongTime = do Date.now
        @ws.send '💓'
      else
        @handleMessage e

  scheduleReconnect: (uuid, immediate = false) =>
    return if @reconnectAttempts >= @maxReconnectAttempts
    
    if @reconnectAttempts >= @maxReconnectAttempts
      @log 'error', uuid, '🔮 Maximum reconnection attempts reached. Gateway sealed.'
      return
    
    delay = @baseReconnectDelay * Math.pow(2, Math.min(@reconnectAttempts, 5))
    @reconnectAttempts++
    
    @log 'system', uuid, "🔮 Attempting dimensional reconnection #{@reconnectAttempts}/#{@maxReconnectAttempts} in #{if immediate then 0 else delay}ms..."
    clearTimeout @connectWebSocketTimeout
    @connectWebSocketTimeout = setTimeout (=> @connectWebSocket uuid), delay
  

connectWebSocketTimeout = null


scheduleReconnect = (uuid, immediate = false) ->
  return if reconnectAttempts >= maxReconnectAttempts
  
  if reconnectAttempts >= maxReconnectAttempts
    log 'error', uuid, '🔮 Maximum reconnection attempts reached. Gateway sealed.'
    return
  
  delay = baseReconnectDelay * Math.pow(2, Math.min(reconnectAttempts, 5))
  reconnectAttempts++
  
  log 'system', uuid, "🔮 Attempting dimensional reconnection #{reconnectAttempts}/#{maxReconnectAttempts} in #{if immediate then 0 else delay}ms..."
  clearTimeout connectWebSocketTimeout
  connectWebSocketTimeout = setTimeout (-> connectWebSocket uuid), delay


# Message persistence
STORAGE_KEY = 'aether_messages'
MAX_MESSAGES = 250


saveMessages = ->
  messages = Array.from(document.querySelectorAll('#messages > div:not(.error)')).map (el) ->
    className: el.className
    innerHTML: el.innerHTML
  localStorage.setItem STORAGE_KEY, JSON.stringify(messages.slice(-MAX_MESSAGES))


stored = null
loadMessages = ->
  try
    m = document.getElementById 'messages'
    stored = JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]')
    stored.forEach (msg) ->
      console.log "load from storage:", msg
      el = document.createElement 'div'
      el.className = msg.className
      el.innerHTML = msg.innerHTML
      document.getElementById('messages').appendChild el
    m.scrollTop = m.scrollHeight
  catch e
    console.warn 'Failed to load messages:', e
  
  do loadMessagesDone


loadMessagesDone = ->
  console.log "loadMessagesDone"
  do connectWebSocket


# Throttled logging interval (1 second)
setInterval ->
  now = do Date.now
  if messageBuffer.length > 0 and now - lastLogTime >= MESSAGE_THROTTLE_TIME
    do messageBuffer.shift()
    # console.log "[Pythia] Throttled log:", message
    lastLogTime = now
, 100 # Check every 100ms


log = (cls, uuid, html) ->
  console.log "logging #{cls}", uuid, html
  
  add_message = ->
    existing = document.getElementById uuid unless null is uuid 
    m = document.getElementById 'messages'
  
    # TODO add highlight animation when appearing
    if existing
      is_near = (existing.offsetTop - m.scrollTop - m.offsetHeight) < 
        m.offsetHeight * 0.5
      existing.className = cls
      existing.innerHTML = html
      if is_near_bottom
        m.scrollTop = existing.offsetTop - m.offsetHeight + 
          existing.offsetHeight
    else
      is_near_bottom = 
        (m.scrollHeight - m.scrollTop - m.offsetHeight) < m.offsetHeight * 0.5
      el = document.createElement 'div'
      el.className = cls
      el.innerHTML = html
      el.id = uuid
      m.appendChild el
      m.scrollTop = m.scrollHeight if is_near_bottom
      
    do saveMessages
    
  if uuid
    messageBuffer.push add_message
  else do add_message


renderTools = (tools) ->
  return unless tools?.length
  tools.forEach (t, idx) ->
    btn = document.createElement 'button'
    btn.textContent = "Consecrate #{t.tool}"
    btn.onclick = ->
      ws.send JSON.stringify method: 'tool', params: t
    log 'system', null, "Proposed tool ##{idx+1}: <pre>#{JSON.stringify(t,null,2)}</pre>"
    document.getElementById('messages').appendChild btn


toggleTaskProgress = (task_id) ->
  taskProgress = document.getElementById 'task_progress'
  taskProgress.classList.toggle('collapsed')


# Enhanced status display with data.task_id feedback
renderTaskProgress = (task) ->
  taskProgress = document.getElementById 'task_progress'
  task_id = task.task_id or task.id
  
  unless taskProgress
    taskProgress = document.createElement 'div'
    taskProgress.id = "task_progress"
    taskProgress.className = 'task-progress'
    
    inputBar = document.getElementById 'input-bar'
    inputBar.insertAdjacentElement "beforebegin", taskProgress
  
  # TODO the task step is rendered wrong it should render the steps and not plan. plan is just description.
  taskProgress.innerHTML = """
    <div class=\"task-header\">
      <strong>#{task.title}</strong>
      <span>Step #{task.current_step}/10</span>
      <button onclick="toggleTaskProgress('#{task_id}')"></button>
    </div>
    <div class=\"progress-bar\">
      <div class="progress" style="width: #{Math.round(task.current_step/10*100)}%"></div>
    </div>
    <div class=\"task-plan\">
      #{[task.plan].map((step, i) ->
        "<div class='step #{if i < task.current_step then 'completed' else if i == task.current_step then 'current' else ''}'>#{step}</div>"
      ).join ''}
    </div>
    <div class=\"task-controls\">
      <button onclick=\"ws.send(JSON.stringify({ method: 'task', params: { action: 'pause', id: #{task_id} }}))\">⏸</button>
      <button onclick=\"ws.send(JSON.stringify({ method: 'task', params: { action: 'resume', id: #{task_id} }}))\">▶</button>
      <button onclick=\"ws.send(JSON.stringify({ method: 'task', params: { action: 'cancel', id: #{task_id} }}))\">✕</button>
    </div>
  """
  

showStatus = (type, data, uuid) ->
  timestamp = new Date(data.timestamp * 1000).toLocaleTimeString() if data.timestamp
  
  console.log "showStatus", timestamp, type, data
  
  switch type
    when 'thinking'
      if data.content
        log 'system', uuid, """
          <details>
            <summary>#{data.message} <small>#{timestamp || ''}</small></summary>
            #{data.content}
          </details>"""
      else
        log 'status', uuid, "#{data.message || 'Consulting the astral codex...'} <small>#{timestamp || ''}</small>"
    when 'file_reading'
      log 'status', uuid, "#{replaceFileTags data.message} <small>#{timestamp || ''}</small>"    
    when 'divination'
      log 'status', uuid, "#{data.message || 'Consulting the astral codex...'} <small>#{timestamp || ''}</small>"
    when 'file_read_complete'
      log 'status', uuid, """
        <details>
          <summary>#{replaceFileTags data.message} <small>#{timestamp || ''}</small></summary>
          #{data.content}
        </details>"""
    when 'file_read_fail'
      log 'status', uuid, "#{replaceFileTags data.message}: #{error} <small>#{timestamp || ''}</small>"
    when 'file_creating'
      log 'status', uuid, "#{replaceFileTags data.message} <small>#{timestamp || ''}</small>"
    when 'file_created'
      log 'status', uuid, """
        <details>
          <summary>#{replaceFileTags data.message} <small>#{timestamp || ''}</small></summary>
          #{data.content}
        </details>"""
    when 'tool_starting'
      log 'status', uuid, "⚡️ Invoking <code>#{data.tool}</code>... <small>#{timestamp || ''}</small>"
      if data.args and Object.keys(data.args).length > 0 and JSON.stringify(data.args).length < 200
        log 'status', uuid, "&nbsp;&nbsp;↳ Args: <code>#{JSON.stringify(data.args)}</code>"
    when 'file_patching'
      log 'status', uuid, """
        <details>
          <summary>#{replaceFileTags data.message} <small>#{timestamp || ''}</small></summary>
          #{data.diff}
        </details>"""
    when 'file_patched'
      log 'status', uuid, """
        <details>
          <summary>#{replaceFileTags data.message} <small>#{timestamp || ''}</small></summary>
          #{replaceFileTags data.diff}
        </details>"""
    when 'file_patched_fail'
      log 'status', uuid, """
        <details>
          <summary>#{replaceFileTags data.message} <small>#{timestamp || ''}</small></summary>
          #{data.diff}
        </details>"""
    when 'command_executing'
      log 'status', uuid, "#{data.message} <small>#{timestamp || ''}</small>"
    when 'command_completed'
      log 'status', uuid, """
        <details>
          <summary>#{data.message} <small>#{timestamp || ''}</small></summary>
          <pre>#{data.content}</pre>
        </details>"""
    when 'file_renaming'
      log 'status', uuid, "#{replaceFileTags data.message} <small>#{timestamp || ''}</small>"
    when 'file_renamed'
      log 'status', uuid, "#{replaceFileTags data.message} <small>#{timestamp || ''}</small>"      
    when 'memory_storing'
      log 'status', uuid, "#{data.message} <small>#{timestamp || ''}</small>"
    when 'memory_stored'
      log 'status', uuid, "#{data.message} <small>#{timestamp || ''}</small>"
    when 'memory_searching'
      log 'status', uuid, "#{data.message} <small>#{timestamp || ''}</small>"
    when 'memory_found'
      log 'status', uuid, """
        <details>
          <summary>#{data.message} <small>#{timestamp || ''}</small></summary>
          <pre>#{data.content}</pre>
        </details>"""
    when 'info'
      log 'status', uuid, "#{replaceFileTags data.message} <small>#{timestamp || ''}</small>"    
    when 'tool_completed'
      if data.result?.error
        log 'status', uuid, "❌ Tool <code>#{data.tool}</code> failed: #{data.result.error} <small>#{timestamp || ''}</small>"
        if data.result.error
          log 'system', uuid, "<details><summary>❌ Error details</summary><pre>#{data.result.error}</pre></details>"
      else
        log 'status', uuid, "✅ Tool <code>#{data.tool}</code> completed <small>#{timestamp || ''}</small>"
      if data.result and Object.keys(data.result).length > 0 and not data.result?.error
        resultJson = JSON.stringify data.result, null, 2
        if resultJson.length > 200
          log 'system', uuid, "<details><summary>📋 #{data.tool} result (#{resultJson.length} chars)</summary><pre>#{resultJson}</pre></details>"
        else
          log 'system', uuid, "&nbsp;&nbsp;↳ Result: <pre style='display:inline; background:none;'>#{resultJson}</pre>"
    when 'oracle_revelation'
      if data.content
        log 'ai', uuid, replaceFileTags data.content
      else
        log 'status', uuid, "💭 AI responding... <small>#{timestamp || ''}</small>"
    when 'oracle_conjuration_revelation'
      log 'system', uuid, """
        <details>
          <summary>#{data.message} <small>#{timestamp || ''}</small></summary>
          #{replaceFileTags data.content}
        </details>"""
    when 'oracle_conjuration'
      log 'status', uuid, """
        <details>
          <summary>#{data.message} <small>#{timestamp || ''}</small></summary>
          #{replaceFileTags data.content}
        </details>"""
    when 'plan_announced'
      log 'status', uuid, "📋Plan: #{data.steps?.join ' → '} <small>#{timestamp || ''}</small>"
    when 'processing'
      log 'status', uuid, "#{data.message} <small>#{timestamp || ''}</small>"
    when 'completed'
      log 'status', uuid, "#{data.summary || 'Completed'} <small>#{timestamp || ''}</small>"
    when 'server_error'
      log 'error', uuid, "#{data.error} <small>#{timestamp || ''}</small>"
    when 'system_error'
      log 'error', uuid, "#{data.error} <small>#{timestamp || ''}</small>"
    when 'system_message'
      log 'system', uuid, "#{data.message} <small>#{timestamp || ''}</small>"
    when 'note_added'
      log 'system', uuid, """
        <details>
          <summary>#{data.message} <small>#{timestamp || ''}</small></summary>
          #{replaceFileTags data.content}
        </details>"""
    when 'note_removed'
      log 'system', uuid, """
        <details>
          <summary>#{data.message} <small>#{timestamp || ''}</small></summary>
          #{replaceFileTags data.content}
        </details>"""
    when 'note_updated'
      log 'system', uuid, """
        <details>
          <summary>#{data.message} <small>#{timestamp || ''}</small></summary>
          #{replaceFileTags data.content}
        </details>"""
    when 'notes_recalled'
      log 'system', uuid, """
        <details>
          <summary>#{data.message} <small>#{timestamp || ''}</small></summary>
          #{replaceFileTags data.notes}
        </details>"""
    when 'file_overview'
      log 'system', uuid, """
        <details>
          <summary>#{replaceFileTags data.message} <small>#{timestamp || ''}</small></summary>
          #{replaceFileTags data.content}
        </details>"""
    when 'aegis_unveiled'
      log 'system', uuid, """
        <details>
          <summary>#{data.message} <small>#{timestamp || ''}</small></summary>
          #{replaceFileTags data.content}
        </details>"""
    when 'task_started'
      log 'status', uuid, "#{data.message} <small>#{timestamp || ''}</small>"
      renderTaskProgress data
    when 'task_completed'
      log 'system', uuid, "#{data.message} <small>#{timestamp || ''}</small>"
      renderTaskProgress data
    when 'task_created'
      log 'system', uuid, """
        <details>
          <summary>#{data.message} <small>#{timestamp || ''}</small></summary>
          <div>#{replaceFileTags data.plan}</div>
        </details>"""
      renderTaskProgress data
    when 'task_updated'
      log 'system', uuid, "#{data.message} <small>#{timestamp || ''}</small>"
      renderTaskProgress data
    when 'task_removed'
      log 'system', uuid, "#{data.message} <small>#{timestamp || ''}</small>"
    when 'task_list'
      log 'system', uuid, """
        <details>
          <summary>#{data.message} <small>#{timestamp || ''}</small></summary>
          <div class="task-list">#{replaceFileTags data.content}</div>
        </details>"""
    when 'task_log_added'
      task_id = data.id or data.task_id
      # Add to existing task log display or create new one
      taskLogElement =
        document.getElementById "task-logs-#{task_id}"
      unless taskLogElement
        # Create task log container if it doesn't exist
        taskLogElement = document.createElement 'div'
        taskLogElement.id = "task-logs-#{task_id}"
        taskLogElement.className = 'task-logs'
        taskLogElement.innerHTML = """
          <div class="task-log-header">
            <h4>📋 Task ##{task_id} Execution Log</h4>
            <button onclick="toggleTaskLogs('#{task_id}')"></button>
          </div>
          <div class="task-log-entries"></div>
        """
        document.getElementById('messages').appendChild taskLogElement
      
      logTime = new Date(data.timestamp * 1000).toLocaleTimeString()
      logEntry = document.createElement 'div'
      logEntry.className = 'task-log-entry'
      logEntry.innerHTML = """
        <span class="log-time">#{logTime}</span>
        <span class="log-message">#{replaceFileTags data.content}</span>
      """
      task_log_entries = taskLogElement.querySelector('.task-log-entries')
      task_log_entries.appendChild logEntry
      task_log_entries.scrollTop = task_log_entries.scrollHeight
      
      # renderTaskProgress data
    when 'history'
      log 'system', uuid, "#{data.message} <small>#{timestamp || ''}</small>"
      data.content.forEach (entry) ->
        log 'user', null, "#{entry.prompt} <small>#{timestamp || ''}</small>"
        log 'ai', null, "#{entry.answer} <small>#{timestamp || ''}</small>"
  

toggleTaskLogs = (task_id) ->
  taskLogElement = document.getElementById "task-logs-#{task_id}"
  if taskLogElement
    taskLogElement.classList.toggle 'collapsed'
        
  
handleMessage = (e) ->
  console.debug "[Pythia] Handling message:", e.data
  data = JSON.parse e.data
  
  if'success' is data.status
    isThinking = false
    return do updateSendButton  
  
  switch data.method
    when 'status'
      showStatus data.result.type, data.result.data, data.result.uuid
    when 'answer'
      isThinking = false
      do updateSendButton
      # TODO remove redundant...
      if data.result.logs?
        data.result.logs.forEach (l) ->
          switch l.type
            when 'prelude' then log 'ai', null, l.data s
            when 'say'     then log 'ai', null, l.data.message
      # if data.result.tools? and data.result.tools.length > 0
      #   toolsJson = JSON.stringify(data.result.tools, null, 2)
      #   if toolsJson.length > 300
      #     log 'system', uuid, "<details><summary>🔧 Tools (#{toolsJson.length} chars)</summary><pre>#{toolsJson}</pre></details>"
      #   else
      #     log 'system', uuid, "<pre>#{toolsJson}</pre>"
      #   renderTools data.result.tools
    when 'toolResult'
      resultJson = JSON.stringify data.result, null, 2
      if resultJson.length > 300
        log 'system', null, "<details><summary>🔧 Tool Result (#{resultJson.length} chars)</summary><pre>#{resultJson}</pre></details>"
      else
        log 'system', null, "<pre>#{resultJson}</pre>"    
    when 'completion'
      log 'ai', null, "<pre>#{data.result.snippet}</pre>"
    when 'error'
      log 'error', null, "<pre>#{data.result.error}\\n#{(data.result.backtrace or []).join '\\n'}</pre>"
    when 'fileContent'
      log 'system', null, """
        <details>
          <summary>📄 File Content</summary>
          <pre>#{data.result}</pre>
        </details>"""
    when 'attach'
      renderAttachmentPreview(data.result.data)
    else
      log 'system', null, "<pre>#{JSON.stringify data, null, 2}</pre>"
      
      
      
match_selection_range =/([0-9]+)(?:\:([0-9]+))?(?:-([0-9]+)(?:\:([0-9]+))?)?/


# Attachment preview rendering
renderAttachmentPreview = (data) ->
  console.log "renderAttachmentPreview", data
  { line, column, selection_range, file_html, content, selection_html, lines } = data
  content ||= 'No content preview available.'
  attachment_uuid = do crypto.randomUUID
  attachment_context = data
  console.log "renderAttachmentPreview",file_html, content, selection_html
  preview = document.createElement 'div'
  preview.id = "attachment_#{attachment_uuid}"
  preview.className = 'attachment-preview'
  attachment_content = if selection_html then """
    <div class=\"attachment-content\">
      <div>#{selection_html}</div>
    </div>
  """ else ''
    
  [selection_range, line, column] = if selection_range
    [_, from_line, from_column, to_line, to_column] = 
      selection_range.match match_selection_range
    if to_line
      ["<span>Selection: <span>#{selection_range}</span></span>", 0, 0]
    else
      ['', from_line, from_column]
  else ['', 0, 0]
    
  line = unless line then '' else
    "<span>Line: <span>#{line}</span></span>"
  column = unless column then '' else
    "<span>Column: <span>#{column}</span></span>"

  preview.innerHTML = """
    <div class=\"attachment-header\">
      <span>📎 #{replaceFileTags file_html}</span>
      <button onclick=\"removeAttachment('#{attachment_uuid}')\">✕</button>
    </div>
    <div class=\"attachment-meta\">
      #{line}
      #{column}
      #{selection_range}
    </div>
    #{attachment_content}
  """
  
  inputBar = document.getElementById 'input-bar'
  inputBar.insertAdjacentElement "beforebegin", preview


# Attachment management
removeAttachment = (attachment_uuid) ->
  attachment_context = null
  # ws.send JSON.stringify method: 'clear_attachment', params: { path: path }
  do document.getElementById("attachment_#{attachment_uuid}").remove


onSendBtnClick = (e) ->
  if isThinking
    do stopThinking
  else
    do adjustHeight
    do askAI


askAI = ->
  text = document.getElementById('chat-input').value
  return unless text?.length
  { file, selection } = attachment_context || {}
  ws.send JSON.stringify method: 'askAI', params: { 
    prompt: text, record: true, file, selection }
  log 'user', null, escapeHtml text
  document.getElementById('chat-input').value = ''
  isThinking = true
  do updateSendButton


stopThinking = ->
  ws.send JSON.stringify method: 'stopThinking'
  isThinking = false
  do updateSendButton


updateSendButton = ->
  if isThinking
    sendBtnGlyph.textContent = '⏹'
    sendBtn.classList.add 'thinking'
  else
    sendBtnGlyph.textContent = '⚡️'
    sendBtn.classList.remove 'thinking'


replaceFileTags = (content) ->
  match_file = RegExp "<file(?: path=\"([^\"]+)\")?(?: line=\"([^\"]+)\")?" +
              "(?: column=\"([^\"]+)\")?>([^<]+)<\\/file>", 'g'
  match_file_html = 
    RegExp "\&lt;file(?: path=\&quot;((?!.*?\&quot;).*?)\&quot;)?" +
           "(?: line=\&quot;((?!.*?\&quot;).*?)\&quot;)?" +
           "(?: column=\&quot;((?!.*?\&quot;).*?)\&quot;)?\&gt;" +
           "(.*?(?<!\&lt;))\&lt;\\/file\&gt;", 'g'
           
  replace_matches = (match, path, line, column, displayName) ->
    path ||= displayName
    href = "txmt://open/?url=file://#{project_root}/#{encodeURIComponent(path)}" 
    href += "\&line=#{line}" if line
    href += "\&column=#{column}" if column
    "<a href=\"#{href}\" class=\"file-link\">#{displayName}</a>"
    
  content = content.replace match_file, replace_matches
  content.replace match_file_html, replace_matches


escapeHtml = (unsafe) ->
  unsafe
  .replace /&/g, "&amp;"
  .replace /</g, "&lt;"
  .replace />/g, "&gt;"
  .replace /"/g, "&quot;"
  .replace /'/g, "&#039;"


sendBtn = document.getElementById 'send-btn'
sendBtnGlyph = sendBtn.getElementsByClassName('send-glyph')[0]
sendBtn.onclick = onSendBtnClick


# Handle Enter and Shift+Enter for textarea
document.getElementById('chat-input').addEventListener 'keydown', (e) ->
  if e.key == 'Enter' and not e.shiftKey
    do e.preventDefault
    do askAI
    do adjustHeight
  else if e.key == 'Enter' and e.shiftKey
    null


textarea = null
                                      

adjustHeight = -> 
  textarea.style.height = 'auto'
  textarea.style.height = "#{textarea.scrollHeight}px"


document.addEventListener 'DOMContentLoaded', ->
  textarea = document.getElementById 'chat-input'
  
  textarea.addEventListener 'input', adjustHeight
  do adjustHeight

    
# Load messages when page loads
window.addEventListener 'DOMContentLoaded', loadMessages

history.pushState null, null, location.href

window.onpopstate = ->
  history.go 1
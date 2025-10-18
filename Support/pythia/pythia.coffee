###
Pythia - AI Oracle Client (Class-based Restructuring)
WebSocket client for communicating with the Aetherflux AI oracle
###

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
    @STORAGE_KEY = "aether_messages_#{@port}"
    @MAX_MESSAGES = 250
    @horologium = null
    @activeTaskLogs = {}  # Track active task logs for persistence
    @attachments = []     # Array for multiple attachments
    @magnumOpus = new MagnumOpus(this)
    @createScrollToBottomButton()
    @loadMermaid()

  # Mermaid.js Loading
  loadMermaid: =>
    # Check if Mermaid is already loaded
    if window.mermaid
      console.log('Mermaid already loaded')
      @initializeMermaid()
      return
    
    # Load Mermaid from CDN
    console.log('Loading Mermaid.js...')
    script = document.createElement('script')
    script.src = 'https://cdn.jsdelivr.net/npm/mermaid@10.6.1/dist/mermaid.min.js'
    script.onload = =>
      console.log('Mermaid.js loaded successfully')
      @initializeMermaid()
    script.onerror = =>
      console.error('Failed to load Mermaid.js')
    document.head.appendChild(script)

  # WebSocket Connection Management
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
      
      console.log "setupWebSocketHandlers", @stored
      if not @stored or @stored?.length < 3
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


  # Message Persistence
  saveMessages: =>
    messages = @stored = Array.from(document.querySelectorAll('#messages > div:not(.error)')).map (el) ->
      className: el.className
      innerHTML: el.innerHTML
    localStorage.setItem @STORAGE_KEY, 
      JSON.stringify(messages.slice -@MAX_MESSAGES)


  loadMessages: =>
    try
      m = document.getElementById 'messages'
      @stored = JSON.parse(localStorage.getItem(@STORAGE_KEY) || '[]')
      @stored.forEach (msg) =>
        console.log "load from storage:", msg
        el = document.createElement 'div'
        el.className = msg.className
        el.innerHTML = msg.innerHTML
        document.getElementById('messages').appendChild el
      m.scrollTop = m.scrollHeight
    catch e
      console.warn 'Failed to load messages:', e
    
    do @loadMessagesDone


  loadMessagesDone: =>
    console.log "loadMessagesDone"
    do @connectWebSocket


  # Logging System
  startLoggingInterval: =>
    setInterval =>
      now = do Date.now
      if @messageBuffer.length > 0 and now - @lastLogTime >= @MESSAGE_THROTTLE_TIME
        do @messageBuffer.shift()
        @lastLogTime = now
    , 100 # Check every 100ms


  log: (cls, uuid, html) =>
    console.log "logging #{cls}", uuid, html
    
    add_message = =>
      existing = document.getElementById uuid unless null is uuid 
      m = document.getElementById 'messages'
    
      if existing
        is_near = (existing.offsetTop - m.scrollTop - m.offsetHeight) < m.offsetHeight * 0.5
        existing.className = cls
        existing.innerHTML = html
        if is_near_bottom
          m.scrollTop = 100 + existing.offsetTop - m.offsetHeight + existing.offsetHeight
      else
        is_near_bottom = (m.scrollHeight - m.scrollTop - m.offsetHeight) < m.offsetHeight * 0.5
        el = document.createElement 'div'
        el.className = cls
        el.innerHTML = html
        el.id = uuid
        m.appendChild el
        m.scrollTop = 100 + m.scrollHeight if is_near_bottom
        
      do @saveMessages
      
      # Render any Mermaid diagrams in the new content
      @renderMermaidDiagrams()
      
    if uuid
      @messageBuffer.push add_message
    else do add_message


  # Status Display System
  showStatus: (type, data, uuid) =>
    timestamp = new Date(data.timestamp * 1000).toLocaleTimeString() if data.timestamp
    timestamp_html = "<small>#{timestamp || ''}</small>"
    
    console.log "showStatus", timestamp, type, data
    
    switch type
      when 'thinking'
        if data.content
          @log 'system', uuid, """
            <details>
              <summary>#{data.message} #{timestamp_html}</summary>
              #{data.content}
            </details>"""
        else
          @log 'status', uuid, "#{data.message || 'Consulting the astral codex...'} #{timestamp_html}"
      when 'file_reading'
        @log 'status', uuid, "#{@replaceFileTags data.message} #{timestamp_html}"    
      when 'divination'
        @log 'status', uuid, "#{data.message || 'Consulting the astral codex...'} #{timestamp_html}"
      when 'file_read_complete'
        @log 'status', uuid, """
          <details>
            <summary>#{@replaceFileTags data.message} #{timestamp_html}</summary>
            #{data.content}
          </details>"""
      when 'file_read_fail'
        @log 'status', uuid, """
          <details>
            <summary>#{@replaceFileTags data.message} #{timestamp_html}</summary>
            #{data.error}
          </details>"""
      when 'file_creating'
        @log 'status', uuid, "#{@replaceFileTags data.message} #{timestamp_html}"
      when 'file_created'
        @log 'status', uuid, """
          <details>
            <summary>#{@replaceFileTags data.message} #{timestamp_html}</summary>
            #{data.content}
          </details>"""
      when 'temp_file_created'
        @log 'status', uuid, """
          <details>
            <summary>#{@replaceFileTags data.message} #{timestamp_html}</summary>
            #{data.content}
          </details>"""

      when 'tool_starting'
        @log 'status', uuid, "⚡️ Invoking <code>#{data.tool}</code>... #{timestamp_html}"
        if data.args and Object.keys(data.args).length > 0 and JSON.stringify(data.args).length < 200
          @log 'status', uuid, "&nbsp;&nbsp;↳ Args: <code>#{JSON.stringify(data.args)}</code>"
      when 'file_patching'
        @log 'status', uuid, """
          <details>
            <summary>#{@replaceFileTags data.message} #{timestamp_html}</summary>
            #{data.diff}
          </details>"""
      when 'file_patched'
        @log 'status', uuid, """
          <details>
            <summary>#{@replaceFileTags data.message} #{timestamp_html}</summary>
            #{@replaceFileTags data.diff}
          </details>"""
      when 'file_patched_fail'
        @log 'status', uuid, """
          <details>
            <summary>#{@replaceFileTags data.message} #{timestamp_html}</summary>
            #{data.diff}
          </details>"""
      when 'symbolic_patch_start'
        @log 'status', uuid, "#{@replaceFileTags data.message} #{timestamp_html}"
      when 'symbolic_patch_complete'
        @log 'status', uuid, """
          <details>
            <summary>#{@replaceFileTags data.message} #{timestamp_html}</summary>
            #{@replaceFileTags data.result_display}
          </details>"""
      when 'symbolic_patch_fail'
        @log 'status', uuid, """
          <details>
            <summary>#{@replaceFileTags data.message} #{timestamp_html}</summary>
            #{data.error}
          </details>"""
      when 'command_executing'
        @log 'status', uuid, "#{data.message} #{timestamp_html}"
      when 'command_completed'
        @log 'status', uuid, """
          <details class="run_command">
            <summary>#{data.message} #{timestamp_html}</summary>
            <pre>#{data.content}</pre>
          </details>"""
      when 'file_renaming'
        @log 'status', uuid, "#{@replaceFileTags data.message} #{timestamp_html}"
      when 'file_renamed'
        @log 'status', uuid, "#{@replaceFileTags data.message} #{timestamp_html}"      
      when 'memory_storing'
        @log 'status', uuid, "#{data.message} #{timestamp_html}"
      when 'memory_stored'
        @log 'status', uuid, "#{data.message} #{timestamp_html}"
      when 'memory_searching'
        @log 'status', uuid, "#{data.message} #{timestamp_html}"
      when 'memory_found'
        @log 'status', uuid, """
          <details>
            <summary>#{data.message} #{timestamp_html}</summary>
            <pre>#{data.content}</pre>
          </details>"""
      when 'info'
        @log 'status', uuid, "#{@replaceFileTags data.message} #{timestamp_html}"    
      when 'tool_completed'
        if data.result?.error
          @log 'status', uuid, "❌ Tool <code>#{data.tool}</code> failed: #{data.result.error} #{timestamp_html}"
          if data.result.error
            @log 'system', uuid, "<details><summary>❌ Error details</summary><pre>#{data.result.error}</pre></details>"
        else
          @log 'status', uuid, "✅ Tool <code>#{data.tool}</code> completed #{timestamp_html}"
        if data.result and Object.keys(data.result).length > 0 and not data.result?.error
          resultJson = JSON.stringify data.result, null, 2
          if resultJson.length > 200
            @log 'system', uuid, "<details><summary>📋 #{data.tool} result (#{resultJson.length} chars)</summary><pre>#{resultJson}</pre></details>"
          else
            @log 'system', uuid, "&nbsp;&nbsp;↳ Result: <pre style='display:inline; background:none;'>#{resultJson}</pre>"
      when 'oracle_revelation'
        if data.content
          @log 'ai', uuid, @replaceFileTags data.content
        else
          @log 'status', uuid, "💭 AI responding... #{timestamp_html}"
      when 'oracle_conjuration_revelation'
        @log 'system', uuid, """
          <details>
            <summary>#{data.message} #{timestamp_html}</summary>
            #{@replaceFileTags data.content}
          </details>"""
      when 'oracle_conjuration'
        @log 'status', uuid, """
          <details>
            <summary>#{data.message} #{timestamp_html}</summary>
            #{@replaceFileTags data.content}
          </details>"""
      when 'plan_announced'
        @log 'status', uuid, "📋Plan: #{data.steps?.join ' → '} #{timestamp_html}"
      when 'processing'
        @log 'status', uuid, "#{data.message} #{timestamp_html}"
      when 'completed'
        @log 'status', uuid, "#{data.summary || 'Completed'} #{timestamp_html}"
      when 'server_error'
        @log 'error', uuid, "#{data.error} #{timestamp_html}"
      when 'system_error'
        @log 'error', uuid, "#{data.error} #{timestamp_html}"
      when 'system_message'
        @log 'system', uuid, "#{data.message} #{timestamp_html}"
      when 'note_added'
        @log 'system', uuid, """
          <details>
            <summary>#{data.message} #{timestamp_html}</summary>
            #{@replaceFileTags data.content}
          </details>"""
      when 'note_removed'
        @log 'system', uuid, """
          <details>
            <summary>#{data.message} #{timestamp_html}</summary>
            #{@replaceFileTags data.content}
          </details>"""
      when 'note_updated'
        @log 'system', uuid, """
          <details>
            <summary>#{data.message} #{timestamp_html}</summary>
            #{@replaceFileTags data.content}
          </details>"""
      when 'notes_recalled'
        @log 'system', uuid, """
          <details>
            <summary>#{data.message} #{timestamp_html}</summary>
            #{@replaceFileTags data.notes}
          </details>"""
      when 'aegis_unveiled'
        @log 'system', uuid, """
          <details>
            <summary>#{data.message} #{timestamp_html}</summary>
            #{@replaceFileTags data.content}
          </details>"""
      when 'file_overview'
        horologium = new window.Horologium()
        overviewHtml = horologium.renderFileOverview data
        @log 'status', uuid, """
          <details>
            <summary>#{@replaceFileTags data.message} #{timestamp_html}</summary>
            #{overviewHtml}
          </details>"""
      when 'task_started'
        @isThinking = true
        do @updateSendButton
        @log 'status', uuid, "#{data.message} #{timestamp_html}"
        @updateTaskProgress data
      when 'task_completed'
        @isThinking = false
        do @updateSendButton
        @log 'system', uuid, "#{data.message} #{timestamp_html}"
        @updateTaskProgress data
      when 'task_created'
        @log 'system', uuid, """
          <details>
            <summary>#{data.message} #{timestamp_html}</summary>
            <div class=\"task-description\">#{data.plan}</div>
          </details>"""
        @updateTaskProgress data
      when 'task_updated'
        if data.show_progress
          @log 'system', uuid, "#{data.message} #{timestamp_html}"
        
        # Update task progress with step results if available
        task_data = {}
        task_data.id = data.id if data.id
        task_data.task_id = data.id if data.id
        task_data.current_step = data.current_step if data.current_step
        task_data.title = data.title if data.title
        task_data.plan = data.plan if data.plan
        task_data.status = data.status if data.status
        task_data.step_results = data.step_results if data.step_results
        task_data.show_progress = data.show_progress if data.show_progress
        
        @updateTaskProgress task_data
      when 'task_step_completed'
        @log 'system', uuid, """
          <details>
            <summary>#{data.message} #{timestamp_html}</summary>
            #{data.result}
          </details>"""
      when 'task_step_rejected'
        @log 'system', uuid, """
          <details>
            <summary>#{data.message} #{timestamp_html}</summary>
            #{data.reason}
          </details>"""
      when 'task_removed'
        @isThinking = false
        do @updateSendButton
        @log 'system', uuid, "#{data.message} #{timestamp_html}"
      when 'task_list'
        @log 'system', uuid, """
          <details>
            <summary>#{data.message} #{timestamp_html}</summary>
            <div class="task-list">#{data.content}</div>
          </details>"""
      when 'task_log_added'
        task_id = data.id or data.task_id
        # Add to existing task log display in unified panel
        taskLogElement = document.getElementById "task-logs-#{task_id}"
        
        # If no log container exists in unified panel, ensure task progress is rendered first
        unless taskLogElement
          # Render the task progress panel which now includes logs container
          @updateTaskProgress data
          taskLogElement = document.getElementById "task-logs-#{task_id}"
        
        if taskLogElement
          logTime = new Date(data.timestamp * 1000).toLocaleTimeString()
          logEntry = document.createElement 'div'
          logEntry.className = 'task-log-entry'
          logEntry.innerHTML = """
            <span class=\"log-time\">#{logTime}</span>
            <span class=\"log-message\">#{data.content}</span>
          """
          task_log_entries = taskLogElement.querySelector('.task-log-entries')
          task_log_entries.appendChild logEntry
          
          # Auto-scroll only if not manually scrolled up
          isNearBottom = (task_log_entries.scrollHeight - task_log_entries.scrollTop - task_log_entries.clientHeight) < 50
          task_log_entries.scrollTop = task_log_entries.scrollHeight if isNearBottom
          
          # Also store the log in localStorage for persistence
          @storeTaskLog task_id, data.content, logTime
      when 'history'
        data.content.forEach (entry) =>
          @log 'user', null, "#{entry.prompt} #{timestamp_html}"
          @log 'ai', null, "#{@replaceFileTags entry.answer} #{timestamp_html}"
          @log 'status', null, "#{entry.completed} #{timestamp_html}"
        @log 'system', uuid, "#{data.message} #{timestamp_html}"
      when 'step_result'
        # Handle step result response for detailed step view
        @displayStepResult data
      when 'task_evaluated'
        @log 'status', null, """
          <details>
            <summary>#{data.message}</summary>
            <div class="task-evaluation-summary">
              <p><strong>Task:</strong> #{data.title} (ID: #{data.task_id})</p>
              <p><strong>Progress:</strong> Step #{data.current_step} of #{data.total_steps} (#{data.alchemical_stage})</p>
              <p><strong>Status:</strong> #{data.status}</p>
              <p><strong>Step Results:</strong> #{data.step_results_count} available</p>
            </div>
          </details>"""
          

  # Task Management
  toggleTaskProgress: (task_id) =>
    @magnumOpus.toggleTaskProgress(task_id)


  # Toggle step results visibility
  toggleStepResults: (task_id) =>
    @magnumOpus.toggleStepResults(task_id)


  showStepResult: (task_id, step_number) =>
    console.log "showStepResult", task_id, step_number
    @magnumOpus.showStepResult(task_id, step_number)


  # Update task progress display
  updateTaskProgress: (task) =>
    @magnumOpus.updateTaskProgress(task)


  toggleTaskLogs: (task_id) =>
    taskLogElement = document.getElementById "task-logs-#{task_id}"
    if taskLogElement
      taskLogElement.classList.toggle 'collapsed'
      # Update button icon based on state
      button = taskLogElement.querySelector('.task-log-header button')
      if taskLogElement.classList.contains('collapsed')
        button.textContent = '' #📄'
        button.title = 'Show logs'
      else
        button.textContent = '' #📋'
        button.title = 'Hide logs'


  # toggleStepResults: (task_id) =>
  #   stepResultsElement = document.getElementById "step-results-#{task_id}"
  #   if stepResultsElement
  #     stepResultsElement.style.display = if stepResultsElement.style.display == 'none' then 'block' else 'none'
  #     button = stepResultsElement.previousElementSibling?.querySelector('.step-results-toggle')
  #     if button
  #       button.textContent = if stepResultsElement.style.display == 'none' then '📊' else '📈'
  #       button.title = if stepResultsElement.style.display == 'none' then 'Show all step results' else 'Hide step results'


  # Enhanced step result display with better error handling
  displayStepResult: (step_data) =>
    @taskResultsManager.handleStepResultResponse(step_data)


  # Get alchemical stage name for step number
  getAlchemicalStage: (step_number) =>
    @taskResultsManager.getAlchemicalStage(step_number)


  # HTML escaping function to prevent XSS attacks
  escapeHtml: (text) =>
    @taskResultsManager.escapeHtml(text)


  # Safe substring utility function that handles all data types with XSS protection
  safeSubstring: (value, maxLength) =>
    @taskResultsManager.extractTextPreview(value, maxLength)


  # Message Handling
  handleMessage: (e) =>
    console.debug "[Pythia] Handling message:", e.data
    data = JSON.parse e.data
    
    if 'success' is data.status
      @isThinking = false
      return do @updateSendButton  
    
    switch data.method
      when 'status'
        @showStatus data.result.type, data.result.data, data.result.uuid
      when 'answer'
        @isThinking = false
        do @updateSendButton
        if data.result.logs?
          data.result.logs.forEach (l) =>
            switch l.type
              when 'prelude' then @log 'ai', null, l.data
              when 'say'     then @log 'ai', null, l.data.message
      when 'task'
        @handleTaskResponse data.result
      when 'step_result'
        @handleStepResult data.result
      when 'toolResult'
        # Special handling for task evaluation results
        console.log("DEBUG: toolResult received:", data.result)
        
        if data.result?.task?.id && data.result?.alchemical_progression
          @renderTaskEvaluation data.result
        else
          resultJson = JSON.stringify data.result, null, 2
          
          if resultJson.length > 300
            @log 'system', null, "<details><summary>🔧 Tool Result (#{resultJson.length} chars)</summary><pre>#{resultJson}</pre></details>"
          else
            @log 'system', null, "<pre>#{resultJson}</pre>"
      when 'completion'
        @log 'ai', null, "<pre>#{data.result.snippet}</pre>"
      when 'attach'
        @attachSelection data.result.data
      when 'error'
        @log 'error', null, "<pre>#{data.result.error}\\n#{(data.result.backtrace or []).join '\\n'}</pre>"
      else
        @log 'system', null, "<pre>#{JSON.stringify data, null, 2}</pre>"


  # Handle task method responses
  handleTaskResponse: (result) =>
    @magnumOpus.handleTaskResponse(result)


  # Handle step result responses
  handleStepResult: (result) =>
    @magnumOpus.handleStepResult(result)


  # Render comprehensive task evaluation results
  renderTaskEvaluation: (evaluation) =>
    @magnumOpus.renderTaskEvaluation(evaluation)


  # Attachment Handling
  match_selection_range = /([0-9]+)(?:\:([0-9]+))?(?:-([0-9]+)(?:\:([0-9]+))?)?/


  renderAttachmentPreview: (data, args = {}) =>
    { is_preview = true } = args
    attachment_uuid = data.uuid
    line = data.line
    column = data.column
    selection_range = data.selection_range
    file_html = data.file_html
    content = data.content
    selection_html = data.selection_html
    lines = data.lines

    content ||= 'No content preview available.'
    
    preview = document.createElement 'div'
    preview.id = "attachment_#{attachment_uuid}"
    preview.className = 'attachment-preview'
    attachment_content = if selection_html then """
      <div class=\"attachment-content\">
        <div>#{selection_html}</div>
      </div>
    """ else ''
    
    console.log "SELECTION RANGE", selection_range
      
    [selection_range, line, column] = if selection_range
      [_, from_line, from_column, to_line, to_column] = 
        selection_range.match @match_selection_range
      if to_line
        ["<span>Selection: <span>#{selection_range}</span></span>", 0, 0]
      else
        ['', from_line, from_column]
    else ['', 0, 0]
      
    line = unless line then '' else "<span>Line: <span>#{line}</span></span>"
    column = unless column then '' else "<span>Column: <span>#{column}</span></span>"
    remove_attachment_button = if is_preview
      """<button onclick=\"pythia.removeAttachment('#{attachment_uuid}')\">✕
         </button>"""
    else ''
      
    attachment_meta = if selection_range.length 
      """<div class=\"attachment-meta\">
        #{line}
        #{column}
        #{selection_range}
      </div>""" 
    else ''

    preview.innerHTML = """
      <div class=\"attachment-header\">
        <span>📎 #{@replaceFileTags file_html}</span>
        #{remove_attachment_button}
      </div>
      #{attachment_meta}
      #{attachment_content}
    """
    
    preview
    

  attachSelection: (data) =>
    console.log "attachSelection", data
        
    attachment_uuid = do crypto.randomUUID
    
    # Add to attachments array with UUID
    attachment_data = { data..., uuid: attachment_uuid }
    @attachments.push(attachment_data)
    
    preview = @renderAttachmentPreview attachment_data
    
    inputBar = document.getElementById 'input-bar'
    inputBar.insertAdjacentElement "beforebegin", preview


  removeAttachment: (attachment_uuid) =>
    # Remove from attachments array
    @attachments = @attachments.filter((att) => att.uuid != attachment_uuid)
    
    # Remove from DOM
    do document.getElementById("attachment_#{attachment_uuid}").remove


  # User Interaction
  onSendBtnClick: (e) =>
    if @isThinking
      do @stopThinking
    else
      do @askAI
      do @adjustInputHeight


  askAI: =>
    text = document.getElementById('chat-input').value
    return unless text?.length
    
    # Check if this is a command (starts with /)
    if text.startsWith('/')
      @processCommand(text)
      document.getElementById('chat-input').value = ''
      return
    
    # remove old attachments
    
    
    # Prepare all attachments for sending
    attachments_data = @attachments.map (att) =>
      (
        file: att.file,
        selection: att.selection,
        line: att.line,
        column: att.column,
        selection_range: att.selection_range
      )
    
    @ws.send JSON.stringify method: 'askAI', params: (
      prompt: text, record: true, attachments: attachments_data )
    
    # Log user message with attachments in history
    attachments_html = if @attachments.length > 0
      @attachments.map((att) =>
        @removeAttachment att.uuid
        
        (@renderAttachmentPreview att, is_preview: false).innerHTML
      ).join('<br>')
    else
      ''
    
    message_html = @escapeHtml(text)
    message_html += "<div class=\"message-attachments\">#{attachments_html}</div>" if attachments_html
    
    uuid = @log 'user', null, message_html
    document.getElementById('chat-input').value = ''
    @isThinking = true
    do @updateSendButton


  stopThinking: =>
    @ws.send JSON.stringify method: 'stopThinking'
    @isThinking = false
    do @updateSendButton
    

  # Command Processing
  processCommand: (command) =>
    command = command.trim()
    parts = command.split(' ')
    cmd = parts[0].toLowerCase()
    args = parts.slice(1)
    
    switch cmd
      when '/list', '/tasks'
        @listTasks()
      when '/start', '/execute'
        taskId = parseInt(args[0])
        if isNaN(taskId)
          @log 'system', null, '<span class="error">Invalid task ID. Usage: /start &lt;task_id&gt;</span>'
        else
          @executeTask(taskId)
      when '/status'
        taskId = parseInt(args[0])
        if isNaN(taskId)
          @log 'system', null, '<span class="error">Invalid task ID. Usage: /status &lt;task_id&gt;</span>'
        else
          @getTaskStatus(taskId)
      when '/help'
        @showCommandHelp()
      else
        @log 'system', null, "<span class=\"error\">Unknown command: #{cmd}. Type /help for available commands.</span>"


  listTasks: =>
    @ws.send JSON.stringify method: 'manageTask', params: (action: 'list')


  executeTask: (taskId) =>
    @ws.send JSON.stringify method: 'manageTask', params: (action: 'execute', id: taskId)


  getTaskStatus: (taskId) =>
    @ws.send JSON.stringify method: 'manageTask', params: (action: 'get', id: taskId)


  showCommandHelp: =>
    helpText = """
    <div class=\"command-help\">
      <h3>Available Commands</h3>
      <ul>
        <li><code>/list</code> or <code>/tasks</code> - List all active tasks</li>
        <li><code>/start &lt;task_id&gt;</code> or <code>/execute &lt;task_id&gt;</code> - Start/execute a task</li>
        <li><code>/status &lt;task_id&gt;</code> - Get detailed status of a task</li>
        <li><code>/help</code> - Show this help message</li>
      </ul>
    </div>
    """
    @log 'system', null, helpText


  updateSendButton: =>
    sendBtn = document.getElementById 'send-btn'
    sendBtnGlyph = sendBtn.getElementsByClassName('send-glyph')[0]
    
    if @isThinking
      sendBtnGlyph.textContent = '⏹'
      sendBtn.classList.add 'thinking'
    else
      sendBtnGlyph.textContent = '⚡️'
      sendBtn.classList.remove 'thinking'


  # Utility Functions
  replaceFileTags: (content) =>
    match_file = RegExp "<file(?: path=\"([^\"]+)\")?(?: line=\"([^\"]+)\")?" +
                "(?: column=\"([^\"]+)\")?>([^<]+)<\\/file>", 'g'
    match_file_html =
      RegExp "\&lt;file(?: path=\&quot;((?!.*?\&quot;).*?)\&quot;)?" +
             "(?: line=\&quot;((?!.*?\&quot;).*?)\&quot;)?" +
             "(?: column=\&quot;((?!.*?\&quot;).*?)\&quot;)?\&gt;" +
             "(.*?(?<!\&lt;))\&lt;\\/file\&gt;", 'g'
             
    replace_matches = (match, path, line, column, displayName) =>
      path ||= displayName
      href = "txmt://open/?url=file://#{@project_root}/#{encodeURIComponent(path)}"
      href += "\&line=#{line}" if line
      href += "\&column=#{column}" if column
      
      # Add markdown preview icon for .md files
      if path.toLowerCase().endsWith('.md')
        preview_link = @createMarkdownPreviewLink(path, line, column)
        "<a href=\"#{href}\" class=\"file-link\">#{displayName}</a>#{preview_link}"
      else
        "<a href=\"#{href}\" class=\"file-link\">#{displayName}</a>"
      
    content = content.replace match_file, replace_matches
    content.replace match_file_html, replace_matches


  # Create markdown preview link with eye icon
  createMarkdownPreviewLink: (filePath, line = null, column = null) =>
    """
    <span class="markdown-preview-container">
      <a data-url="#{filePath}" class="markdown-preview-link"
         title="Preview markdown" onclick="return window.pythia.openMarkdownPreview(event, '#{filePath}');">
        👁️
      </a>
    </span>
    """


  # Open markdown preview in popup window
  openMarkdownPreview: (event, fileUrl) =>
    event.preventDefault()
    
    # Extract file path from URL
    filePath = fileUrl.replace(/^file:\/\//, '')
    
    console.log filePath
    # Create preview window
    previewWindow = window.open('', 'markdown-preview',
      'width=800,height=600,resizable=yes,scrollbars=yes,toolbar=no')
    # setTimeout ->
    previewWindow.resizeTo 800, 600
    previewWindow.moveTo (screen.availWidth - 800) / 2, (screen.availHeight - 600) / 2
    # , 200
    console.log previewWindow
    if previewWindow
      # Load and render markdown content
      @loadAndRenderMarkdown(previewWindow, filePath)
    
    return false


  # Load and render markdown content via HTTP request
  loadAndRenderMarkdown: (previewWindow, filePath) =>
    # Make HTTP request to backend for markdown preview
    fetch "http://127.0.0.1:#{@port}/api", 
      method: 'POST',
      headers: 
        'Content-Type': 'application/json'
      body: JSON.stringify
        method: 'previewMarkdown',
        params: 
          file_path: filePath
    .then (response) => do response.json
    .then (data) =>
      console.log data
      if 'previewMarkdown' is data.method
        # Render the markdown in the preview window
        @renderMarkdownPreview previewWindow, data.result
      else
        console.error 'Preview request failed:', data
        @renderMarkdownPreview previewWindow, 
          error: 'Preview failed',
          content: 'Failed to load markdown preview',
          html: '<p>Failed to load markdown preview</p>'
    .catch (error) =>
      console.error 'Preview error:', error
      @renderMarkdownPreview previewWindow, 
        error: error.message,
        content: 'Error loading markdown preview',
        html: '<p>Error loading markdown preview</p>'
        

  # TextMate link handler for hierarchical structure items
  createTextMateLink: (filePath, line = null, column = null) =>
    return unless @project_root
    href = "txmt://open/?url=file://#{@project_root}/#{encodeURIComponent(filePath)}"
    href += "\&line=#{line}" if line
    href += "\&column=#{column}" if column
    href


  # Render markdown preview in popup window
  renderMarkdownPreview: (previewWindow, markdownData) =>
    # Handle error cases
    if markdownData.error
      { error, content, html } = markdownData
      html ||= "<p style='color: red;'>Error: #{error}</p><pre>#{content || 'No content available'}</pre>"
      title = 'Markdown Preview Error'
    else
      { content, html, title } = markdownData
    
    previewWindow.document.write html
    # previewWindow.document.write """
    #   <!DOCTYPE html>
    #   <html>
    #   <head>
    #     <title>📄 #{title || 'Markdown Preview'}</title>
    #     <meta charset="utf-8">
    #     <style>
    #       body {
    #         font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    #         margin: 20px;
    #         line-height: 1.6;
    #         background: #f8f9fa;
    #         color: #333;
    #       }
    #       .markdown-container {
    #         max-width: 800px;
    #         margin: 0 auto;
    #         background: white;
    #         padding: 30px;
    #         border-radius: 8px;
    #         box-shadow: 0 2px 10px rgba(0,0,0,0.1);
    #       }
    #       h1, h2, h3, h4, h5, h6 {
    #         color: #2c3e50;
    #         margin-top: 1.5em;
    #         margin-bottom: 0.5em;
    #       }
    #       code {
    #         background: #f1f3f4;
    #         padding: 2px 6px;
    #         border-radius: 3px;
    #         font-family: 'Monaco', 'Menlo', monospace;
    #         font-size: 0.9em;
    #       }
    #       pre {
    #         background: #2d3748;
    #         color: #e2e8f0;
    #         padding: 15px;
    #         border-radius: 5px;
    #         overflow-x: auto;
    #       }
    #       pre code {
    #         background: none;
    #         padding: 0;
    #       }
    #       blockquote {
    #         border-left: 4px solid #3498db;
    #         margin: 20px 0;
    #         padding-left: 20px;
    #         color: #7f8c8d;
    #         font-style: italic;
    #       }
    #       table {
    #         border-collapse: collapse;
    #         width: 100%;
    #         margin: 20px 0;
    #       }
    #       th, td {
    #         border: 1px solid #ddd;
    #         padding: 8px 12px;
    #         text-align: left;
    #       }
    #       th {
    #         background: #f2f2f2;
    #         font-weight: bold;
    #       }
    #       a {
    #         color: #3498db;
    #         text-decoration: none;
    #       }
    #       a:hover {
    #         text-decoration: underline;
    #       }
    #       .header {
    #         border-bottom: 2px solid #3498db;
    #         padding-bottom: 10px;
    #         margin-bottom: 20px;
    #       }
    #       .error {
    #         color: #e74c3c;
    #         background: #fdf2f2;
    #         border: 1px solid #e74c3c;
    #         padding: 15px;
    #         border-radius: 5px;
    #         margin-bottom: 20px;
    #       }
    #     </style>
    #   </head>
    #   <body>
    #     <div class="markdown-container">
    #       #{if markdownData.error then "<div class='error'><strong>Error:</strong> #{markdownData.error}</div>" else ""}
    #       <div class="header">
    #         <h1>📄 #{title || 'Markdown Preview'}</h1>
    #       </div>
    #       <div class="content">
    #         #{html || content}
    #       </div>
    #     </div>
    #   </body>
    #   </html>
    # """
    
    previewWindow.document.close()


  escapeHtml: (unsafe) =>
    unsafe
    .replace /&/g, "&amp;"
    .replace /</g, "&lt;"
    .replace />/g, "&gt;"
    .replace /"/g, "&quot;"
    .replace /'/g, "&#039;"

  # Hierarchy preview rendering moved to Horologium class
  # to eliminate code duplication and improve maintainability

  # Alchemical stage mapping
  getAlchemicalStage: (step) =>
    @magnumOpus.getAlchemicalStage(step)

  # Task log persistence methods
  storeTaskLog: (task_id, content, timestamp) =>
    # Get existing logs or initialize empty array
    logs = JSON.parse(localStorage.getItem("task_#{task_id}_logs") || '[]')
    
    # Add new log entry
    logs.push {
      content: content,
      timestamp: timestamp,
      added_at: new Date().toISOString()
    }
    
    # Store back to localStorage
    localStorage.setItem "task_#{task_id}_logs", JSON.stringify(logs)
    
    # Also update in-memory cache
    @activeTaskLogs[task_id] = logs

  loadTaskLogs: (task_id) =>
    # Try to load from localStorage first
    logs = JSON.parse(localStorage.getItem("task_#{task_id}_logs") || '[]')
    
    # Update in-memory cache
    @activeTaskLogs[task_id] = logs
    
    # Render logs if container exists
    taskLogElement = document.getElementById "task-logs-#{task_id}"
    return unless taskLogElement
    
    task_log_entries = taskLogElement.querySelector('.task-log-entries')
    return unless task_log_entries
    
    # Store current scroll position to preserve user view
    currentScrollPosition = task_log_entries.scrollTop
    isNearBottom = (task_log_entries.scrollHeight - currentScrollPosition - task_log_entries.clientHeight) < 50
    
    # Clear existing logs and render all stored logs
    task_log_entries.innerHTML = ''
    
    logs.forEach (log) =>
      logEntry = document.createElement 'div'
      logEntry.className = 'task-log-entry'
      logEntry.innerHTML = """
        <span class=\"log-time\">#{log.timestamp}</span>
        <span class=\"log-message\">#{log.content}</span>
      """
      task_log_entries.appendChild logEntry
    
    # Restore scroll position - only auto-scroll if user was near bottom
    if isNearBottom
      task_log_entries.scrollTop = task_log_entries.scrollHeight
    else
      task_log_entries.scrollTop = currentScrollPosition

  clearTaskLogs: (task_id) =>
    # Remove from localStorage
    localStorage.removeItem "task_#{task_id}_logs"
    
    # Remove from in-memory cache
    delete @activeTaskLogs[task_id]


  # UI Initialization
  initializeUI: =>
    sendBtn = document.getElementById 'send-btn'
    sendBtnGlyph = sendBtn.getElementsByClassName('send-glyph')[0]
    sendBtn.onclick = @onSendBtnClick

    # Handle Enter and Shift+Enter for textarea
    document.getElementById('chat-input').addEventListener 'keydown', (e) =>
      if e.key == 'Enter' and not e.shiftKey
        do e.preventDefault
        do @askAI
        do @adjustInputHeight

    # Initialize Mermaid.js
    @initializeMermaid()

  adjustInputHeight: => 
    textarea = document.getElementById 'chat-input'
    textarea.style.height = 'auto'
    textarea.style.height = "#{textarea.scrollHeight}px"


  # Format symbolic patch results for human-readable display with syntax highlighting
  formatSymbolicPatchResult: (result, filePath) =>
    # Parse the result if it's a JSON string
    try
      parsedResult = if typeof result is 'string' then JSON.parse(result) else result
    catch e
      console.error 'Failed to parse symbolic patch result:', e, result
      return 'No transformations applied'
    
    return 'No transformations applied' unless parsedResult?.length > 0
    
    output = ""
    parsedResult.forEach (transformation, index) =>
      # Generate chunk ID for the transformation
      chunkId = "symbolic-chunk-#{index + 1}"
      
      # Create a beautiful chunk with syntax highlighting
      output += """
        <div class=\"chunk\" id=\"#{chunkId}\">
          <div class=\"chunk-header\">
            <span class=\"chunk-number\">#{index + 1}</span>
            <span class=\"chunk-title\">Symbolic Transformation</span>
            <span class=\"chunk-badge\">#{transformation.language || 'text'}</span>
          </div>
          <div class=\"chunk-content\">
      """
      
      # Show file location if available
      if transformation.file
        output += """
          <div class=\"chunk-meta\">
            <strong>File:</strong> <file path=\"#{transformation.file}\">#{transformation.file}</file>
          </div>
        """
      else if filePath
        output += """
          <div class=\"chunk-meta\">
            <strong>File:</strong> <file path=\"#{filePath}\">#{filePath}</file>
          </div>
        """
      
      # Show line/column information
      if transformation.range?.start
        line = transformation.range.start.line + 1  # Convert 0-based to 1-based
        column = transformation.range.start.column + 1
        output += """
          <div class=\"chunk-meta\">
            <strong>Location:</strong> Line #{line}, Column #{column}
          </div>
        """
      
      # Show original text and replacement with beautiful diff styling
      if transformation.text && transformation.replacement
        # Determine language for syntax highlighting
        lang = transformation.language || 'text'
        
        output += """
          <div class=\"chunk-diff\">
            <div class=\"diff-section\">
              <div class=\"diff-header\">Original</div>
              <pre><code class=\"language-#{lang}\">#{@escapeHtml(transformation.text)}</code></pre>
            </div>
            <div class=\"diff-section\">
              <div class=\"diff-header\">Replacement</div>
              <pre><code class=\"language-#{lang}\">#{@escapeHtml(transformation.replacement)}</code></pre>
            </div>
          </div>
        """
      
      output += """
          </div>
        </div>
      """
    
    output


  # HTML escape utility
  escapeHtml: (text) =>
    return '' unless text
    text.toString()
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;')


  setupEventListeners: =>
    textarea = document.getElementById 'chat-input'
    textarea.addEventListener 'input', @adjustInputHeight
    setTimeout @adjustInputHeight, 100
    
    # Single document-level click handler for Mermaid diagrams
    document.addEventListener 'click', (event) =>
      # Check if click is on a Mermaid SVG or its container
      target = event.target
      mermaidContainer = target.closest('.mermaid')
      
      if mermaidContainer
        event.stopPropagation()
        event.preventDefault()
        @openMermaidPopup(mermaidContainer.innerHTML)


  # Mermaid.js Integration
  initializeMermaid: =>
    # Initialize Mermaid with detailed Argonaut theme styling
    if window.mermaid
      mermaid.initialize({
        startOnLoad: false,
        theme: 'dark',
        securityLevel: 'loose',
        fontFamily: 'var(--mono)',
        themeCSS: '''
          /* Node styling */
          .node rect, .node circle, .node ellipse, .node polygon {
            fill: var(--argonaut-deep);
            stroke: var(--argonaut-azure);
            stroke-width: 3px;
            rx: 8px;
            ry: 8px;
          }
          .node.label {
            color: var(--argonaut-azure);
            font-weight: bold;
            font-family: var(--hermetic);
          }
          
          /* Edge styling */
          .edgePath path {
            stroke: var(--argonaut-steel);
            stroke-width: 2px;
            fill: none;
          }
          .edgeLabel:not(:empty) {
            background-color: var(--argonaut-void);
            color: var(--argonaut-steel);
            font-weight: bold;
            font-family: var(--sans);
            border: 1px solid var(--argonaut-steel);
            border-radius: 4px;
            padding: 0px 6px;
          }
          
          /* Cluster styling */
          .cluster rect {
            fill: var(--argonaut-void);
            stroke: var(--argonaut-mystic);
            stroke-width: 3px;
            rx: 12px;
            ry: 12px;
          }
          .cluster text {
            fill: var(--argonaut-mystic);
            font-weight: bold;
            font-family: var(--sigil);
          }
          
          /* Message text and labels */
          .messageText {
            fill: var(--argonaut-emerald);
            font-weight: bold;
            font-family: var(--sans);
          }
          
          .note rect {
            fill: var(--argonaut-void);
            stroke: var(--argonaut-amber);
            stroke-width: 2px;
          }
          
          .note text {
            fill: var(--argonaut-amber);
            font-weight: bold;
            font-family: var(--mono);
          }
          
          .actor {
            fill: var(--argonaut-deep);
            stroke: var(--argonaut-cosmic);
            stroke-width: 3px;
          }
          
          .actor text {
            fill: var(--argonaut-cosmic);
            font-weight: bold;
            font-family: var(--hermetic);
          }
          
          .label-container {
            background-color: var(--argonaut-void);
            color: var(--argonaut-steel);
            font-weight: bold;
            font-family: var(--sans);
          }
          
          .nodeLabel {
            color: var(--argonaut-azure);
            font-weight: bold;
            font-family: var(--hermetic);
          }
        '''
      })
      
      # Render any existing Mermaid diagrams
      @renderMermaidDiagrams()

  renderMermaidDiagrams: =>
    console.log('renderMermaidDiagrams called, window.mermaid:', window.mermaid)
    console.log('mermaid.render function exists:', !!window.mermaid?.render)
    
    # Initialize mermaid if not already done
    if window.mermaid && !window.mermaid._initialized
      window.mermaid.initialize({startOnLoad: false})
      window.mermaid._initialized = true
      console.log('Mermaid initialized')
    
    if window.mermaid && window.mermaid.run
      # Find all Mermaid containers in message content only (not input area)
      messageContainer = document.querySelector('#message-container')
      if messageContainer
        mermaidContainers = messageContainer.querySelectorAll('.mermaid')
      else
        mermaidContainers = document.querySelectorAll('.mermaid')
        
      console.log('Found mermaid containers in messages:', mermaidContainers.length)
      
      # Use mermaid.run for auto-rendering
      window.mermaid.run({
        querySelector: '.mermaid',
        nodes: Array.from(mermaidContainers)
      })
      console.log('mermaid.run called for all containers')
      
      # Add pointer cursor to indicate clickability
      setTimeout(() =>
        mermaidContainers.forEach((container) =>
          svgElement = container.querySelector('svg')
          if svgElement
            svgElement.style.cursor = 'pointer'
            console.log('Added pointer cursor to Mermaid diagram')
        )
      , 500)
    else
      console.error('Mermaid not available or run method missing')
  
  openMermaidPopup: (svgContent) =>
    console.log('Opening Mermaid diagram in new window')
    
    # Create a new window with the SVG content
    popupWindow = window.open('', '_blank', 'width=800,height=600,scrollbars=yes')
    
    if popupWindow
      # Get the glyphs.css href from the current document
      glyphsStylesheet = document.getElementById('glyphs-stylesheet')
      glyphsHref = if glyphsStylesheet then glyphsStylesheet.href else '/Support/pythia/glyphs.css'
      
      # Remove any inline max-width styles from the SVG content
      cleanedSvgContent = svgContent.replace(/style=\"[^\"]*max-width[^\"]*\"/gi, '')
      
      # Create HTML content for the new window
      htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
          <title>Mermaid Diagram</title>
          <link rel="stylesheet" href="#{glyphsHref}" id="glyphs-stylesheet">
          <style>
            body {
              margin: 0;
              padding: 0;
              background: #000C16;
              display: flex;
              justify-content: center;
              align-items: center;
              min-height: 100vh;
              font-family: 'Argonaut', 'JetBrains Mono', monospace;
              overflow: hidden;
            }
            .mermaid-content {
              width: 100vw;
              height: 100vh;
              display: flex;
              justify-content: center;
              align-items: center;
            }
            svg {
              width: 100% !important;
              height: 100% !important;
              max-width: none !important;
              max-height: none !important;
            }
            .label { font-size: 0.8em; }
          </style>
        </head>
        <body>
          <div class="mermaid-content">
            #{cleanedSvgContent}
          </div>
        </body>
        </html>
      """
      
      popupWindow.document.write(htmlContent)
      popupWindow.document.close()
      console.log('Mermaid popup window opened successfully with glyphs.css')
    else
      console.error('Failed to open popup window - popup might be blocked')
      alert('Please allow popups for this site to view Mermaid diagrams in full screen')

  # Scroll to Bottom Button
  createScrollToBottomButton: =>
    @scrollButton = document.createElement('button')
    @scrollButton.innerHTML = '↓'
    @scrollButton.className = 'scroll-to-bottom'
    
    @scrollButton.onclick = @scrollToBottom
    
    # Add to input bar container
    document.body.appendChild(@scrollButton)
    
    # Add scroll detection and resize observers
    messagesElement = document.getElementById('messages')
    if messagesElement
      messagesElement.addEventListener('scroll', @checkScrollPosition)
      window.addEventListener('resize', @updateScrollButtonPosition)
      
      # Observe input height changes
      chatInput = document.getElementById('chat-input')
      if chatInput
        @inputObserver = new MutationObserver(@updateScrollButtonPosition)
        @inputObserver.observe(chatInput, { attributes: true, attributeFilter: ['style'] })
    
    # Initial position update
    @updateScrollButtonPosition()


  updateScrollButtonPosition: =>
    return unless @scrollButton
    
    messagesElement = document.getElementById('messages')
    
    return unless messagesElement 
    
    # Calculate position above input, centered horizontally
    messagesRect = messagesElement.getBoundingClientRect()
    messagesHeight = messagesRect.height
    
    # Position button 10px above the input bar
    buttonTop = -32 - 10 - 16  + messagesHeight
    
    @scrollButton.style.top = buttonTop + 'px'
    

  checkScrollPosition: =>
    messagesElement = document.getElementById('messages') 
    return unless messagesElement && @scrollButton
    
    isNearBottom = (messagesElement.scrollHeight - 
                    messagesElement.scrollTop - 
                    messagesElement.offsetHeight) < 100
    
    if isNearBottom
      @scrollButton.classList.remove('visible')
    else
      @scrollButton.classList.add('visible')


  scrollToBottom: =>
    messagesElement = document.getElementById('messages')
    return unless messagesElement
    
    messagesElement.scrollTo({
      top: messagesElement.scrollHeight,
      behavior: 'smooth'
    })


  # Main Initialization
  initialize: =>
    window.addEventListener 'DOMContentLoaded', @loadMessages
    do @startLoggingInterval
    do @setupEventListeners
    do @initializeUI



# Initialize Pythia
window.pythia = new Pythia
do pythia.initialize

history.pushState null, null, location.href
window.onpopstate = -> history.go 1
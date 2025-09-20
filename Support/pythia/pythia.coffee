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


  # Message Persistence
  saveMessages: =>
    messages = Array.from(document.querySelectorAll('#messages > div:not(.error)')).map (el) ->
      className: el.className
      innerHTML: el.innerHTML
    localStorage.setItem @STORAGE_KEY, JSON.stringify(messages.slice(-@MAX_MESSAGES))


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
          m.scrollTop = existing.offsetTop - m.offsetHeight + existing.offsetHeight
      else
        is_near_bottom = (m.scrollHeight - m.scrollTop - m.offsetHeight) < m.offsetHeight * 0.5
        el = document.createElement 'div'
        el.className = cls
        el.innerHTML = html
        el.id = uuid
        m.appendChild el
        m.scrollTop = m.scrollHeight if is_near_bottom
        
      do @saveMessages
      
    if uuid
      @messageBuffer.push add_message
    else do add_message


  # Status Display System
  showStatus: (type, data, uuid) =>
    timestamp = new Date(data.timestamp * 1000).toLocaleTimeString() if data.timestamp
    
    console.log "showStatus", timestamp, type, data
    
    switch type
      when 'thinking'
        if data.content
          @log 'system', uuid, """
            <details>
              <summary>#{data.message} <small>#{timestamp || ''}</small></summary>
              #{data.content}
            </details>"""
        else
          @log 'status', uuid, "#{data.message || 'Consulting the astral codex...'} <small>#{timestamp || ''}</small>"
      when 'file_reading'
        @log 'status', uuid, "#{@replaceFileTags data.message} <small>#{timestamp || ''}</small>"    
      when 'divination'
        @log 'status', uuid, "#{data.message || 'Consulting the astral codex...'} <small>#{timestamp || ''}</small>"
      when 'file_read_complete'
        @log 'status', uuid, """
          <details>
            <summary>#{@replaceFileTags data.message} <small>#{timestamp || ''}</small></summary>
            #{data.content}
          </details>"""
      when 'file_read_fail'
        @log 'status', uuid, """
          <details>
            <summary>#{@replaceFileTags data.message} <small>#{timestamp || ''}</small></summary>
            #{data.error}
          </details>"""
      when 'file_creating'
        @log 'status', uuid, "#{@replaceFileTags data.message} <small>#{timestamp || ''}</small>"
      when 'file_created'
        @log 'status', uuid, """
          <details>
            <summary>#{@replaceFileTags data.message} <small>#{timestamp || ''}</small></summary>
            #{data.content}
          </details>"""
      when 'temp_file_created'
        @log 'status', uuid, """
          <details>
            <summary>#{@replaceFileTags data.message} <small>#{timestamp || ''}</small></summary>
            #{data.content}
          </details>"""

      when 'tool_starting'
        @log 'status', uuid, "⚡️ Invoking <code>#{data.tool}</code>... <small>#{timestamp || ''}</small>"
        if data.args and Object.keys(data.args).length > 0 and JSON.stringify(data.args).length < 200
          @log 'status', uuid, "&nbsp;&nbsp;↳ Args: <code>#{JSON.stringify(data.args)}</code>"
      when 'file_patching'
        @log 'status', uuid, """
          <details>
            <summary>#{@replaceFileTags data.message} <small>#{timestamp || ''}</small></summary>
            #{data.diff}
          </details>"""
      when 'file_patched'
        @log 'status', uuid, """
          <details>
            <summary>#{@replaceFileTags data.message} <small>#{timestamp || ''}</small></summary>
            #{@replaceFileTags data.diff}
          </details>"""
      when 'file_patched_fail'
        @log 'status', uuid, """
          <details>
            <summary>#{@replaceFileTags data.message} <small>#{timestamp || ''}</small></summary>
            #{data.diff}
          </details>"""
      when 'symbolic_patch_start'
        @log 'status', uuid, "#{@replaceFileTags data.message} <small>#{timestamp || ''}</small>"
      when 'symbolic_patch_complete'
        @log 'status', uuid, """
          <details>
            <summary>#{@replaceFileTags data.message} <small>#{timestamp || ''}</small></summary>
            #{@replaceFileTags data.result_display}
          </details>"""
      when 'symbolic_patch_fail'
        @log 'status', uuid, """
          <details>
            <summary>#{@replaceFileTags data.message} <small>#{timestamp || ''}</small></summary>
            #{data.error}
          </details>"""
      when 'command_executing'
        @log 'status', uuid, "#{data.message} <small>#{timestamp || ''}</small>"
      when 'command_completed'
        @log 'status', uuid, """
          <details class="run_command">
            <summary>#{data.message} <small>#{timestamp || ''}</small></summary>
            <pre>#{data.content}</pre>
          </details>"""
      when 'file_renaming'
        @log 'status', uuid, "#{@replaceFileTags data.message} <small>#{timestamp || ''}</small>"
      when 'file_renamed'
        @log 'status', uuid, "#{@replaceFileTags data.message} <small>#{timestamp || ''}</small>"      
      when 'memory_storing'
        @log 'status', uuid, "#{data.message} <small>#{timestamp || ''}</small>"
      when 'memory_stored'
        @log 'status', uuid, "#{data.message} <small>#{timestamp || ''}</small>"
      when 'memory_searching'
        @log 'status', uuid, "#{data.message} <small>#{timestamp || ''}</small>"
      when 'memory_found'
        @log 'status', uuid, """
          <details>
            <summary>#{data.message} <small>#{timestamp || ''}</small></summary>
            <pre>#{data.content}</pre>
          </details>"""
      when 'info'
        @log 'status', uuid, "#{@replaceFileTags data.message} <small>#{timestamp || ''}</small>"    
      when 'tool_completed'
        if data.result?.error
          @log 'status', uuid, "❌ Tool <code>#{data.tool}</code> failed: #{data.result.error} <small>#{timestamp || ''}</small>"
          if data.result.error
            @log 'system', uuid, "<details><summary>❌ Error details</summary><pre>#{data.result.error}</pre></details>"
        else
          @log 'status', uuid, "✅ Tool <code>#{data.tool}</code> completed <small>#{timestamp || ''}</small>"
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
          @log 'status', uuid, "💭 AI responding... <small>#{timestamp || ''}</small>"
      when 'oracle_conjuration_revelation'
        @log 'system', uuid, """
          <details>
            <summary>#{data.message} <small>#{timestamp || ''}</small></summary>
            #{@replaceFileTags data.content}
          </details>"""
      when 'oracle_conjuration'
        @log 'status', uuid, """
          <details>
            <summary>#{data.message} <small>#{timestamp || ''}</small></summary>
            #{@replaceFileTags data.content}
          </details>"""
      when 'plan_announced'
        @log 'status', uuid, "📋Plan: #{data.steps?.join ' → '} <small>#{timestamp || ''}</small>"
      when 'processing'
        @log 'status', uuid, "#{data.message} <small>#{timestamp || ''}</small>"
      when 'completed'
        @log 'status', uuid, "#{data.summary || 'Completed'} <small>#{timestamp || ''}</small>"
      when 'server_error'
        @log 'error', uuid, "#{data.error} <small>#{timestamp || ''}</small>"
      when 'system_error'
        @log 'error', uuid, "#{data.error} <small>#{timestamp || ''}</small>"
      when 'system_message'
        @log 'system', uuid, "#{data.message} <small>#{timestamp || ''}</small>"
      when 'note_added'
        @log 'system', uuid, """
          <details>
            <summary>#{data.message} <small>#{timestamp || ''}</small></summary>
            #{@replaceFileTags data.content}
          </details>"""
      when 'note_removed'
        @log 'system', uuid, """
          <details>
            <summary>#{data.message} <small>#{timestamp || ''}</small></summary>
            #{@replaceFileTags data.content}
          </details>"""
      when 'note_updated'
        @log 'system', uuid, """
          <details>
            <summary>#{data.message} <small>#{timestamp || ''}</small></summary>
            #{@replaceFileTags data.content}
          </details>"""
      when 'notes_recalled'
        @log 'system', uuid, """
          <details>
            <summary>#{data.message} <small>#{timestamp || ''}</small></summary>
            #{@replaceFileTags data.notes}
          </details>"""
      when 'aegis_unveiled'
        @log 'system', uuid, """
          <details>
            <summary>#{data.message} <small>#{timestamp || ''}</small></summary>
            #{@replaceFileTags data.content}
          </details>"""
      when 'file_overview'
        horologium = new window.Horologium()
        overviewHtml = horologium.renderFileOverview data
        @log 'status', uuid, """
          <details>
            <summary>#{@replaceFileTags data.message} <small>#{timestamp || ''}</small></summary>
            #{overviewHtml}
          </details>"""
      when 'task_started'
        @isThinking = true
        do @updateSendButton
        @log 'status', uuid, "#{data.message} <small>#{timestamp || ''}</small>"
        @renderTaskProgress data
      when 'task_completed'
        @isThinking = false
        do @updateSendButton
        @log 'system', uuid, "#{data.message} <small>#{timestamp || ''}</small>"
        @renderTaskProgress data
      when 'task_created'
        @log 'system', uuid, """
          <details>
            <summary>#{data.message} <small>#{timestamp || ''}</small></summary>
            <div class=\"task-description\">#{data.plan}</div>
          </details>"""
        @renderTaskProgress data
      when 'task_updated'
        if data.show_progress
          @log 'system', uuid, "#{data.message} <small>#{timestamp || ''}</small>"
        @renderTaskProgress data
      when 'task_step_completed'
        @log 'system', uuid, """
          <details>
            <summary>#{data.message} <small>#{timestamp || ''}</small></summary>
            #{data.result}
          </details>"""
      when 'task_step_rejected'
        @log 'system', uuid, """
          <details>
            <summary>#{data.message} <small>#{timestamp || ''}</small></summary>
            #{data.reason}
          </details>"""
      when 'task_removed'
        @isThinking = false
        do @updateSendButton
        @log 'system', uuid, "#{data.message} <small>#{timestamp || ''}</small>"
      when 'task_list'
        @log 'system', uuid, """
          <details>
            <summary>#{data.message} <small>#{timestamp || ''}</small></summary>
            <div class="task-list">#{data.content}</div>
          </details>"""
      when 'task_log_added'
        task_id = data.id or data.task_id
        # Add to existing task log display in unified panel
        taskLogElement = document.getElementById "task-logs-#{task_id}"
        
        # If no log container exists in unified panel, ensure task progress is rendered first
        unless taskLogElement
          # Render the task progress panel which now includes logs container
          @renderTaskProgress data
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
        @log 'system', uuid, "#{data.message} <small>#{timestamp || ''}</small>"
        data.content.forEach (entry) =>
          @log 'user', null, "#{entry.prompt} <small>#{timestamp || ''}</small>"
          @log 'ai', null, "#{entry.answer} <small>#{timestamp || ''}</small>"


  # Task Management
  toggleTaskProgress: (task_id) =>
    taskProgress = document.getElementById 'task_progress'
    
    # Toggle between expanded, collapsed, and compact views
    if taskProgress.classList.contains('collapsed')
      # Currently collapsed -> switch to compact view
      taskProgress.classList.remove('collapsed')
      taskProgress.classList.add('compact-view')
    else if taskProgress.classList.contains('compact-view')
      # Currently compact -> expand fully
      taskProgress.classList.remove('compact-view')
    else
      # Currently expanded -> collapse to minimal
      taskProgress.classList.add('collapsed')
    
    button = taskProgress.querySelector('.task-header button')
    if taskProgress.classList.contains('collapsed')
      button.textContent = '▶'
      button.title = 'Show compact view'
    else if taskProgress.classList.contains('compact-view')
      button.textContent = '▼'
      button.title = 'Expand fully'
    else
      button.textContent = '▼'
      button.title = 'Minimize task panel'


  renderTaskProgress: (task) =>
    taskProgress = document.getElementById 'task_progress'
    task_id = task.task_id or task.id
    
    unless taskProgress
      taskProgress = document.createElement 'div'
      taskProgress.id = "task_progress"
      taskProgress.className = 'task-progress'
      
      inputBar = document.getElementById 'input-bar'
      inputBar.insertAdjacentElement "beforebegin", taskProgress
    
    # Fix step counting: current_step is number of completed steps (0-10)
    # display_step should be current step number (1-10), 0 for Initium
    current_step = task.current_step || 0
    display_step = if current_step == 0 then 0 else current_step  # 0 for Initium, 1-10 for steps
    progress_percent = Math.round(current_step/10*100)
    
    # Get alchemical stage based on progress
    alchemical_stage = @getAlchemicalStage(display_step)
    
    # Add step results to display if available
    step_results = task.step_results || []
    result_display = if step_results.length > 0
      latest_result = step_results[step_results.length - 1]
      """<div class=\"step-result-preview\">Latest Result: #{latest_result.substring(0, 100)}#{if latest_result.length > 100 then '...' else ''}</div>"""
    else
      ''
    
    # Check if we already have progress elements
    taskHeader = taskProgress.querySelector('.task-header')
    progressBar = taskProgress.querySelector('.progress-bar')
    taskControls = taskProgress.querySelector('.task-controls')
    logsContainer = document.getElementById "task-logs-#{task_id}"
    
    # If we don't have a task progress structure yet, create it
    unless taskHeader
      # Display task plan as description (not individual steps)
      task_plan_html = if task.plan
        """<div class=\"task-description\"><strong>Plan:</strong> #{task.plan}</div>"""
      else
        ''
      
      # Create unified task panel with progress and logs
      taskProgress.innerHTML = """
        <div class=\"task-header\">
          <strong>#{task.title}</strong>
          <span>#{alchemical_stage} (#{if display_step == 0 then 'Initium' else display_step}/10)</span>
          <button onclick=\"pythia.toggleTaskProgress('#{task_id}')\" title=\"Toggle task panel\">▼</button>
        </div>
        <div class=\"progress-bar\">
          <div class=\"progress\" style=\"width: #{progress_percent}%\"></div>
        </div>
        #{result_display}
        #{task_plan_html}
        <div class=\"task-controls\">
          <button onclick=\"pythia.ws.send(JSON.stringify({ method: 'task', params: { action: 'pause', id: #{task_id} }}))\" title=\"Pause task\">⏸</button>
          <button onclick=\"pythia.ws.send(JSON.stringify({ method: 'task', params: { action: 'resume', id: #{task_id} }}))\" title=\"Resume task\">▶</button>
          <button onclick=\"pythia.ws.send(JSON.stringify({ method: 'task', params: { action: 'cancel', id: #{task_id} }}))\" title=\"Cancel task\">✕</button>
        </div>
        <div class=\"task-logs-container\" id=\"task-logs-#{task_id}\">
          <div class=\"task-log-header\">
            <h4>📋 Task ##{task_id} Execution Log - #{alchemical_stage} (#{display_step}/10)</h4>
            <button onclick=\"pythia.toggleTaskLogs('#{task_id}')\" title=\"Hide logs\">📋</button>
          </div>
          <div class=\"task-log-entries\"></div>
        </div>
      """
      
      # Start in compact view by default for better UX
      taskProgress.classList.add('compact-view')
      
      # Load any existing logs from storage
      @loadTaskLogs(task_id)
    else
      # Just update the progress elements without destroying logs
      headerSpan = taskHeader.querySelector('span')
      headerSpan.textContent = "#{alchemical_stage} (#{if display_step == 0 then 'Initium' else display_step}/10)" if headerSpan
      
      progress = progressBar.querySelector('.progress')
      progress.classList.add do alchemical_stage.toLowerCase
      progress.style.width = "#{progress_percent}%" if progress
      
      # Update step result display if available
      resultElement = taskProgress.querySelector('.step-result-preview')
      if step_results.length > 0
        latest_result = step_results[step_results.length - 1]
        resultHtml = "Latest Result: #{latest_result.substring(0, 100)}#{if latest_result.length > 100 then '...' else ''}"
        if resultElement
          resultElement.innerHTML = resultHtml
        else
          resultElement = document.createElement 'div'
          resultElement.className = 'step-result-preview'
          resultElement.innerHTML = resultHtml
          # Insert after progress bar
          progressBar.insertAdjacentElement 'afterend', resultElement
      else if resultElement
        resultElement.remove()
      
      # Ensure logs container exists and is properly loaded
      unless logsContainer
        logsContainer = document.createElement 'div'
        logsContainer.className = 'task-logs-container'
        logsContainer.id = "task-logs-#{task_id}"
        logsContainer.innerHTML = """
          <div class=\"task-log-header\">
            <h4>📋 Task ##{task_id} Execution Log - #{alchemical_stage} (#{display_step}/10)</h4>
            <button onclick=\"pythia.toggleTaskLogs('#{task_id}')\" title=\"Hide logs\">📋</button>
          </div>
          <div class=\"task-log-entries\"></div>
        """
        taskProgress.appendChild logsContainer
      else
        # Preserve existing log entries - only update header and progress
        logEntries = logsContainer.querySelector('.task-log-entries')
        if logEntries
          # Store current scroll position and content to preserve user view
          scrollPosition = logEntries.scrollTop
          logContent = logEntries.innerHTML
          
          # Update the log header to show current progress
          logHeader = logsContainer.querySelector('.task-log-header h4')
          logHeader.textContent = "📋 Task ##{task_id} Execution Log - #{alchemical_stage} (#{display_step}/10)" if logHeader
          
          # Restore the log content and scroll position
          logEntries.innerHTML = logContent
          logEntries.scrollTop = scrollPosition
      
      # Always load logs from storage when panel is accessed
      @loadTaskLogs(task_id)


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
      when 'toolResult'
        # Special handling for task evaluation results
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

  # Render comprehensive task evaluation results
  renderTaskEvaluation: (evaluation) =>
    task = evaluation.task
    stepResults = evaluation.step_results || {}
    executionLogs = evaluation.execution_logs || []
    progression = evaluation.alchemical_progression || []
    
    # Create detailed evaluation HTML
    evaluationHtml = """
      <div class=\"task-evaluation\">
        <div class=\"evaluation-header\">
          <h3>📊 Task Evaluation: #{task.title}</h3>
          <span class=\"task-status\">Status: #{task.status}</span>
        </div>
        
        <div class=\"task-details\">
          <div><strong>ID:</strong> #{task.id}</div>
          <div><strong>Current Stage:</strong> #{task.current_stage} (Step #{task.current_step}/#{task.total_steps})</div>
          <div><strong>Progress:</strong> #{task.progress_percentage}%</div>
          <div><strong>Created:</strong> #{task.created_at}</div>
          <div><strong>Updated:</strong> #{task.updated_at}</div>
        </div>
        
        <div class=\"task-plan\">
          <h4>Plan:</h4>
          <p>#{task.plan || 'No plan specified'}</p>
        </div>
        
        <div class=\"alchemical-progression\">
          <h4>Alchemical Progression:</h4>
          <div class=\"progression-steps\">
    """
    
    # Add alchemical progression steps
    progression.forEach (stage) =>
      statusClass = if stage.completed then 'completed' else if stage.current then 'current' else 'pending'
      evaluationHtml += """
            <div class=\"progression-step #{statusClass}\">
              <span class=\"step-number\">#{stage.step}</span>
              <span class=\"stage-name\">#{stage.stage}</span>
              <span class=\"status-indicator\">#{if stage.completed then '✅' else if stage.current then '⏳' else '⏱'}</span>
            </div>
      """
    
    evaluationHtml += """
          </div>
        </div>
        
        <div class=\"step-results\">
          <h4>Step Results:</h4>
          <pre>#{JSON.stringify(stepResults, null, 2)}</pre>
        </div>
        
        <div class=\"execution-logs\">
          <h4>Execution Logs (#{executionLogs.length} entries):</h4>
          <div class=\"log-entries\">
    """
    
    # Add execution logs
    executionLogs.forEach (log, index) =>
      if index < 10  # Show only last 10 logs to avoid overwhelming
        evaluationHtml += """
            <div class=\"log-entry\">
              <span class=\"log-index\">#{index + 1}.</span>
              <span class=\"log-content\">#{log}</span>
            </div>
        """
    
    if executionLogs.length > 10
      evaluationHtml += """
            <div class=\"log-more\">... and #{executionLogs.length - 10} more log entries</div>
      """
    
    evaluationHtml += """
          </div>
        </div>
      </div>
    """
    
    @log 'system', null, evaluationHtml


  # Attachment Handling
  match_selection_range = /([0-9]+)(?:\:([0-9]+))?(?:-([0-9]+)(?:\:([0-9]+))?)?/


  renderAttachmentPreview: (data, args = {}) =>
    { is_preview = true } = args
    { line, column, selection_range, file_html, content, selection_html, 
      lines, uuid: attachment_uuid } = data

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
      do @adjustHeight
      do @askAI


  askAI: =>
    text = document.getElementById('chat-input').value
    return unless text?.length
    
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
      "<a href=\"#{href}\" class=\"file-link\">#{displayName}</a>"
      
    content = content.replace match_file, replace_matches
    content.replace match_file_html, replace_matches


  # TextMate link handler for hierarchical structure items
  createTextMateLink: (filePath, line = null, column = null) =>
    return unless @project_root
    href = "txmt://open/?url=file://#{@project_root}/#{encodeURIComponent(filePath)}"
    href += "\&line=#{line}" if line
    href += "\&column=#{column}" if column
    href


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
    stages = [
      'Nigredo',      # Step 1: Understanding the prima materia
      'Albedo',       # Step 2: Defining the purified solution
      'Citrinitas',   # Step 3: Exploring golden implementation paths
      'Rubedo',       # Step 4: Selecting the philosopher\'s stone
      'Solve',        # Step 5: Identifying required dissolutions
      'Coagula',      # Step 6: Implementing solid transformations
      'Test',         # Step 7: Probing the elixir\'s purity
      'Purify',       # Step 8: Edge cases as alchemical impurities
      'Validate',     # Step 9: Ensuring the elixir\'s perfection
      'Documentatio'  # Step 10: Inscribing the magnum opus
    ]
    stages[step - 1] || 'Initium'

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
        do @adjustHeight

  adjustHeight: => 
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
    textarea.addEventListener 'input', @adjustHeight
    do @adjustHeight


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
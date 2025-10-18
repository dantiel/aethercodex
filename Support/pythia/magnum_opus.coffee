###
MagnumOpus - Comprehensive Task and Step Results Management
Centralized class for all task-related functionality including step results, progress tracking,
and alchemical progression management.

Hermetic Principles Applied:
- Mentalism: Clear mental models for task progression
- Correspondence: Consistent patterns across task states
- Vibration: Dynamic updates and real-time feedback
- Polarity: Balance between detailed views and overviews
- Rhythm: Natural flow of task execution stages
- Cause_Effect: Clear relationship between actions and results
- Gender: Integration of masculine (action) and feminine (reflection) principles
###

class MagnumOpus
  constructor: (@pythia) ->
    @stepResults = {}
    @taskProgress = {}

  # Alchemical stages for step naming
  getAlchemicalStage: (step) =>
    stages = [
      'Nigredo', 'Albedo', 'Citrinitas', 'Rubedo',
      'Coagula', 'Solve', 'Test', 'Purificatio', 'Documentatio'
    ]
    stages[step - 1] || 'Unknown'

  ###
  Task Progress Management
  ###

  # Update task progress display with comprehensive step results
  updateTaskProgress: (task) =>
    task_id = task.task_id or task.id
    element_id = "task_progress" #"-#{task_id}"
    taskProgress = document.getElementById element_id
    
    console.log("DEBUG: Task data received:", task)
    console.log("DEBUG: Task ID:", task_id)
    console.log("DEBUG: Task step_results:", task.step_results)
    
    unless taskProgress
      taskProgress = document.createElement 'div'
      taskProgress.id = element_id
      taskProgress.className = 'task-progress'
      
      inputBar = document.getElementById 'input-bar'
      inputBar.insertAdjacentElement "beforebegin", taskProgress
    
    # Calculate progress metrics
    current_step = task.current_step || 0
    display_step = if current_step == 0 then 0 else current_step
    progress_percent = Math.round current_step / 10 * 100
    alchemical_stage = @getAlchemicalStage(display_step)
    
    # Generate step results preview
    result_display = @generateStepResultsPreview(task_id, task.step_results, display_step)
    
    # Check if we already have progress elements
    taskHeader = taskProgress.querySelector('.task-header')
    progressBar = taskProgress.querySelector('.progress-bar')
    taskControls = taskProgress.querySelector('.task-controls')
    logsContainer = document.getElementById "task-logs-#{task_id}"
    
    # If we don't have a task progress structure yet, create it
    unless taskHeader
      task_plan_html = if task.plan
        """<div class=\"task-description\"><strong>Plan:</strong> #{task.plan}</div>"""
      else
        ''
      
      # Create unified task panel with progress and logs
      taskProgress.innerHTML = @generateTaskProgressHTML(task, task_id, alchemical_stage, display_step, progress_percent, result_display, task_plan_html)
      
      # Start in compact view by default for better UX
      # taskProgress.classList.add('compact-view')
      
      # Load any existing logs from storage
      @pythia.loadTaskLogs(task_id)
    else
      # Just update the progress elements without destroying logs
      headerSpan = taskHeader.querySelector('span')
      headerSpan.textContent = "#{alchemical_stage} (#{if display_step == 0 then 'Initium' else display_step}/10)" if headerSpan
      
      progress = progressBar.querySelector('.progress')
      progress.classList.add alchemical_stage.toLowerCase()
      progress.style.width = "#{progress_percent}%" if progress
      
      # Update step result display if available
      @updateStepResultsDisplay(taskProgress, task_id, task.step_results, display_step)
      
      # Ensure logs container exists and is properly loaded
      unless logsContainer
        logsContainer = document.createElement 'div'
        logsContainer.className = 'task-logs-container'
        logsContainer.id = "task-logs-#{task_id}"
        logsContainer.innerHTML = @generateLogsContainerHTML(task_id, alchemical_stage, display_step)
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
      @pythia.loadTaskLogs(task_id)

  # Generate task progress HTML structure
  generateTaskProgressHTML: (task, task_id, alchemical_stage, display_step, progress_percent, result_display, task_plan_html) =>
    """
      <div class=\"task-header\">
        <strong>#{task.title}</strong>
        <span>#{alchemical_stage} (#{if display_step == 0 then 'Initium' else display_step}/10)</span>
        <button onclick=\"pythia.toggleTaskProgress('#{task_id}')\" title=\"Toggle task panel\">▼</button>
      </div>
      <div class=\"progress-bar\">
        <div class=\"progress\" style=\"width: #{progress_percent}%\"></div>
      </div>
      <div class=\"content\">
        <div class=\"step-results-container\">
          <h4>📊 Step Results</h4>
          <div class=\"step-results\" id=\"step-results-#{task_id}\">
            #{result_display}
          </div>
        </div>
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
      </div>
    """

  # Generate logs container HTML
  generateLogsContainerHTML: (task_id, alchemical_stage, display_step) =>
    """
      <div class=\"task-log-header\">
        <h4>📋 Task ##{task_id} Execution Log - #{alchemical_stage} (#{display_step}/10)</h4>
        <button onclick=\"pythia.toggleTaskLogs('#{task_id}')\" title=\"Hide logs\">📋</button>
      </div>
      <div class=\"task-log-entries\"></div>
    """

  ###
  Step Results Management
  ###

  # Generate step results preview for task progress panel
  generateStepResultsPreview: (task_id, step_results, current_step) =>
    return '' unless step_results
    
    # Handle different step results formats
    if typeof step_results == 'string'
      try
        step_results = JSON.parse(step_results)
      catch e
        return ''
    
    return '' unless Object.keys(step_results).length > 0
    
    # Sort steps numerically
    sorted_steps = Object.keys(step_results).sort((a, b) => Number(a) - Number(b))
    
    # Get current step result if available
    current_step_result = if current_step > 0 then step_results[current_step] else null
    
    # Generate preview HTML
    preview_html = """
      <div class=\"step-results-preview\">
        <div class=\"step-results-header\">
          <strong>📊 Step Results (#{sorted_steps.length} steps)</strong>
          <button class=\"step-results-toggle\" onclick=\"pythia.toggleStepResults('#{task_id}')\" title=\"Show all step results\">📊</button>
        </div>
    """
    
    # Add current step result if available
    if current_step_result
      preview_text = @extractStepResultText(current_step_result)
      if preview_text
        preview_html += """
          <div class=\"current-step-result\">
            <strong>Current Step (#{@getAlchemicalStage(current_step)}):</strong>
            <div class=\"step-preview\">#{preview_text}</div>
          </div>
        """
    
    preview_html += """
        <div class=\"step-results\" id=\"step-results-#{task_id}\" style=\"display: none;\">
    """
    
    # Add all step results in collapsible format
    sorted_steps.forEach (step) =>
      step_result = step_results[step]
      step_text = @extractStepResultText(step_result)
      if step_text
        preview_html += """
          <div class=\"step-result-item\">
            <button class=\"step-link\" onclick=\"pythia.showStepResult('#{task_id}', #{step})\" title=\"View full step result\">
              Step #{step}
            </button>
            <div class=\"step-preview\">
              <h4>#{@getAlchemicalStage(Number(step))}</h4>
              #{step_text}</div>
          </div>
        """
    
    preview_html += """
        </div>
      </div>
    """
    
    return preview_html

  # Update step results display in existing task progress
  updateStepResultsDisplay: (taskProgress, task_id, step_results, current_step) =>
    return unless step_results
    
    # Find or create step results container
    stepResultsContainer = taskProgress.querySelector('.step-results-preview')
    
    if stepResultsContainer
      # Update existing container
      newStepResults = @generateStepResultsPreview(task_id, step_results, current_step)
      tempDiv = document.createElement('div')
      tempDiv.innerHTML = newStepResults
      
      newStepResultsContainer = tempDiv.querySelector('.step-results-preview')
      if newStepResultsContainer
        stepResultsContainer.parentNode.replaceChild(newStepResultsContainer, stepResultsContainer)
    else
      # Add new step results container
      stepResultsHTML = @generateStepResultsPreview(task_id, step_results, current_step)
      contentDiv = taskProgress.querySelector('.content')
      if contentDiv
        contentDiv.insertAdjacentHTML('afterbegin', stepResultsHTML)

  # Generate comprehensive step results grid for task evaluation
  generateStepResultsGrid: (task_id, step_results) =>
    return '<div class="no-results">No step results available</div>' unless step_results
    
    # Handle different step results formats
    if typeof step_results == 'string'
      try
        step_results = JSON.parse(step_results)
      catch e
        return '<div class="no-results">Invalid step results format</div>'
    
    return '<div class="no-results">No step results available</div>' unless Object.keys(step_results).length > 0
    
    # Sort steps numerically
    sorted_steps = Object.keys(step_results).sort((a, b) => Number(a) - Number(b))
    
    grid_html = """
      <div class=\"step-results-grid\">
        <h4>Step Results (#{sorted_steps.length} steps)</h4>
        <div class=\"step-grid\">
    """
    
    sorted_steps.forEach (step) =>
      step_result = step_results[step]
      step_text = @extractStepResultText(step_result)
      step_stage = @getAlchemicalStage(Number(step))
      
      if step_text
        grid_html += """
          <div class=\"step-grid-item\">
            <div class=\"step-header\">
              <strong>#{step_stage} (Step #{step})</strong>
              <button class=\"step-view-btn\" onclick=\"pythia.showStepResult('#{task_id}', #{step})\" title=\"View full step result\">🔍</button>
            </div>
            <div class=\"step-preview\">#{step_text}</div>
          </div>
        """
    
    grid_html += """
        </div>
      </div>
    """
    
    return grid_html

  # Extract text from step result (handles various formats)
  extractStepResultText: (step_result) =>
    return '' unless step_result
    
    # Backend already converts markdown to HTML using Scriptorium
    # Return as-is for display
    if typeof step_result == 'string'
      return step_result
    else if typeof step_result == 'object'
      # Handle object case
      if step_result.result
        return step_result.result
      else if step_result.content
        return step_result.content
      else
        # Convert object to string representation
        try
          json_str = JSON.stringify(step_result, null, 2)
          return "<pre>#{json_str}</pre>"
        catch e
          return String(step_result)
    else
      return step_result.toString()

  # Truncate text for preview display
  truncateText: (text, max_length) =>
    return '' unless text
    text = String(text)
    if text.length > max_length
      return text.substring(0, max_length) + '...'
    else
      return text

  ###
  Task Evaluation and Response Handling
  ###

  # Render comprehensive task evaluation results
  renderTaskEvaluation: (evaluation) =>
    console.log('Evaluation data:', evaluation)
    task = evaluation.task
    stepResults = evaluation.formatted_step_results || evaluation.step_results || {}
    executionLogs = evaluation.execution_logs || []
    progression = evaluation.alchemical_progression || []
    
    console.log('Step results data:', stepResults)
    
    # Create clickable step results display
    stepResultsHtml = @generateStepResultsGrid(task.id, stepResults)
    
    # Create detailed evaluation HTML
    evaluationHtml = @generateTaskEvaluationHTML(task, stepResultsHtml, progression, executionLogs)
    
    @pythia.log 'system', null, evaluationHtml

  # Generate task evaluation HTML
  generateTaskEvaluationHTML: (task, stepResultsHtml, progression, executionLogs) =>
    """
      <div class=\"task-evaluation\">
        <div class=\"evaluation-header\">
          <h3>📊 Task Evaluation: #{@escapeHtml(task.title || 'Untitled')}</h3>
          <span class="task-status">Status: #{@escapeHtml(task.status || 'unknown')}</span>
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
            #{@generateProgressionHTML(progression)}
          </div>
        </div>
        
        <div class=\"step-results\">
          #{stepResultsHtml}
        </div>
        
        <div class=\"execution-logs\">
          <h4>Execution Logs (#{executionLogs.length} entries):</h4>
          <div class=\"log-entries\">
            #{@generateExecutionLogsHTML(executionLogs)}
          </div>
        </div>
      </div>
    """

  # Generate alchemical progression HTML
  generateProgressionHTML: (progression) =>
    progression_html = ''
    progression.forEach (stage) =>
      statusClass = if stage.completed then 'completed' else if stage.current then 'current' else 'pending'
      progression_html += """
        <div class=\"progression-step #{statusClass}\">
          <span class=\"step-number\">#{stage.step}</span>
          <span class=\"stage-name\">#{stage.stage}</span>
          <span class=\"status-indicator\">#{if stage.completed then '✅' else if stage.current then '⏳' else '⏱'}</span>
        </div>
      """
    return progression_html

  # Generate execution logs HTML
  generateExecutionLogsHTML: (executionLogs) =>
    logs_html = ''
    executionLogs.forEach (log, index) =>
      if index < 10  # Show only last 10 logs to avoid overwhelming
        logs_html += """
          <div class=\"log-entry\">
            <span class=\"log-index\">#{index + 1}.</span>
            <span class=\"log-content\">#{log}</span>
          </div>
        """
    
    if executionLogs.length > 10
      logs_html += """
        <div class=\"log-more\">... and #{executionLogs.length - 10} more log entries</div>
      """
    
    return logs_html

  # Handle task method responses
  handleTaskResponse: (result) =>
    if result.ok
      if result.result && result.task_id
        # This is a task execution response
        @pythia.log 'system', null, "Task #{result.task_id} executed successfully"
      else if result.result
        # This is a step result response
        @pythia.log 'system', null, "<h4>Step #{result.step} Result (#{@getAlchemicalStage(result.step)})</h4><pre>#{result.result}</pre>"
      else if result.task
        # This is a full task response
        @renderTaskEvaluation result
      else if result.tasks
        # This is a task list response
        @renderTaskList result.tasks
      else if result.message
        # This is a simple message response
        @pythia.log 'system', null, result.message

  # Handle step result messages
  handleStepResult: (result) =>
    console.log("DEBUG: Step result received:", result)
    
    if result.ok && result.result
      # Display step result immediately
      task_id = result.task_id
      step_name = @getAlchemicalStage(result.step) || "Step #{result.step}"
      @pythia.log 'system', null, """
        <details open>
          <summary><strong>📊 #{step_name} Result</strong></summary>
          <div class="step-result-content">#{result.result}</div>
        </details>
      """
      
      # Also update task progress with the new step result
      if task_id
        @pythia.ws.send JSON.stringify
          method: 'task'
          params:
            action: 'evaluate'
            id: task_id
    else
      @pythia.log 'error', null, "Step result error: #{result.error}"

  ###
  Task List Management
  ###

  # Render list of tasks
  renderTaskList: (tasks) =>
    if tasks && tasks.length > 0
      task_list = tasks.map((task) =>
        """
        <div class="task-item">
          <strong>Task #{task.id}:</strong> #{task.title || 'Untitled'}
          <br><small>Status: #{task.status || 'unknown'}</small>
          <br><small>Created: #{task.created_at || 'unknown'}</small>
        </div>
        """
      ).join('')
      
      @pythia.log 'system', null, """
        <details open>
          <summary><strong>📋 Active Tasks (#{tasks.length})</strong></summary>
          <div class="task-list">
            #{task_list}
          </div>
        </details>
      """
    else
      @pythia.log 'system', null, "No active tasks found."

  ###
  Alchemical Stage Management
  Utility Methods
  ###

  # Escape HTML for safe display
  escapeHtml: (text) =>
    return '' unless text
    text.toString()
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;')

  # Show step result via websocket
  showStepResult: (task_id, step_number) =>
    console.log "showStepResult2"
    @pythia.ws.send JSON.stringify
      method: 'showStepResult'
      params:
        task_id: parseInt task_id
        step_number: step_number

  # Toggle step results visibility
  toggleStepResults: (task_id) =>
    stepResultsElement = document.getElementById "step-results-#{task_id}"
    if stepResultsElement
      stepResultsElement.style.display = if stepResultsElement.style.display == 'none' then 'block' else 'none'
      button = stepResultsElement.previousElementSibling?.querySelector('.step-results-toggle')
      if button
        button.textContent = if stepResultsElement.style.display == 'none' then '📊' else '📈'
        button.title = if stepResultsElement.style.display == 'none' then 'Show all step results' else 'Hide step results'

  # Toggle task progress panel
  toggleTaskProgress: (task_id) =>
    element_id = "task_progress" #"-#{task_id}"
    taskProgress = document.getElementById element_id
    
    return unless taskProgress
    
    if taskProgress.classList.contains('collapsed')
      taskProgress.classList.remove('collapsed')
      taskProgress.classList.add('expanded')
    else
      taskProgress.classList.add('collapsed')
      taskProgress.classList.remove('expanded')
    
    button = document.querySelector("##{element_id} button")
    if button
      if taskProgress.classList.contains('collapsed')
        button.textContent = '▶'
        button.title = 'Expand task panel'
      else
        button.textContent = '▼'
        button.title = 'Collapse task panel'

  # Toggle task logs visibility
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
        
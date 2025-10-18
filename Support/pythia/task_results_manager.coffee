# Task Results Manager
# Centralized class for handling task results display and step navigation
# Refactored from duplicated code in pythia.coffee

class TaskResultsManager
  constructor: (@pythia) ->

  # Parse step results from various formats (string, object, etc.)
  parseStepResults: (step_results) ->
    # Handle null/undefined
    return {} unless step_results?
    
    # Handle string JSON
    if typeof step_results == 'string'
      try
        return JSON.parse(step_results)
      catch
        return {}
    
    # Handle object
    if typeof step_results == 'object'
      return step_results
    
    # Default to empty object
    return {}

  # Get latest step result
  getLatestStepResult: (step_results) ->
    parsed_results = @parseStepResults(step_results)
    
    # Filter to numeric keys only
    numeric_keys = Object.keys(parsed_results).filter((key) -> !isNaN(Number(key)))
    return null unless numeric_keys.length > 0
    
    latest_step = Math.max(...numeric_keys.map(Number))
    return {
      step: latest_step,
      result: parsed_results[latest_step]
    }

  # Extract step text from various result formats
  extractStepText: (step_result) ->
    return '' unless step_result?
    
    if typeof step_result == 'string'
      return step_result
    else if step_result && step_result.result
      return step_result.result
    else if step_result && step_result.content
      return step_result.content
    else if step_result && step_result.message
      return step_result.message
    else if step_result && step_result.text
      return step_result.text
    else if step_result && step_result.answer
      return step_result.answer
    else
      try
        return JSON.stringify(step_result)
      catch
        return '[Complex object]'

  # Generate step links HTML for navigation
  generateStepLinks: (task_id, step_results, current_step = null) ->
    parsed_results = @parseStepResults(step_results)
    return '' if Object.keys(parsed_results).length == 0
    
    step_links = ''
    
    # Sort steps numerically
    Object.keys(parsed_results).sort((a, b) => Number(a) - Number(b)).forEach (step_num) =>
      step_name = @pythia.getAlchemicalStage(Number(step_num)) || "Step #{step_num}"
      step_result = parsed_results[step_num]
      
      step_text = @extractStepText(step_result)
      step_summary = @pythia.safeSubstring(step_text, 50)
      
      # Add ellipsis if truncated
      if typeof step_text == 'string' && step_text.length > 50
        step_summary += '...'
      else if typeof step_text != 'string' && String(step_text).length > 50
        step_summary += '...'
      
      # Escape step_name to prevent XSS
      escaped_step_name = @pythia.escapeHtml(step_name)
      
      # Add visual indicator for current step
      is_current_step = Number(step_num) == current_step
      step_class = if is_current_step then 'step-result-item current-step' else 'step-result-item'
      
      step_links += """
        <div class=\"#{step_class}\" onclick=\"pythia.showStepResult('#{task_id}', #{step_num})\">
          <span class=\"step-number\">#{step_num}</span>
          <div class=\"step-content\">
            <strong>#{escaped_step_name}</strong>
            <div class=\"step-summary\">#{step_summary}</div>
          </div>
        </div>
      """
    
    return step_links

  # Generate step results preview HTML
  generateStepResultsPreview: (task_id, step_results, current_step = null) ->
    parsed_results = @parseStepResults(step_results)
    return '' if Object.keys(parsed_results).length == 0
    
    latest = @getLatestStepResult(step_results)
    return '' unless latest
    
    latest_text = @extractStepText(latest.result)
    truncated_result = @pythia.safeSubstring(latest_text, 100)
    
    truncation_dots = if (typeof latest_text == 'string' and latest_text.length > 100) or
                         (typeof latest_text != 'string' and String(latest_text).length > 100)
                        '...'
                      else ''
    
    step_links = @generateStepLinks(task_id, step_results, current_step)
    
    return """
      <div class=\"step-result-preview\">
        <strong>Latest Result:</strong>
        <span class=\"result-summary\">
          #{truncated_result}#{truncation_dots}
        </span>
        <button onclick=\"pythia.toggleStepResults('#{task_id}')\" class=\"step-results-toggle\" title=\"Show all step results\">📊</button>
      </div>
      <div class=\"step-results-details\" id=\"step-results-#{task_id}\" style=\"\">
        <h5>Step Results (#{Object.keys(parsed_results).length} steps completed):</h5>
        <div class=\"step-results-list\">
          #{step_links}
        </div>
      </div>
    """

  # Generate step results grid for evaluation view
  generateStepResultsGrid: (task_id, step_results) ->
    parsed_results = @parseStepResults(step_results)
    return '<div class="no-step-results"><h4>Step Results:</h4><p>No step results available</p></div>' if Object.keys(parsed_results).length == 0
    
    stepResultsHtml = '<h4>Step Results:</h4>'
    stepResultsHtml += '<div class="step-results-grid">'
    
    # Sort steps numerically
    Object.keys(parsed_results).sort((a, b) => Number(a) - Number(b)).forEach (stepNum) =>
      result = parsed_results[stepNum]
      stepName = @pythia.getAlchemicalStage(Number(stepNum))
      
      stepResultsHtml += """
        <div class="step-result-card" onclick="pythia.showStepResult('#{task_id}', #{stepNum})">
          <div class="step-card-header">
            <span class="step-number">Step #{stepNum}</span>
            <span class="step-name">#{@pythia.escapeHtml(stepName)}</span>
          </div>
          <div class="step-result-preview">
            #{@pythia.safeSubstring(result, 150)}
          </div>
        </div>
      """
    
    stepResultsHtml += '</div>'
    return stepResultsHtml

  # Update step results display in task progress
  updateStepResultsDisplay: (taskProgress, task_id, step_results, current_step = null) ->
    parsed_results = @parseStepResults(step_results)
    
    stepResultsDetails = taskProgress.querySelector('.step-results-details')
    stepResultsPreview = taskProgress.querySelector('.step-result-preview')
    
    if Object.keys(parsed_results).length > 0
      latest = @getLatestStepResult(step_results)
      return unless latest
      
      latest_text = @extractStepText(latest.result)
      truncated_result = @pythia.safeSubstring(latest_text, 100)
      
      truncation_dots = if (typeof latest_text == 'string' and latest_text.length > 100) or
                           (typeof latest_text != 'string' and String(latest_text).length > 100)
                          '...'
                        else ''
      
      step_links = @generateStepLinks(task_id, step_results, current_step)
      
      # Update or create step results preview
      resultHtml = """
        <strong>Latest Result:</strong>
        <span class=\"result-summary clickable-result\" onclick=\"pythia.showStepResult('#{task_id}', #{latest.step})\" title=\"Click to view full step result\">
          #{truncated_result}#{truncation_dots}
        </span>
        <button onclick=\"pythia.toggleStepResults('#{task_id}')\" class=\"step-results-toggle\" title=\"Show all step results\">📊</button>
      """
      
      if stepResultsPreview
        stepResultsPreview.innerHTML = resultHtml
      else
        stepResultsPreview = document.createElement 'div'
        stepResultsPreview.className = 'step-result-preview'
        stepResultsPreview.innerHTML = resultHtml
        # Insert after progress bar
        progressBar = taskProgress.querySelector('.progress-bar')
        progressBar.insertAdjacentElement 'afterend', stepResultsPreview if progressBar
      
      # Create or update step results details
      stepResultsHtml = """
        <div class=\"step-results-details\" id=\"step-results-#{task_id}\" style=\"\">
          <h5>Step Results (#{Object.keys(parsed_results).length} steps completed):</h5>
          <div class=\"step-results-list\">
            #{step_links}
          </div>
        </div>
      """
      
      if stepResultsDetails
        stepResultsDetails.innerHTML = stepResultsHtml
      else
        stepResultsDetails = document.createElement 'div'
        stepResultsDetails.innerHTML = stepResultsHtml
        stepResultsPreview.insertAdjacentElement 'afterend', stepResultsDetails if stepResultsPreview
    else
      # Remove step results if none exist
      stepResultsPreview?.remove()
      stepResultsDetails?.remove()

# Export the class
window.TaskResultsManager = TaskResultsManager
# Support/task_engine.rb
require_relative 'mnemosyne'
require 'timeout'

STATES = %i[pending active paused failed completed invalid cancelled]
WORKFLOW_STEPS = 10

# Step purposes for logging
STEP_PURPOSES = [
  "Understanding business need",
  "Defining ideal solution",
  "Exploring implementation options",
  "Selecting implementation candidate",
  "Identifying required code changes",
  "Implementing code changes",
  "Testing functionality",
  "Testing edge cases",
  "Validating security and performance",
  "Documenting changes"
]



class TaskEngine
  def initialize(options = {})
    mnemosyne = options[:mnemosyne] || Mnemosyne
    aetherflux = options[:aetherflux]
    
    raise ArgumentError, "Mnemosyne is required" unless mnemosyne
    raise ArgumentError, "Aetherflux is required" unless aetherflux
    
    @mnemosyne = mnemosyne
    @aetherflux = aetherflux
  end


  # Query @mnemosyne for notes related to the task's business need
  def query_notes(task_id, query)
    # Retrieve and score notes based on relevance
    notes = @mnemosyne.recall_notes(query, limit: 10)
    
    # Score notes by relevance to the business need
    scored_notes = notes.map do |note|
      {
        id: note[:id],
        content: note[:content],
        score: relevance_score(note[:content], query)
      }
    end
    
    # Sort by score descending and return top 3
    scored_notes.sort_by { |n| -n[:score] }.first(3)
  end
    
  
  # Calculate relevance score using simple keyword matching
  def relevance_score(content, query)
    query_terms = query.downcase.split
    content_terms = content.downcase.split
    
    # Count matching terms
    (query_terms & content_terms).size.to_f / query_terms.size
  end
  def generate_solution_options(task_id); end
  def evaluate_alternatives(task_id); end
  def choose_best_option(task_id); end
  def analyze_files(task_id); end
  def apply_patches(task_id); end
  def run_tests(task_id); end
  def validate_edge_scenarios(task_id); end
  def audit_and_optimize(task_id); end
  def update_documentation(task_id); end

  # Execute sub-tasks recursively, respecting max_loops
  def execute_sub_tasks(task_id, max_loops)
    sub_tasks = @mnemosyne.manage_tasks({ 'action' => 'list', 'parent_task_id' => task_id })
    sub_tasks.each do |sub_task|
      next if halted?(sub_task[:id]) || max_loops <= 0
      execute_task(sub_task[:id], max_loops: max_loops - 1)
      @mnemosyne.manage_tasks({ 'action' => 'update', 'id' => task_id, 'max_loops' => max_loops - 1 })
    end
    max_loops - 1
  end


public


  # Creates a new task with optional sub-tasks
  def create_task(prompt, parent_task_id: nil)
    response = @mnemosyne.manage_tasks({
      'action' => 'create',
      'description' => prompt,
      'parent_task_id' => parent_task_id
    })
    response['id']
  end
  

  # Executes a task, supporting recursive sub-tasks
  def execute_task(task_id, max_loops: 10)
    task = @mnemosyne.manage_tasks({ 'action' => 'list' }).find { |t| t[:id] == task_id }

    unless task && task[:status] == 'pending'
      if task && !%w[pending active].include?(task[:status])
        if task[:status] == 'cancelled'
          log_message(task_id, "Task was cancelled")
          raise RuntimeError, "Task cancelled"
        else
          log_message(task_id, "Invalid state: #{task[:status]}")
          raise RuntimeError, "Invalid state: #{task[:status]}"
        end
      end
      return
    end
  
    update_state(task_id, :active)
  
    begin
      WORKFLOW_STEPS.times do |step|
        break if halted?(task_id)

        begin
          Timeout.timeout(30) { execute_step(task_id, step + 1) }
        rescue Timeout::Error => e
          update_state(task_id, :failed)
          log_message(task_id, "Timeout in step #{step + 1}: #{e.message}")
          raise
        end
  
        update_progress(task_id, step + 1)
      end
  
      # Execute sub-tasks recursively, respecting max_loops
      if max_loops > 0
        @mnemosyne.manage_tasks({ 'action' => 'list', 'parent_task_id' => task_id }).each do |sub_task|
          next if halted?(sub_task[:id]) || max_loops <= 0
          execute_task(sub_task[:id], max_loops: max_loops - 1)
        end
        @mnemosyne.manage_tasks({ 'action' => 'update', 'id' => task_id, 'max_loops' => max_loops - 1 })
      end
  
      update_state(task_id, :completed) unless halted?(task_id)
    rescue => e
      update_state(task_id, :failed)
      log_message(task_id, "Task failed: #{e.message}")
      raise
    end
  end
  
  
private

  
  # Removed hardcoded oracle_conjuration stub
  
  
  # Executes a step dynamically using the reasoning model
  def execute_step(task_id, step_index)
    task = @mnemosyne.manage_tasks({ 'action' => 'list' }).find { |t| t[:id] == task_id }
    prompt = "Execute step #{step_index} for task #{task_id}: #{task[:description]}"
    
    begin
      response = @aetherflux.channel_oracle_conjuration(prompt: prompt)
      
      case response[:status]
      when :failure
        raise RuntimeError, response[:response]  # Raise just the response message
      when :timeout
        raise Timeout::Error, "Step timed out"
      when :success
        log_message(task_id, "Step #{step_index} completed: #{response[:response]}")
      else
        raise RuntimeError, "Unknown status: #{response[:status]}"
      end
    rescue => e
      log_message(task_id, "Step #{step_index} failed: #{e.message}")
      raise  # Propagate the error up
    end

    # Only log step purpose - actual implementation handled by conjuration
    log_message(task_id, "Executing step #{step_index}: #{STEP_PURPOSES[step_index-1]}")
  end
  

  def log_message(task_id, message)
    @mnemosyne.manage_tasks({ 'action' => 'update', 'id' => task_id, 'log' => message })
    broadcast_update(task_id)
  end


  def update_state(task_id, state)
    unless STATES.include?(state)
      raise ArgumentError, "Invalid task state: #{state}"
    end
    @mnemosyne.manage_tasks({ 'action' => 'update', 'id' => task_id, 'status' => state.to_s })
    broadcast_update(task_id)
  end
  

  def broadcast_update(task_id)
    # Send update to Pythia UI via WebSocket
  end


  def halted?(task_id)
    task = @mnemosyne.manage_tasks({ 'action' => 'list' }).find { |t| t[:id] == task_id }
    return false unless task
    
    case task[:status]
    when 'invalid'
      log_message(task_id, "Invalid task state encountered")
      raise RuntimeError, "Invalid state: invalid"
    when 'cancelled'
      log_message(task_id, "Task was cancelled")
      raise RuntimeError, "Task cancelled"
    else
      %w[paused failed].include?(task[:status])
    end
  end
  

  def update_progress(task_id, step)
    task = @mnemosyne.manage_tasks({ 'action' => 'list' }).find { |t| t[:id] == task_id }
    task[:progress] = step
    @mnemosyne.manage_tasks({ 'action' => 'update', 'id' => task_id, 'progress' => step }) if task[:id]
    broadcast_update(task_id)
  end
end
# frozen_string_literal: true

# Support/task_engine.rb
require 'timeout'


# The TaskEngine orchestrates hermetic workflows, weaving:
# - **Alchemical Steps**: 10-stage transmutation of tasks (as above, so below).
# - **Recursive Sub-Tasks**: Nested operations respecting `max_loops` like fractal iterations.
# - **Dynamic State Transitions**: Task states mirroring alchemical phases (nigredo, albedo, rubedo).
# - **Oracle Integration**: Conjuring responses via `aetherflux` for step execution.
class TaskEngine
  STATES = %i[pending active paused failed completed invalid cancelled].freeze
  WORKFLOW_STEPS = 10

  # Step purposes for logging, aligned with hermetic principles
  STEP_PURPOSES = [
    'Nigredo: Understanding the prima materia (business need)',
    'Albedo: Defining the purified solution',
    'Citrinitas: Exploring golden implementation paths',
    "Rubedo: Selecting the philosopher's stone (candidate)",
    'Solve: Identifying required dissolutions (code changes)',
    'Coagula: Implementing solid transformations',
    "Test: Probing the elixir's purity (functionality)",
    'Test: Edge cases as alchemical impurities',
    "Validate: Ensuring the elixir's perfection (security/performance)",
    'Document: Inscribing the magnum opus'
  ].freeze


  # The TaskEngine is the crucible where tasks undergo hermetic transformation.
  # It binds Mnemosyne (memory) and Aetherflux (oracle) to alchemize prompts into results.
  def initialize(options = {})
    mnemosyne = options[:mnemosyne]
    aetherflux = options[:aetherflux]

    raise ArgumentError, 'Mnemosyne (memory) is required for task alchemy' unless mnemosyne
    raise ArgumentError, 'Aetherflux (oracle) is required for conjuration' unless aetherflux

    @mnemosyne = mnemosyne
    @aetherflux = aetherflux
  end


  # Query Mnemosyne for notes, scoring them by hermetic resonance with the task's prima materia.
  def query_notes(_task_id, query)
    notes = @mnemosyne.recall_notes query, limit: 10

    # Score notes by their alignment with the query's essence
    scored_notes = notes.map do |note|
      {
        id:      note[:id],
        content: note[:content],
        score:   relevance_score(note[:content], query)
      }
    end

    # Return the top 3 notes, sorted by their resonance score
    scored_notes.sort_by { |n| -n[:score] }.first(3)
  end


  # Calculate relevance score as the ratio of shared terms (hermetic concordance).
  #
  # @param [String] content The note's text.
  # @param [String] query The search phrase.
  # @return [Float] A score between 0 (no resonance) and 1 (perfect harmony).
  def relevance_score(content, query)
    query_terms = query.downcase.split
    content_terms = content.downcase.split

    # The ratio of shared terms reflects the harmony between content and query.
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
      next if halted?(sub_task[:id]) || 0 >= max_loops

      execute_task sub_task[:id], max_loops: max_loops - 1
      @mnemosyne.manage_tasks({ 'action'    => 'update',
                                'id'        => task_id,
                                'max_loops' => max_loops - 1 })
    end
    max_loops - 1
  end


  # Creates a new task with optional sub-tasks
  def create_task(prompt, parent_task_id: nil)
    response = @mnemosyne.manage_tasks({
                                         'action'         => 'create',
                                         'description'    => prompt,
                                         'parent_task_id' => parent_task_id
                                       })

    unless response && response['ok']
      error_msg = "Task creation failed: #{response['error'] || 'Unknown error'}"
      log_message nil, error_msg
      raise error_msg.to_s
    end

    response['id']
  end


  # Executes a task, supporting recursive sub-tasks
  def execute_task(task_id, max_loops: 10)
    task = @mnemosyne.manage_tasks({ 'action' => 'list' }).find { |t| t[:id] == task_id }

    unless task && 'pending' == task[:status]
      if task && !%w[pending active].include?(task[:status])
        if 'cancelled' == task[:status]
          log_message task_id, 'Task was cancelled'
          raise 'Task cancelled'
        else
          log_message task_id, "Invalid state: #{task[:status]}"
          raise "Invalid state: #{task[:status]}"
        end
      end
      return
    end

    update_state task_id, :active

    begin
      WORKFLOW_STEPS.times do |step|
        break if halted? task_id

        begin
          Timeout.timeout(30) { execute_step task_id, step + 1 }
        rescue Timeout::Error => e
          update_state task_id, :failed
          log_message task_id, "Timeout in step #{step + 1}: #{e.message}"
          raise
        end

        update_progress task_id, step + 1
      end

      # Execute sub-tasks recursively, respecting max_loops
      if max_loops.positive?
        @mnemosyne.manage_tasks({ 'action'         => 'list',
                                  'parent_task_id' => task_id }).each do |sub_task|
          next if halted?(sub_task[:id]) || 0 >= max_loops

          execute_task sub_task[:id], max_loops: max_loops - 1
        end
        @mnemosyne.manage_tasks({ 'action'    => 'update',
                                  'id'        => task_id,
                                  'max_loops' => max_loops - 1 })
      end

      update_state task_id, :completed unless halted? task_id
    rescue StandardError => e
      update_state task_id, :failed
      log_message task_id, "Task failed: #{e.message}"
      raise
    end
  end


  private


  # Removed hardcoded oracle_conjuration stub


  # Execute a workflow step, invoking the oracle for hermetic guidance.
  #
  # @param [Integer] task_id The task's alchemical identifier.
  # @param [Integer] step_index The phase of the magnum opus (1..10).
  # @raise [RuntimeError] If the oracle's response is invalid or times out.
  def execute_step(task_id, step_index)
    task = @mnemosyne.manage_tasks({ 'action' => 'list' }).find { |t| t[:id] == task_id }
    prompt = "Execute step #{step_index} for task #{task_id}: #{task[:description]}"

    begin
      response = @aetherflux.channel_oracle_conjuration prompt: prompt

      case response[:status]
      when :failure
        raise response[:response].to_s # Raise just the response message
      when :timeout
        raise Timeout::Error, 'Step timed out'
      when :success
        log_message(task_id, "Step #{step_index} completed: #{response[:response]}")
      else
        raise "Unknown status: #{response[:status]}"
      end
    rescue StandardError => e
      log_message task_id, "Step #{step_index} failed: #{e.message}"
      raise # Propagate the error up
    end

    # Only log step purpose - actual implementation handled by conjuration
    log_message task_id, "Executing step #{step_index}: #{STEP_PURPOSES[step_index - 1]}"
  end


  def log_message(task_id, message)
    @mnemosyne.manage_tasks({ 'action' => 'update', 'id' => task_id, 'log' => message })
    broadcast_update task_id
  end


  def update_state(task_id, state)
    raise ArgumentError, "Invalid task state: #{state}" unless STATES.include? state

    @mnemosyne.manage_tasks({ 'action' => 'update', 'id' => task_id, 'status' => state.to_s })
    broadcast_update task_id
  end


  def broadcast_update(task_id)
    # Send update to Pythia UI via WebSocket
  end


  def halted?(task_id)
    task = @mnemosyne.manage_tasks({ 'action' => 'list' }).find { |t| t[:id] == task_id }
    return false unless task

    case task[:status]
    when 'invalid'
      log_message task_id, 'Invalid task state encountered'
      raise 'Invalid state: invalid'
    when 'cancelled'
      log_message task_id, 'Task was cancelled'
      raise 'Task cancelled'
    else
      %w[paused failed].include? task[:status]
    end
  end


  def update_progress(task_id, step)
    task = @mnemosyne.manage_tasks({ 'action' => 'list' }).find { |t| t[:id] == task_id }
    task[:progress] = step
    if task[:id]
      @mnemosyne.manage_tasks({ 'action'   => 'update',
                                'id'       => task_id,
                                'progress' => step })
    end
    broadcast_update task_id
  end
end

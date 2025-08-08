# Support/task_engine.rb
class TaskEngine
  STATES = %i[pending active paused failed completed]
  WORKFLOW_STEPS = 10

  def initialize(mnemosyne)
    @mnemosyne = mnemosyne
    @current_task = nil
  end

  def create_task(prompt)
    task_id = @mnemosyne.remember(
      content: prompt,
      tags: ['task'],
      links: [],
      meta: {
        state: :pending,
        progress: 0,
        max_steps: WORKFLOW_STEPS
      }
    )
    task_id
  end

  def execute_task(task_id)
    task = @mnemosyne.recall(id: task_id)
    return unless task[:meta][:state] == :pending

    update_state(task_id, :active)
    
    WORKFLOW_STEPS.times do |step|
      break if halted?(task_id)
      
      execute_step(task_id, step + 1)
      update_progress(task_id, step + 1)
    end
    
    update_state(task_id, :completed) unless halted?(task_id)
  end

  private

  def execute_step(task_id, step_index)
    # Implementation for each workflow phase
    case step_index
    when 1
      # Step 1: Understand business need
    when 2
      # Step 2: Define ideal solution
    # ... other steps
    end
  end

  def update_state(task_id, state)
    @mnemosyne.update_note(task_id, meta: { state: state })
    broadcast_update(task_id)
  end

  def broadcast_update(task_id)
    # Send update to Pythia UI via WebSocket
  end

  def halted?(task_id)
    task = @mnemosyne.recall(id: task_id)
    task[:meta][:state] == :paused || task[:meta][:state] == :failed
  end

  def update_progress(task_id, step)
    @mnemosyne.update_note(task_id, meta: { progress: step })
    broadcast_update(task_id)
  end
end
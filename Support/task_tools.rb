# frozen_string_literal: true

# Support/task_tools.rb
# Dynamic task-specific tools that automatically include task_id context

require_relative 'instrumenta'
require_relative 'prima_materia'



class TaskTools
  # Build a PrimaMateria instance with task-specific tools
  def self.build_task_tools(base_prima, task_id, task_engine)
    # Create a fresh instance with base tools
    task_prima = base_prima.clone_tools
    # Merge in task-specific tools
    task_prima.merge_tools! build_task_prima(task_id, task_engine)
    task_prima
  end


  # Build a PrimaMateria with just the task-specific tools
  def self.build_task_prima(task_id, task_engine)
    task_prima = PrimaMateria.new
    
    # Task-specific file operations
    task_prima.add_instrument :task_read_file,
                    description: 'Read a file (optionally a line range) with task context.',
                    params: {
                      path:  { type: 'string', required: true, minLength: 1 },
                      range: { type:     'array',
                               items:    { type: 'integer', minimum: 0, maximum: 10_000 },
                               minItems: 2,
                               maxItems: 2 }
                    } do |path:, range: nil|
      result = Instrumenta::PRIMA_MATERIA.read_file path: path, range: range
      result.merge task_id: task_id if result.is_a? Hash
    end
    

    # Task-specific patch operations
    task_prima.add_instrument :task_patch_file,
                    description: 'Apply targeted modifications to a file with task context.',
                    params: {
                      path: { type: 'string', required: true },
                      diff: { type: 'string', required: true }
                    } do |path:, diff:|
      result = Instrumenta::PRIMA_MATERIA.patch_file path: path, diff: diff
      result.merge task_id: task_id if result.is_a? Hash
    end


    # Task-specific memory operations
    task_prima.add_instrument :task_recall_notes,
                    description: 'Recall notes relevant to the current task context.',
                    params: {
                      query: { type: 'string', required: false },
                      limit: { type: 'integer', required: false, default: 3 }
                    } do |query: '', limit: 3|
      enhanced_query = "#{query} task_id:#{task_id}".strip
      result = Instrumenta::PRIMA_MATERIA.recall_notes query: enhanced_query, limit: limit
      result.merge task_id: task_id if result.is_a? Hash
    end


    # Task progress and state management
    task_prima.add_instrument :task_update_progress,
                    description: 'Update task progress with optional message.',
                    params: {
                      progress: { type:     'integer',
                                  required: true,
                                  minimum:  0,
                                  maximum:  10 },
                      message:  { type: 'string', required: false }
                    } do |progress:, message: nil|
      task_engine.send :update_progress, task_id, progress
      task_engine.log_message task_id, message if message
      { ok: true, task_id: task_id, progress: progress }
    end


    # Task-specific oracle conjuration
    task_prima.add_instrument :task_oracle_conjuration,
                    description: 'Invoke oracle reasoning with task context.',
                    params: {
                      prompt: { type: 'string', required: true }
                    } do |prompt:|
      enhanced_prompt = "[Task #{task_id}] #{prompt}"
      Instrumenta::PRIMA_MATERIA.oracle_conjuration prompt: enhanced_prompt
    end


    # Task step rejection with restart capability
    task_prima.add_instrument :task_reject_step,
                    description: 'Reject current step and optionally restart from specific step.',
                    params: {
                      reason:            { type: 'string', required: false },
                      restart_from_step: { type: 'integer', required: false, minimum: 1 }
                    } do |reason: nil, restart_from_step: nil|
      task_engine.send :reject_step, task_id, reason, restart_from_step
      { ok:                true,
        task_id:           task_id,
        rejected_step:     task_engine.send(:current_step, task_id),
        restart_from_step: restart_from_step }
    end


    # Task step completion
    task_prima.add_instrument :task_complete_step,
                    description: 'Complete current step with optional result.',
                    params: {
                      result: { type: 'string', required: false }
                    } do |result: nil|
      task_engine.send :complete_step, task_id, result
      { ok:             true,
        task_id:        task_id,
        completed_step: task_engine.send(:current_step, task_id),
        result:         result }
    end

    task_prima
  end
end
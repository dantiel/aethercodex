# frozen_string_literal: true

# Support/opus_instrumenta.rb
# Dynamic task-specific tools that automatically include task_id context

require_relative '../instrumentarium/instrumenta'
require_relative '../instrumentarium/prima_materia'
require_relative '../instrumentarium/horologium_aeternum'
require_relative '../oracle/error_handler'



class OpusInstrumenta
  # Build a PrimaMateria instance with task-specific tools
  def self.build_task_tools(base_prima, task_id, task_engine)
    # Create a fresh instance with base tools
    task_prima = base_prima.clone_tools.reject %i[aegis oracle_conjuration patch_file read_file
                                                  create_task]
    # Merge in task-specific tools
    task_prima.merge_tools! build_task_prima(task_id, task_engine)
    task_prima
  end


  # Build a PrimaMateria with just the task-specific tools
  def self.build_task_prima(task_id, task_engine)
    task_prima = PrimaMateria.new

    # Task creation within task context
    # task_prima.add_instrument :create_sub_task,
    #                           description: 'Create a sub-task with parent task context for complex workflows.',
    #                           params: {
    #                             title: { type: 'string', required: true, minLength: 1 },
    #                             plan:  { type: 'string', required: true, minLength: 1 },
    #                             workflow_type: { type: 'string', required: false, enum: ['full', 'simple', 'analysis'], default: 'simple' }
    #                           } do |title:, plan:, workflow_type: 'simple'|
    #   # Create sub-task with parent context and workflow type
    #   sub_task = task_engine.create_task(title: title, plan: plan, parent_task_id: task_id, workflow_type: workflow_type)
    #
    #   # Store workflow type in task metadata for simplified execution
    #   Mnemosyne.manage_tasks({
    #     'action' => 'update',
    #     'id' => sub_task['id'],
    #     'workflow_type' => workflow_type,
    #     'max_steps' => case workflow_type
    #                   when 'simple' then 3
    #                   when 'analysis' then 5
    #                   else 10
    #                   end
    #   })
    #
    #   HorologiumAeternum.task_created(**sub_task)
    #   sub_task
    # end

    # Task-specific file operations
    task_prima.add_instrument :task_read_file,
                              description: 'Read a file (optionally a line range) with task context.',
                              params: {
                                path:  { type: 'string', required: true, minLength: 1 },
                                range: { type:     'array',
                                         items:    { type: 'integer', minimum: 0, maximum: 10_000 },
                                         minItems: 2,
                                         maxItems: 2 }
                              } do |**args|
      result = Instrumenta::PRIMA_MATERIA.read_file(**args)
      result.merge task_id: task_id if result.is_a? Hash
    end

    patch_description = Instrumenta::PRIMA_MATERIA.tools[:patch_file].description
    # Task-specific patch operations
    task_prima.add_instrument :task_patch_file,
                              description: 'Apply targeted modifications to a file with task ' \
                                           "context.\n\n#{patch_description}",
                              params: {
                                path: { type: 'string', required: true },
                                diff: { type: 'string', required: true }
                              } do |path:, diff:|
      # Track file modifications in task context
      result = Instrumenta::PRIMA_MATERIA.patch_file path: path, diff: diff
      
      if result.is_a?(Hash) && result[:ok]
        # Record file modification in task notes for context continuity
        change_note = "File modified: #{path}\nDiff applied:\n#{diff.truncate(200)}"
        Mnemosyne.create_note(content: change_note, links: [path], tags: ['task_modification', "task_#{task_id}"])
      end
      
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

    # TODO this is wrong and violates our schema, instead there should be only TASK_STOP_EXECUTION 
    # # Task progress and state management
    # task_prima.add_instrument :task_update_progress,
    #                           description: 'Update task progress with optional message.',
    #                           params: {
    #                             progress: { type:     'integer',
    #                                         required: true,
    #                                         minimum:  0,
    #                                         maximum:  10 },
    #                             message:  { type: 'string', required: false }
    #                           } do |progress:, message: nil|
    #   task_engine.send :update_progress, task_id, progress
    #   task_engine.log_message task_id, message if message
    #   { ok: true, task_id: task_id, progress: progress }
    # end

    #
    # # Task-specific oracle conjuration
    # task_prima.add_instrument :task_oracle_conjuration,
    #                 description: 'Invoke oracle reasoning with task context.',
    #                 params: {
    #                   prompt: { type: 'string', required: true }
    #                 } do |prompt:|
    #   enhanced_prompt = "[Task #{task_id}] #{prompt}"
    #   Instrumenta::PRIMA_MATERIA.oracle_conjuration prompt: enhanced_prompt
    # end


    # Task step rejection with restart capability
    task_prima.add_instrument :task_reject_step,
                              description: 'Reject current step and optionally restart from specific step.',
                              params: {
                                reason:            { type: 'string', required: false },
                                restart_from_step: { type: 'integer', required: false, minimum: 1 }
                              } do |reason: nil, restart_from_step: nil|
      # Return clean divine interruption signal - engine handles step progression
      {
        __divine_interrupt: :step_rejected,
        reason: reason,
        restart_from_step: restart_from_step
      }
    end


    # Task step completion
    task_prima.add_instrument :task_complete_step,
                              description: 'Complete current step with optional result.',
                              params: {
                                result: { type: 'string', required: false }
                              } do |result: nil|
      # Return clean divine interruption signal - engine handles step progression
      {
        __divine_interrupt: :step_completed,
        result: result
      }
    end

    # TODO DEFINE WHICH STEP GET RESULTS FROM
    # Access previous step results
    task_prima.add_instrument :task_get_previous_results,
                              description: 'Retrieve results from previous steps for context.',
                              params: {
                                limit: { type:     'integer',
                                         required: false,
                                         default:  3,
                                         minimum:  1,
                                         maximum:  10 }
                              } do |limit: 3|
      task = task_engine.instance_variable_get(:@mnemosyne).get_task task_id
      return { ok: true, task_id: task_id, results: {} } unless task && task[:step_results]

      begin
        results = JSON.parse(task[:step_results] || '{}')
        # Return most recent results up to limit, excluding current step
        current_step = task_engine.send :current_step, task_id
        filtered_results = results.reject { |step, _| step.to_i >= current_step }
        recent_results = filtered_results.sort_by { |step, _| step.to_i }.last(limit).to_h
        { ok: true, task_id: task_id, results: recent_results }
      rescue JSON::ParserError
        { ok: true, task_id: task_id, results: {} }
      end
    end

    # Task-specific aegis that preserves temperature parameter
    aegis_description = Instrumenta::PRIMA_MATERIA.tools[:aegis].description
    task_prima.add_instrument :task_aegis,
                              description: "Maintain active context with task focus. #{aegis_description}",
                              params: {
                                tags:        { type: 'array', required: false, items: { type: 'string' } },
                                summary:     { type:        'string',
                                               required:    false,
                                               description: 'Dynamic summary update without altering tags. Required for every invocation.' },
                              } do |tags: nil, summary: ''|
      # Call the original aegis but preserve the temperature parameter
      result = Instrumenta::PRIMA_MATERIA.aegis(tags: tags, summary: summary)
      result.merge(task_id: task_id) if result.is_a?(Hash)
    end

    task_prima
  end
end
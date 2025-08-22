# frozen_string_literal: true

# Support/task_engine.rb
require 'timeout'
require 'json'
# require_relative 'horologium_aeternum'
require_relative 'task_tools'


class String
  def truncate(max_length, omission = '...')
    if length > max_length
      truncated_string = self[0...(max_length - omission.length)]
      truncated_string += omission
      truncated_string
    else
      self
    end
  end
end


# Task System Prompt for comprehensive context in oracle conjuration
TASK_SYSTEM_PROMPT = <<~PROMPT
  You are executing a task step in the AetherCodex task engine...

  # TASK SYSTEM ARCHITECTURE
  - Tasks have titles, plans, and multiple steps
  - Each step has a purpose and extended purpose for detailed guidance
  - Use task-specific tools (task_read_file, task_patch_file, etc.) that automatically include task_id
  - Step management: task_reject_step(reason, restart_from_step) and task_complete_step(result)
  - Context Access: Use task_get_previous_results to access historical step outcomes

  # STEP PURPOSES:
  - read_file: Read and analyze file content
  - patch_file: Make surgical edits to files
  - run_command: Execute system commands
  - recall_notes: Query memory for relevant information
  - oracle_conjuration: Complex reasoning and tool execution
  - update_progress: Report progress and status updates
  - get_previous_results: Access historical step outcomes for context continuity

  # CURRENT STEP GUIDANCE:
  %<step_guidance>s
PROMPT

# Extended Step Guidance - 3 paragraph detailed instructions for each step
EXTENDED_STEP_GUIDANCE = {
  1  => <<~GUIDANCE,
    **Nigredo Phase - Understanding the Prima Materia**: Begin by thoroughly analyzing the task
    requirements and business context. Read all relevant files to understand the current state and
    identify what needs to be transformed. This is the blackening phase where you confront the raw,
    unrefined material and understand its inherent nature and limitations.

    **Comprehensive Analysis**: Examine the codebase structure, dependencies, and existing patterns.
    Look for similar implementations or patterns that can inform your approach. Document any
    constraints, edge cases, or potential pitfalls that might affect the transformation process.

    **Strategic Planning**: Formulate an initial understanding of how the prima materia (current
    state) can be transmuted into the desired state. Consider multiple approaches and evaluate their
    feasibility before proceeding to the purification phase.
  GUIDANCE

  2  => <<~GUIDANCE,
    **Albedo Phase - Defining the Purified Solution**: In this whitening phase, focus on clarifying
    and refining the solution approach. Define the clean, purified state that should emerge from the
    transformation. This involves specifying requirements, interfaces, and expected behaviors with
    precision.

    **Solution Architecture**: Design the architectural patterns, data structures, and algorithms
    that will form the purified solution. Consider scalability, maintainability, and performance
    requirements. Document the proposed architecture and validate it against the business
    requirements.

    **Interface Definition**: Clearly define the boundaries and interfaces between components.
    Specify input/output formats, error handling, and validation rules. This phase establishes the
    foundation for the golden implementation that follows.
  GUIDANCE

  3  => <<~GUIDANCE,
    **Citrinitas Phase - Exploring Golden Implementation Paths**: This yellowing phase involves
    exploring multiple implementation approaches and selecting the most optimal one. Research best
    practices, patterns, and existing solutions that align with the purified architecture.

    **Comparative Analysis**: Evaluate different implementation strategies, considering factors like
    complexity, performance, maintainability, and alignment with existing codebase patterns. Create
    proof-of-concepts or prototypes if necessary to validate approaches.

    **Path Selection**: Choose the implementation path that best balances elegance, efficiency, and
    practicality. Document the rationale for the selected approach and prepare for the rubedo phase
    where the chosen path will be implemented.
  GUIDANCE

  4  => <<~GUIDANCE,
    **Rubedo Phase - Selecting the Philosopher's Stone**: In this reddening phase, finalize the
    implementation details and prepare for actual coding. This is where you select the specific
    techniques, libraries, and patterns that will serve as your philosopher's stone - the key to
    successful transformation.

    **Technical Specification**: Create detailed technical specifications including class diagrams,
    method signatures, and data flow diagrams. Specify the exact implementation details, including
    any third-party libraries or frameworks to be used.

    **Implementation Planning**: Break down the implementation into manageable chunks or milestones.
    Define the order of implementation, dependencies between components, and any parallel work that
    can be done. Prepare for the solve phase where actual code changes begin.
  GUIDANCE

  5  => <<~GUIDANCE,
    **Solve Phase - Identifying Required Dissolutions**: Begin the actual transformation by
    identifying what needs to be dissolved or removed from the current state. This involves
    analyzing existing code to determine what can be refactored, replaced, or removed entirely.

    **Code Analysis**: Thoroughly examine the current codebase to identify patterns, anti-patterns,
    and areas that need improvement. Look for code smells, duplication, and opportunities for
    optimization. Document all findings and plan the dissolution process.

    **Change Identification**: Specify exactly what code changes are needed - which files to modify,
    which methods to refactor, which patterns to introduce. Create a detailed change plan that
    minimizes disruption while maximizing the transformation's effectiveness.
  GUIDANCE

  6  => <<~GUIDANCE,
    **Coagula Phase - Implementing Solid Transformations**: Execute the planned code changes with
    surgical precision. This phase involves actual coding, refactoring, and implementation of the
    purified solution. Work methodically and test each change as you go.

    **Incremental Implementation**: Implement changes in small, manageable increments. After each
    change, verify that the code still compiles and basic functionality works. Use version control
    effectively to track changes and enable easy rollback if needed.

    **Quality Assurance**: Write clean, well-documented code that follows established patterns and
    conventions. Ensure proper error handling, input validation, and edge case coverage. Maintain
      high coding standards throughout the implementation process.
  GUIDANCE

  7  => <<~GUIDANCE,
    **Test Phase - Probing the Elixir's Purity**: Begin comprehensive testing of the implemented
    changes. Focus on functional testing to ensure the basic requirements are met and the
    transformation produces the expected results.

    **Functional Verification**: Test all primary use cases and scenarios to ensure the solution
    works as intended. Verify that inputs produce correct outputs and that the system behaves
    predictably under normal conditions.

    **Integration Testing**: Test how the changes integrate with existing components and systems.
    Ensure that interfaces work correctly and that data flows properly between different parts of
    the system.
  GUIDANCE

  8  => <<~GUIDANCE,
    **Test Phase - Edge Cases as Alchemical Impurities**: Focus on testing edge cases, boundary
    conditions, and error scenarios. These are the impurities that must be identified and purified
    from the elixir to ensure its perfection.

    **Boundary Testing**: Test the limits of the system - minimum/maximum values, empty inputs,
    extreme conditions. Verify that the system handles these gracefully and provides appropriate
    feedback or error handling.

    **Error Scenario Testing**: Test how the system behaves under failure conditions - network
    outages, invalid inputs, resource constraints. Ensure that error messages are clear and that the
    system fails gracefully without data loss or corruption.
  GUIDANCE

  9  => <<~GUIDANCE,
    **Validate Phase - Ensuring the Elixir's Perfection**: Perform final validation to ensure the
    solution meets all quality standards including security, performance, and maintainability. This
    is the final purification before documentation.

    **Security Audit**: Review the code for potential security vulnerabilities, including injection
    attacks, authentication issues, and data exposure. Ensure that all security best practices are
    followed.

    **Performance Validation**: Test the solution under load to ensure it meets performance
    requirements. Profile critical paths, optimize bottlenecks, and verify that resource usage is
    within acceptable limits.
  GUIDANCE

  10 => <<~GUIDANCE
    **Document Phase - Inscribing the Magnum Opus**: Create comprehensive documentation that
    captures the entire transformation process, the final solution, and how to maintain it. This
    documentation serves as the permanent record of the magnum opus.

    **Technical Documentation**: Write detailed technical documentation including architecture
    overview, API references, deployment instructions, and troubleshooting guides. Include code
    comments and inline documentation where appropriate.

    **Knowledge Transfer**: Create documentation that enables other developers to understand,
    maintain, and extend the solution. Include examples, best practices, and lessons learned from
    the transformation process.
  GUIDANCE
}.freeze

DEBUG = true
def debug(msg)
  puts msg if DEBUG
end


# The TaskEngine orchestrates hermetic workflows, weaving:
# - **Alchemical Steps**: 10-stage transmutation of tasks (as above, as below).
# - **Recursive Sub-Tasks**: Nested operations respecting `max_loops` like fractal iterations.
# - **Dynamic Task Tools**: Tools that automatically include the current task_id for context.
# - **Dynamic State Transitions**: Task states mirroring alchemical phases (nigredo, albedo, rubedo).
# - **Oracle Integration**: Conjuring responses via `aetherflux` for step execution.
class TaskEngine
  # Patched to include dynamic task tools
  class TaskStateError < StandardError; end
  class TaskCancelledError < StandardError; end
  class TaskCreationError < StandardError; end

  debug 'TaskEngine module loaded (FIXED)'
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
    @task_tools_registry = {}

    raise ArgumentError, 'Mnemosyne (memory) is required for task alchemy' unless mnemosyne
    raise ArgumentError, 'Aetherflux (oracle) is required for conjuration' unless aetherflux

    @mnemosyne = mnemosyne
    @aetherflux = aetherflux
  end


  # Create dynamic task tools for a specific task
  def create_task_tools(task_id)
    @task_tools_registry[task_id] ||= TaskTools.build_task_prima task_id, self
  end


  # Get task tools schema for oracle conjuration
  def task_tools_schema(task_id)
    create_task_tools(task_id).instrumenta_schema
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


  def evaluate_task(task_id)
    task = @mnemosyne.get_task task_id
    progress = (task[:current_step] || 0) + 1
    debug "Evaluating task ID: #{task_id}"
    debug "Updating task ID: #{task_id} with new plan"
    debug "Executing task ID: #{task_id}"
  end


  def choose_best_option(task_id); end
  def analyze_files(task_id); end
  def apply_patches(task_id); end
  def run_tests(task_id); end
  def validate_edge_scenarios(task_id); end
  def audit_and_optimize(task_id); end
  def update_documentation(task_id); end


  # Load step results from database for context continuity
  def load_step_results(task_id)
    task = @mnemosyne.get_task task_id
    return {} unless task && task[:step_results]

    begin
      JSON.parse(task[:step_results] || '{}')
    rescue JSON::ParserError
      {}
    end
  end


  # Format previous step results for context inclusion
  def format_previous_results(results, current_step)
    return 'No previous step results available.' if results.empty? || 1 == current_step

    formatted = []
    results.each do |step_num, result|
      next if step_num.to_i >= current_step

      formatted << if current_step - 1 == step_num
        "Step #{step_num}: #{result.to_s}"
      else
        "Step #{step_num}: #{result.to_s.truncate 200}"
      end
    end

    formatted.empty? ? 'No previous step results available.' : formatted.join("\n")
  end


  # Store step result for future context
  def store_step_result(task_id, step_index, result)
    current_results = load_step_results task_id
    current_results[step_index.to_s] = result

    @mnemosyne.manage_tasks({
                              'action'       => 'update',
                              'id'           => task_id,
                              'step_results' => current_results.to_json
                            })
  end


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
  def create_task(title:, plan:, parent_task_id: nil)
    response = @mnemosyne.manage_tasks({ 'action'         => 'create',
                                         'title'          => title,
                                         'plan'           => plan,
                                         'parent_task_id' => parent_task_id,
                                         'status'         => 'pending' })

    unless response && response['ok']
      error_msg = "Task creation failed: #{response['error'] || 'Unknown error'}"
      log_message nil, error_msg
      raise TaskCreationError, error_msg
    end

    response
  end


  # Executes a task, supporting recursive sub-tasks
  def execute_task(task_id, max_loops: 10)
    task = @mnemosyne.get_task task_id

    raise TaskStateError, "Task not found: #{task_id}" unless task

    log_message task_id, "Starting execution of task #{task_id} (max_loops=#{max_loops})"
    log_message task_id, "Task status: #{task[:status]}"

    unless %w[pending active].include? task[:status]
      case task[:status]
      when 'cancelled'
        log_message task_id, 'Task was cancelled'
        update_state task_id, :cancelled
        raise TaskCancelledError, 'Task cancelled'
      when 'paused', 'failed'
        log_message task_id, "Task is #{task[:status]}"
        update_state task_id, task[:status].to_sym
        raise TaskStateError, "Task is #{task[:status]}"
      else
        log_message task_id, "Invalid state: #{task[:status]}"
        update_state task_id, :failed
        raise TaskStateError, "Invalid state: #{task[:status]}"
      end
    end

    update_state task_id, :active

    begin
      WORKFLOW_STEPS.times do |step|
        break if halted? task_id

        begin
          execute_step task_id, step + 1
        rescue TaskEngine::TaskStateError => e
          update_state task_id, :failed
          log_message task_id, "Step #{step + 1} failed: #{e.message}"
          raise e
        rescue StandardError => e
          update_state task_id, :failed
          log_message task_id, "Error in step #{step + 1}: #{e.message}"
          raise StandardError, "Error in step #{step + 1}: #{e.message}"
        end

        update_progress task_id, step + 1
      end

      # Execute sub-tasks recursively, respecting max_loops
      if 1 < max_loops
        sub_tasks = @mnemosyne.manage_tasks({ 'action' => 'list', 'parent_task_id' => task_id })
        sub_tasks.each do |sub_task|
          next if halted?(sub_task[:id]) || 1 >= max_loops

          execute_task sub_task[:id], max_loops: max_loops - 1
        end
        @mnemosyne.manage_tasks({ 'action'    => 'update',
                                  'id'        => task_id,
                                  'max_loops' => max_loops - 1 })
      end

      update_state task_id, :completed unless halted? task_id
    rescue TaskEngine::TaskStateError, Timeout::Error => e
      # Re-raise specific error types that should propagate to tests
      raise e
    rescue StandardError => e
      update_state task_id, :failed
      log_message task_id, "Task failed: #{e.message}"
      raise
    end
  end


  def log_message(task_id, message)
    @mnemosyne.manage_tasks({ 'action' => 'update', 'id' => task_id, 'log' => message })
    # Broadcast log update to frontend (commented out for testing)
    HorologiumAeternum.task_log_added \
      task_id, timestamp: Time.now.to_f, message: message

    debug message.to_s # Add debug output for test visibility
  end


  # Execute a workflow step, invoking the oracle for hermetic guidance.
  #
  # @param [Integer] task_id The task's alchemical identifier.
  # @param [Integer] step_index The phase of the magnum opus (1..10).
  # @raise [RuntimeError] If the oracle's response is invalid or times out.
  def execute_step(task_id, step_index)
    debug "Executing step #{step_index} for task #{task_id}"
    task = @mnemosyne.get_task task_id
    debug "Task description: #{task[:description]}"

    # Load previous step results for context continuity
    previous_results = load_step_results task_id
    previous_step_context = format_previous_results previous_results, step_index

    # Enhanced context with comprehensive task information
    step_guidance = if task[:steps] && task[:steps][step_index - 1]
                      step_data = task[:steps][step_index - 1]
                      extended_guidance = step_data[:extended_purpose] || EXTENDED_STEP_GUIDANCE[step_index] || 'No extended guidance provided.'
                      "#{step_data[:purpose]}\n\nEXTENDED PURPOSE:\n#{extended_guidance}"
                    else
                      extended_guidance = EXTENDED_STEP_GUIDANCE[step_index] || 'No extended guidance provided.'
                      "#{STEP_PURPOSES[step_index - 1]}\n\nEXTENDED PURPOSE:\n#{extended_guidance}"
                    end

    # Comprehensive system prompt with task context
    system_prompt = format TASK_SYSTEM_PROMPT, step_guidance: step_guidance

    # Enhanced prompt with complete task context including previous results
    prompt = <<~PROMPT
      # TASK EXECUTION CONTEXT
      TASK TITLE: #{task[:title] || '--'}
      TASK DESCRIPTION: #{task[:description] || '--'}
      TASK PLAN: #{task[:plan] || '--'}
      CURRENT STEP: #{step_index}/#{WORKFLOW_STEPS}

      # PREVIOUS STEP RESULTS
      #{previous_step_context}

      # CURRENT STEP GUIDANCE
      #{step_guidance}

      # EXECUTION INSTRUCTIONS
      - Use task-specific tools (prefixed with 'task_') for all operations
      - After completing step actions, call task_complete_step to advance
      - If you need to backtrack, use task_reject_step with optional restart_from_step
      - All task tools automatically include the task_id context
      - Use task_get_previous_results to access historical step outcomes for context continuity

      Execute the step actions based on the guidance above, building upon previous transformations.
    PROMPT

    begin
      # Comprehensive context for hermetic execution
      context = {
        task_id: task_id
      }
      # TODO: some phases should use normal divination instead of reasoning conjuration, but may call conjuration if needed, but conjuration shall not be able to call conjuration
      # response = @aetherflux.channel_oracle_divination(
      #   {
      #     prompt: prompt,
      #     system: system_prompt
      #   },
      #   nil,
      #   tools: create_task_tools(task_id),
      #   context: context
      # )
      #
      response = @aetherflux.channel_oracle_conjuration(
        {
          prompt: prompt,
          system: system_prompt
        },
        tools: create_task_tools(task_id),
        context: context
      )


      # log_message task_id, "TASK CONJURATION RESPONSE=#{response.inspect}"

      case response[:status]
      when :failure
        update_state task_id, :failed
        error_msg = "Step #{step_index} failed: #{response[:response]}"
        log_message task_id, error_msg
        raise TaskStateError, error_msg
      when :timeout
        update_state task_id, :failed
        error_msg = "Step #{step_index} timed out"
        log_message task_id, error_msg
        raise Timeout::Error, error_msg
      when :success
        reasoning = response[:response][:reasoning]
        reasoning = "\nReasoning: #{reasoning}\nResponse: " if reasoning
        answer = response[:response][:answer]
        log_message task_id, "Step #{step_index} completed: #{reasoning}#{answer}"

        # Store step result for future context
        store_step_result task_id, step_index, answer
        update_progress task_id, step_index
      else
        update_state task_id, :failed
        error_msg = "Unknown response status: #{response[:status]}"
        log_message task_id, error_msg
        raise TaskStateError, error_msg
      end
    rescue Timeout::Error => e
      log_message task_id, "Step #{step_index} timed out: #{e.message}"
      update_state task_id, :failed
      raise
    rescue StandardError => e
      log_message task_id, "Step #{step_index} failed: #{e.message}"
      update_state task_id, :failed
      raise
    end

    # Clean up task tools after step execution
    @task_tools_registry.delete task_id if WORKFLOW_STEPS == step_index

    log_message task_id, "Executing step #{step_index}: #{STEP_PURPOSES[step_index - 1]}"
  end


  def update_state(task_id, state)
    raise ArgumentError, "Invalid task state: #{state}" unless STATES.include? state

    @mnemosyne.manage_tasks({ 'action' => 'update', 'id' => task_id, 'status' => state.to_s })
    broadcast_update task_id
  end


  def broadcast_update(task_id)
    task = @mnemosyne.get_task task_id
    return unless task

    HorologiumAeternum.task_updated(**task)
  end


  def halted?(task_id)
    debug "Checking halt status for task #{task_id}"
    task = @mnemosyne.get_task task_id
    debug "Current task status: #{task[:status]}"
    return false unless task

    case task[:status]
    when 'invalid', 'cancelled', 'failed', 'paused'
      true
    else
      false
    end
  end


  # Reject current step and optionally restart from specific step
  def reject_step(task_id, reason = nil, restart_from_step = nil)
    log_message task_id, "Step rejected: #{reason}" if reason

    if restart_from_step
      # Set progress to restart from specific step
      update_progress task_id, restart_from_step - 1
      log_message task_id, "Restarting from step #{restart_from_step}"
    else
      # Default: go back to previous step
      current_progress = current_step task_id
      if 1 < current_progress
        update_progress task_id, current_progress - 1
        log_message task_id, "Returning to previous step #{current_progress - 1}"
      else
        log_message task_id, 'Cannot go back from first step'
      end
    end

    { ok:                true,
      task_id:           task_id,
      restart_from_step: restart_from_step || (current_step(task_id) - 1) }
  end


  # TODO: complete_step and reject step should terminate the current reasoning otherwise this creates double cycles.
  # Complete current step with optional result
  def complete_step(task_id, result = nil)
    current_step = current_step task_id
    log_message task_id, "Step #{current_step} completed: #{result.inspect}" if result
    update_progress task_id, current_step + 1
    { ok: true, task_id: task_id, completed_step: current_step, result: result }
  end


  # Get current step number for task
  def current_step(task_id)
    task = @mnemosyne.get_task task_id
    task[:current_step] || 0
  end


  def update_progress(task_id, step)
    @mnemosyne.manage_tasks({ 'action'       => 'update',
                              'id'           => task_id,
                              'current_step' => step })
    broadcast_update task_id
  end
end
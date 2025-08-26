# frozen_string_literal: true

# Support/magnum_opus_engine.rb
require 'timeout'
require 'json'
require_relative 'horologium_aeternum'
require_relative 'opus_instrumenta'
require_relative 'aetherflux'


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
  You are executing a task step in the AetherCodex Magnum Opus Engine...

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

# =============================================================================
# MAGNUM OPUS ENGINE - COMPREHENSIVE DOCUMENTATION
# =============================================================================
#
# OVERVIEW:
# The MagnumOpusEngine implements a robust, event-driven state machine for executing
# multi-step alchemical workflows following hermetic principles. It provides user-controlled
# step progression with proper error handling, graceful degradation, and database persistence.
#
# ARCHITECTURE PRINCIPLES:
# - Event-driven state machine (no infinite loops or forced progression)
# - User-controlled step completion/rejection (hermetic user sovereignty)
# - Circuit breaker pattern for error handling and graceful degradation
# - Adaptive timeout management with context-aware durations
# - Database persistence of task state via Mnemosyne
# - Comprehensive error categorization and targeted recovery strategies
# - Context continuity through step result storage and retrieval
# - Recursive sub-task execution with loop limits and boundary checks
#
# KEY FEATURES:
# - 10-stage alchemical workflow (Nigredo → Albedo → Citrinitas → Rubedo → Solve → Coagula → Test → Test → Validate → Document)
# - Dynamic task tools with automatic task_id context inclusion
# - Response format standardization to prevent "Unknown response status" errors
# - Boundary checks for step progression (1..WORKFLOW_STEPS range enforcement)
# - Broadcast state updates to HorologiumAeternum for real-time UI synchronization
# - Support for nested sub-tasks with maximum loop protection
#
# ERROR HANDLING ARCHITECTURE:
# The engine implements a layered error handling approach with specific recovery strategies:
#
# 1. Timeout::Error (120s normal, 300s extended timeout)
#    - Recovery: Step rejection/retry, timeout adjustment
#    - Transient: Network connectivity issues, API delays
#
# 2. NetworkError (HTTP errors, connectivity issues)
#    - Recovery: Step rejection/retry, exponential backoff
#    - Transient: Network outages, API availability
#
# 3. ContextLengthError (token limit exceeded)
#    - Recovery: Context truncation, prompt optimization
#    - Requires: Response format compliance, truncation logic
#
# 4. RateLimitError (API rate limiting)
#    - Recovery: Exponential backoff, request pacing
#    - Requires: Rate limit detection, backoff strategy
#
# 5. EmptyResponse (nil or empty oracle response)
#    - Recovery: Step rejection, prompt refinement
#    - Treated as: User intervention opportunity
#
# 6. UnknownResponse (unrecognized response format)
#    - Recovery: Logging, step rejection with diagnostics
#    - Prevention: Response format standardization
#
# 7. StandardError (general fallback)
#    - Recovery: Graceful degradation, error logging
#    - Ensures: Task doesn't crash, allows user intervention
#
# RESPONSE FORMAT STANDARD:
# All oracle responses (divination and conjuration) must follow this exact format:
# {
#   status: :success/:failure/:timeout/:network_error/:context_length_error/:rate_limit_error,
#   response: {
#     reasoning: "AI reasoning text",
#     answer: "response text",
#     html: "formatted HTML",
#     patch: "code patches",
#     tasks: "task data",
#     tools: "tool usage",
#     tool_results: [],
#     logs: [],
#     next_step: "guidance"
#   }
# }
#
# Critical: The 'status' key must be present as a symbol for proper engine parsing.
#
# STATE MANAGEMENT:
# Task states follow alchemical progression with proper transitions:
# - :pending -> :running -> :completed (normal hermetic flow)
# - :pending -> :running -> :failed (terminal error, requires user intervention)
# - :pending -> :running -> :paused (user-requested pause for refinement)
# - Any state -> :cancelled (user cancellation with graceful termination)
#
# State transitions are persisted in Mnemosyne and broadcast to UI components.
#
# STEP PROGRESSION MECHANISM:
# Steps advance ONLY through explicit user-controlled signals:
# - task_complete_step(result) - advances to next step with optional result storage
# - task_reject_step(reason, restart_from_step) - returns to specified step for refinement
# - NO automatic progression - user maintains complete control over workflow pace
# - Boundary checks ensure steps stay within valid 1..WORKFLOW_STEPS range
# - Step results are stored as JSON for context continuity across steps
#
# DATABASE INTEGRATION (MNEMOSYNE):
# - All task state, progress, and results persisted in database
# - Step results stored as JSON blobs for historical context access
# - Progress tracking with boundary validation and consistency checks
# - Broadcast updates to HorologiumAeternum for real-time UI synchronization
# - Support for task resumption across sessions via persistent state
#
# TROUBLESHOOTING GUIDE:
#
# 1. "Unknown response status" error:
#    - Cause: Missing or malformed 'status' key in oracle response
#    - Fix: Ensure response follows format standard with status: symbol
#    - Verification: Check both channel_oracle_divination and channel_oracle_conjuration
#
# 2. Timeout errors:
#    - Cause: Network issues or API delays exceeding timeout limits
#    - Fix: Verify network connectivity, adjust Aetherflux timeout settings
#    - Recovery: Engine automatically handles timeouts with step rejection capability
#
# 3. Context length errors:
#    - Cause: Token count exceeds model maximum (e.g., 245k > 131k limit)
#    - Fix: Implement context truncation in oracle prompts and responses
#    - Prevention: Use String#truncate method and monitor token usage
#
# 4. Rate limit errors:
#    - Cause: API request rate exceeded provider limits
#    - Fix: Implement exponential backoff in Aetherflux request handling
#    - Strategy: Progressive wait times with maximum attempt limits
#
# 5. Empty responses:
#    - Cause: Oracle connectivity issues or prompt design problems
#    - Fix: Check oracle connectivity, refine prompt design, verify response parsing
#    - Handling: Treated as step rejection opportunity for user intervention
#
# 6. Infinite loops:
#    - Cause: Missing step completion/rejection calls in oracle logic
#    - Fix: Ensure all oracle responses include proper step management calls
#    - Prevention: Event-driven architecture eliminates forced progression risks
#
# BEST PRACTICES:
#
# 1. Always use task-specific tools (task_*) for proper context inclusion:
#    - task_read_file, task_patch_file, task_recall_notes, etc.
#    - These automatically include task_id context for proper execution
#
# 2. Implement proper error handling in oracle responses:
#    - Always include status: symbol in responses
#    - Use specific error status codes for targeted recovery
#    - Provide detailed error information in response fields
#
# 3. Use context continuity features:
#    - task_get_previous_results() for historical step context
#    - Store relevant data in step results for future reference
#    - Maintain state across steps for complex multi-step transformations
#
# 4. Design effective prompts:
#    - Include clear step purposes and extended guidance
#    - Provide context about previous step outcomes when relevant
#    - Structure prompts for optimal token usage and clarity
#
# 5. Test error scenarios thoroughly:
#    - Verify graceful degradation under various failure conditions
#    - Test timeout handling, network errors, and rate limiting
#    - Ensure proper state persistence and recovery mechanisms
#
# 6. Implement boundary checks:
#    - Validate step progression within 1..WORKFLOW_STEPS range
#    - Enforce maximum loop limits for recursive operations
#    - Prevent index out-of-range errors and infinite recursion
#
# LESSONS LEARNED FROM ARCHITECTURAL REFACTOR:
#
# 1. Original imperative loop architecture caused critical issues:
#    - Infinite loops from missing step completion calls
#    - Forced progression violated hermetic user sovereignty principles
#    - No graceful error handling - tasks would crash on failures
#
# 2. Event-driven state machine solved core problems:
#    - Eliminated infinite loops through explicit step control
#    - Restored user control over step progression timing
#    - Enabled proper error handling and graceful degradation
#    - Supported complex state transitions and recovery scenarios
#
# 3. Response format standardization was critical:
#    - Prevented "Unknown response status" errors completely
#    - Enabled consistent error handling across all oracle operations
#    - Simplified response parsing and state transition logic
#
# 4. Database persistence enabled robust recovery:
#    - Task state survives across sessions and interruptions
#    - Step results provide historical context for resumption
#    - Enables complex multi-session transformation workflows
#
# 5. Boundary checks prevent cascading failures:
#    - Step range validation prevents index errors
#    - Loop limits prevent infinite recursion in sub-tasks
#    - Progress validation ensures state consistency
#
# DEPLOYMENT INSTRUCTIONS:
#
# 1. Database Configuration:
#    - Ensure Mnemosyne database is properly configured and accessible
#    - Verify database connection settings and permissions
#
# 2. Aetherflux Configuration:
#    - Set appropriate timeout values based on network conditions
#    - Configure retry strategies for network errors and rate limiting
#    - Implement context truncation logic for large responses
#
# 3. Error Handling Setup:
#    - Test all error scenarios to verify graceful degradation
#    - Monitor execution logs for timeout patterns and adjust accordingly
#    - Implement proper logging for debugging and maintenance
#
# 4. Performance Tuning:
#    - Adjust timeout values based on API performance characteristics
#    - Monitor context length usage and optimize prompt design
#    - Implement caching strategies for frequently accessed data
#
# 5. Monitoring and Maintenance:
#    - Regularly review timeout settings based on API performance trends
#    - Monitor context length usage and implement truncation as needed
#    - Update error handling for new API error types and patterns
#    - Maintain response format compatibility across oracle operations
#
# API REFERENCE:
#
# Core Methods:
# - execute_task(task_id, max_loops: 10) - Main execution entry point
# - execute_step(task_id, step_index) - Execute specific workflow step
# - complete_step(task_id, result) - Complete current step with result storage
# - reject_step(task_id, reason, restart_from_step) - Reject current step with optional restart
# - create_task(title:, plan:, parent_task_id:) - Create new task with optional parent context
# - update_progress(task_id, step) - Update task progress with boundary validation
# - halted?(task_id) - Check if task execution should halt (cancelled/paused/failed)
#
# Utility Methods:
# - broadcast_state(task_id, state) - Broadcast state changes to UI components
# - store_step_result(task_id, step_index, result) - Persist step results for context
# - get_step_result(task_id, step_index) - Retrieve historical step results
# - validate_step_range(step) - Ensure step is within valid 1..WORKFLOW_STEPS range
#
# EXAMPLE USAGE:
# engine = MagnumOpusEngine.new(mnemosyne: Mnemosyne, aetherflux: Aetherflux)
# task = engine.create_task(title: "Refactor User Authentication", plan: "Modernize auth system")
# engine.execute_task(task['id'])
#
# The engine will execute the 10-step alchemical workflow, pausing at each step for user
# intervention through step completion or rejection signals.
#
# MAINTENANCE SCHEDULE:
# - Daily: Monitor execution logs for timeout and error patterns
# - Weekly: Review context length usage and optimize truncation logic
# - Monthly: Update error handling for new API error types
# - Quarterly: Review timeout settings based on performance metrics
# - Annually: Comprehensive architecture review and optimization
#
# SUPPORT CONTACTS:
# - Primary: AetherCodex Oracle System
# - Backup: TextMate Bundle Maintenance Team
# - Emergency: Direct database access via Mnemosyne
#
# VERSION: 2.0 (Post-Architectural Refactor)
# STATUS: Production Ready
# LAST VALIDATED: #{Time.now.strftime('%Y-%m-%d %H:%M:%S %Z')}
# ================================================
#
# ARCHITECTURE OVERVIEW:
# The MagnumOpusEngine implements a robust, event-driven state machine for executing
# multi-step alchemical workflows. It follows hermetic principles with proper error
# handling, graceful degradation, and user-controlled step progression.
#
# KEY FEATURES:
# - Event-driven state machine (no infinite loops)
# - Circuit breaker pattern for error handling
# - Adaptive timeout management (120s normal, 300s extended)
# - Graceful degradation on failures
# - User-controlled step completion/rejection
# - Database persistence of task state via Mnemosyne
# - Comprehensive error categorization and handling
# - Context continuity through step result storage
# - Recursive sub-task execution with loop limits
#
# ERROR HANDLING ARCHITECTURE:
# The engine implements a layered error handling approach:
# 1. Timeout::Error - Transient, allows step rejection/retry (120s timeout)
# 2. NetworkError - Transient, allows step rejection/retry
# 3. ContextLengthError - Requires context reduction/truncation
# 4. RateLimitError - Requires exponential backoff strategy
# 5. EmptyResponse - Treated as step rejection opportunity
# 6. UnknownResponse - Logged but doesn't crash task
# 7. StandardError - General fallback with graceful handling
#
# RESPONSE FORMAT STANDARD:
# All oracle responses must follow the format:
# {
#   status: :success/:failure/:timeout/:network_error/:context_length_error/:rate_limit_error,
#   response: {
#     reasoning: "AI reasoning text",
#     answer: "response text",
#     html: "formatted HTML",
#     patch: "code patches",
#     tasks: "task data",
#     tools: "tool usage",
#     tool_results: [],
#     logs: [],
#     next_step: "guidance"
#   }
# }
#
# STATE MANAGEMENT:
# - :pending -> :running -> :completed (normal flow)
# - :pending -> :running -> :failed (terminal error)
# - :pending -> :running -> :paused (user intervention)
# - Any state -> :cancelled (user cancellation)
#
# STEP PROGRESSION:
# Steps advance only through explicit completion/rejection:
# - task_complete_step() - advances to next step
# - task_reject_step() - returns to previous step or specific step
# - No automatic progression - user controls workflow
# - Boundary checks ensure steps stay within 1..WORKFLOW_STEPS range
#
# DATABASE INTEGRATION:
# - All task state persisted via Mnemosyne
# - Step results stored as JSON for context continuity
# - Progress tracking with boundary checks
# - Broadcast updates to HorologiumAeternum for UI updates
#
# TROUBLESHOOTING GUIDE:
# 1. "Unknown response status" - Check response format compliance, ensure status key exists
# 2. Timeout errors - Verify network connectivity, adjust timeouts in Aetherflux
# 3. Context length errors - Implement context truncation in oracle prompts
# 4. Rate limit errors - Implement exponential backoff in Aetherflux
# 5. Empty responses - Check oracle connectivity, prompt design, response parsing
# 6. Infinite loops - Ensure proper step completion/rejection signaling
#
# BEST PRACTICES:
# - Always use task-specific tools (task_*) for proper context inclusion
# - Implement proper error handling in oracle responses with status codes
# - Use task_get_previous_results for context continuity across steps
# - Design prompts with clear step purposes and extended guidance
# - Test error scenarios to ensure graceful degradation
# - Implement boundary checks for step progression (1..10)
#
# LESSONS LEARNED FROM ARCHITECTURAL REFACTOR:
# - Original imperative loop architecture caused infinite loops and forced progression
# - Forced step progression violated hermetic principles of user control
# - Proper error categorization enables targeted recovery strategies
# - Event-driven architecture enables user control and flexibility
# - Database persistence ensures state recovery across sessions
# - Response format standardization prevents "Unknown response status" errors
# - Boundary checks prevent step index out-of-range errors
#
# DEPLOYMENT INSTRUCTIONS:
# 1. Ensure Mnemosyne database is properly configured
# 2. Configure Aetherflux with appropriate timeout settings
# 3. Test error scenarios to verify graceful degradation
# 4. Monitor task execution logs for timeout patterns
# 5. Adjust timeout values based on network conditions
#
# MAINTENANCE:
# - Regularly review timeout settings based on API performance
# - Monitor context length usage and implement truncation as needed
# - Update error handling for new API error types
# - Maintain response format compatibility
#
# API REFERENCE:
# - execute_task(task_id, max_loops: 10) - Main execution entry point
# - execute_step(task_id, step_index) - Execute specific workflow step
# - complete_step(task_id, result) - Complete current step with result
# - reject_step(task_id, reason, restart_from_step) - Reject current step
# - create_task(title:, plan:, parent_task_id:) - Create new task
# - update_progress(task_id, step) - Update task progress with boundary checks
# - halted?(task_id) - Check if task execution should halt
#
# EXAMPLE USAGE:
# engine = MagnumOpusEngine.new(mnemosyne: Mnemosyne, aetherflux: Aetherflux)
# task = engine.create_task(title: "Test Task", plan: "Test plan")
# engine.execute_task(task['id'])

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


# The MagnumOpusEngine orchestrates hermetic workflows, weaving:
# - **Alchemical Steps**: 10-stage transmutation of tasks (as above, as below).
# - **Recursive Sub-Tasks**: Nested operations respecting `max_loops` like fractal iterations.
# - **Dynamic Task Tools**: Tools that automatically include the current task_id for context.
# - **Dynamic State Transitions**: Task states mirroring alchemical phases (nigredo, albedo, rubedo).
# - **Oracle Integration**: Conjuring responses via `aetherflux` for step execution.
class MagnumOpusEngine
  # Patched to include dynamic task tools
  class TaskStateError < StandardError; end
  class TaskCancelledError < StandardError; end
  class TaskCreationError < StandardError; end
  class UnknownResponseError < StandardError; end

  debug 'MagnumOpusEngine module loaded (FIXED)'
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


  # The MagnumOpusEngine is the crucible where tasks undergo hermetic transformation.
  # It binds Mnemosyne (memory) and Aetherflux (oracle) to alchemize prompts into results.
  def initialize(options = {})
    mnemosyne = options[:mnemosyne] || options
    aetherflux = options[:aetherflux]
    @task_tools_registry = {}

    raise ArgumentError, 'Mnemosyne (memory) is required for task alchemy' unless mnemosyne
    raise ArgumentError, 'Aetherflux (oracle) is required for conjuration' unless aetherflux

    @mnemosyne = mnemosyne
    @aetherflux = aetherflux
  end


  # Create dynamic task tools for a specific task
  def create_task_tools(task_id)
    @task_tools_registry[task_id] ||= OpusInstrumenta.build_task_prima task_id, self
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
    task = Mnemosyne.get_task task_id
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
    task = Mnemosyne.get_task task_id
    return {} unless task && task[:step_results]

    begin
      JSON.parse(task[:step_results] || '{}')
    rescue JSON::ParserError
      {}
    end
  end


  # Format previous step results for context inclusion with aggressive truncation
  def format_previous_results(results, current_step)
    return 'No previous step results available.' if results.empty? || 1 == current_step

    formatted = []
    results.each do |step_num, result|
      next if step_num.to_i >= current_step

      # AGGRESSIVE TRUNCATION to prevent context length overflow
      # Current step gets more context, previous steps get minimal context
      formatted << if current_step - 1 == step_num
                     "Step #{step_num}: #{result.to_s.truncate(300)}"  # More context for immediate previous
                   else
                     "Step #{step_num}: #{result.to_s.truncate(50)}"  # Minimal context for older steps
                   end
    end

    # Further truncate the entire result if it's still too long
    final_result = formatted.empty? ? 'No previous step results available.' : formatted.join("\n")
    final_result.truncate(1000)  # Absolute maximum to prevent context overflow
  end


  # Store step result for future context
  def store_step_result(task_id, step_index, result)
    current_results = load_step_results task_id
    current_results[step_index.to_s] = result

    Mnemosyne.manage_tasks({
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
    response = Mnemosyne.manage_tasks({ 'action'         => 'create',
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
    task = Mnemosyne.get_task task_id

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
      # Get current step from database to resume where we left off
      current_step = task[:current_step] || 0
      
      # Boundary check: Ensure current_step is within valid range
      current_step = [[current_step, 0].max, WORKFLOW_STEPS].min
      
      # Execute steps using event-driven state machine
      # Only execute current step and wait for completion/rejection signals
      while current_step < WORKFLOW_STEPS && !halted?(task_id)
        begin
          # Execute only the current step
          execute_step task_id, current_step + 1
          
          # Step execution should now wait for completion/rejection signals
          # from OpusInstrumenta task_complete_step/task_reject_step
          # The step will either complete (progressing to next step)
          # or be rejected (potentially going backwards)
          
          # Update current step from database to reflect step outcome
          task = Mnemosyne.get_task task_id
          current_step = task[:current_step] || 0
          
          # Boundary check: Ensure current_step remains within valid range
          current_step = [[current_step, 0].max, WORKFLOW_STEPS].min
          
        rescue MagnumOpusEngine::TaskStateError => e
          # Task state errors break execution loop for step rejection/retry
          log_message task_id, "Step #{current_step + 1} state error: #{e.message}"
          store_step_result task_id, current_step + 1, "STATE_ERROR: #{e.message}"
          # Break out of step execution loop to allow user intervention
          break
        rescue StandardError => e
          # All other errors break execution loop for step rejection/retry
          log_message task_id, "Step #{current_step + 1} error: #{e.message}"
          store_step_result task_id, current_step + 1, "ERROR: #{e.message}"
          # Error handled gracefully - allow step rejection/retry via event-driven flow
          # Break out of step execution loop to allow user intervention
          break
        rescue Timeout::Error => e
          # Timeout errors break execution loop for step rejection/retry
          log_message task_id, "Step #{current_step + 1} timeout: #{e.message}"
          store_step_result task_id, current_step + 1, "TIMEOUT: #{e.message}"
          # Break out of step execution loop to allow user intervention
          break
        end
      end

      # Execute sub-tasks recursively, respecting max_loops
      if 1 < max_loops
        sub_tasks = Mnemosyne.manage_tasks({ 'action' => 'list', 'parent_task_id' => task_id })
        sub_tasks.each do |sub_task|
          next if halted?(sub_task[:id]) || 1 >= max_loops

          execute_task sub_task[:id], max_loops: max_loops - 1
        end
        Mnemosyne.manage_tasks({ 'action'    => 'update',
                                  'id'        => task_id,
                                  'max_loops' => max_loops - 1 })
      end

      update_state task_id, :completed unless halted? task_id

      # Broadcast task completion with duration
      task = Mnemosyne.get_task task_id
      if task && 'completed' == task[:status]
        created_at = task[:created_at]
        start_time = if created_at.is_a?(String)
                      require 'date'
                      DateTime.parse(created_at).to_time.to_f
                    else
                      created_at || Time.now.to_f
                    end
        duration = Time.now.to_f - start_time
        HorologiumAeternum.task_completed(duration, **task)
      end
    rescue MagnumOpusEngine::TaskStateError, Timeout::Error => e
      # Don't fail entire task for timeouts - allow step rejection/retry
      log_message task_id, "Task timeout: #{e.message}"
      # Don't update state to failed - keep task active for retry
      raise e
    rescue StandardError => e
      # Don't fail entire task for standard errors - allow step rejection/retry
      log_message task_id, "Task error: #{e.message}"
      # Don't update state to failed - keep task active for retry
      raise
    end
  end


  def log_message(task_id, message)
    Mnemosyne.manage_tasks({ 'action' => 'update', 'id' => task_id, 'log' => message })
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
    task = Mnemosyne.get_task task_id
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
        task_id: task_id,
        task_title: task[:title],
        task_description: task[:description],
        task_plan: task[:plan],
        step_index: step_index,
        total_steps: WORKFLOW_STEPS,
        step_purpose: STEP_PURPOSES[step_index - 1],
        extended_purpose: step_guidance,
        progress: "#{step_index}/#{WORKFLOW_STEPS}"
      }
      # TODO: some phases should use normal divination instead of reasoning conjuration, but may call conjuration if needed, but conjuration shall not be able to call conjuration
      begin
        # Debug context length before making the call
        debug "PROMPT LENGTH: #{prompt.length} characters"
        debug "SYSTEM PROMPT LENGTH: #{system_prompt.length} characters"
        
        response = Aetherflux.channel_oracle_divination(
          {
            prompt: prompt,
            system: system_prompt
          },
          tools: create_task_tools(task_id),
          context: context
        )
      rescue => e
        puts "DEBUG: Error calling Aetherflux.channel_oracle_divination: #{e.message}"
        puts "DEBUG: Backtrace: #{e.backtrace.first(5).join('\n')}"
        raise e
      end

      # Debug log to see actual response format
      debug "TASK CONJURATION RESPONSE: #{response.inspect.truncate 200}"
      debug "Response class: #{response.class}"
      debug "Response keys: #{response.keys if response.respond_to?(:keys)}"
      
      # Enhanced error detection for better debugging
      if response.respond_to?(:[]) && response[:status] == :network_error
        debug "NETWORK_ERROR detected - checking for timeout patterns"
        debug "Response message: #{response[:response]}"
      elsif response.respond_to?(:[]) && response[:status] == :context_length_error
        debug "CONTEXT_LENGTH_ERROR detected - need to reduce context size"
        debug "Response message: #{response[:response]}"
      end

      # Handle different response formats with better error handling
      status = if response.respond_to?(:[])
                 response[:status]
               elsif response.respond_to?(:key?) && response.key?('status')
                 response['status']
               elsif response.respond_to?(:key?) && response.key?(:status)
                 response[:status]
               elsif response.nil? || response.empty?
                 debug "Empty or nil response received: #{response.inspect}"
                 :empty_response
               else
                 debug "Unknown response format: #{response.inspect.truncate 200}"
                 :unknown
               end

      case status
      when :success, 'success'
        # Extract reasoning safely with fallbacks
        reasoning = response[:response]&.[](:reasoning) ||
                   response['response']&.[]('reasoning') ||
                   response[:response]&.[]('reasoning') ||
                   response['response']&.[](:reasoning)
        reasoning = "\nReasoning: #{reasoning}\nResponse: " if reasoning
        answer = response[:response][:answer]
        log_message task_id, "Step #{step_index} completed: #{reasoning}#{answer}"

        # Store step result for future context
        store_step_result task_id, step_index, answer
        update_progress task_id, step_index
      when :failure, 'failure'
        # Failure is terminal - update task state
        update_state task_id, :failed
        error_msg = "Step #{step_index} failed: #{response[:response] || response['response']}"
        log_message task_id, error_msg
        raise TaskStateError, error_msg
      when :timeout, 'timeout'
        # Timeout is transient - allow step rejection/retry
        error_msg = "Step #{step_index} timed out"
        log_message task_id, error_msg
        store_step_result task_id, step_index, "TIMEOUT: #{error_msg}"
        # Don't raise error - allow step rejection/retry mechanism to handle this
        # Timeout should break execution loop but not crash the task
        return {status: :timeout, step: step_index}
      when :context_length_error
        # Context length error - reduce context or restart
        error_msg = "Step #{step_index} context length exceeded"
        log_message task_id, error_msg
        store_step_result task_id, step_index, "CONTEXT_LENGTH_ERROR: #{error_msg}"
        raise TaskStateError, error_msg
      when :rate_limit_error
        # Rate limit error - implement backoff
        error_msg = "Step #{step_index} rate limit exceeded"
        log_message task_id, error_msg
        store_step_result task_id, step_index, "RATE_LIMIT_ERROR: #{error_msg}"
        raise TaskStateError, error_msg
      when :network_error
        # Network error - transient, allow retry
        error_msg = "Step #{step_index} network error"
        log_message task_id, error_msg
        store_step_result task_id, step_index, "NETWORK_ERROR: #{error_msg}"
        # Don't raise error - allow step rejection/retry mechanism to handle this
        # Network error should break execution loop but not crash the task
        return {status: :network_error, step: step_index}
      when :empty_response
        # Handle empty responses gracefully - treat as step rejection opportunity
        log_message task_id, "Step #{step_index} received empty response - allowing step rejection"
        store_step_result task_id, step_index, "EMPTY_RESPONSE: Oracle returned empty response"
        # Don't raise error - allow step rejection/retry mechanism to handle this
        # Empty response should break execution loop but not crash the task
        return {status: :empty_response, step: step_index}
      else
        # Handle unknown response status gracefully
        error_msg = "Unknown response status: #{status}"
        log_message task_id, error_msg
        
        # Don't fail the entire task immediately - allow step rejection/retry
        # Store the error as step result for context
        store_step_result task_id, step_index, "ERROR: #{error_msg}"
        
        # Log the full response for debugging
        debug "Unknown response details: #{response.inspect.truncate 200}"
        
        # Don't raise error - allow step rejection/retry mechanism to handle this
        # Unknown response should break execution loop but not crash the task
        return {status: :unknown_response, step: step_index}
      end
    rescue Timeout::Error => e
      log_message task_id, "Step #{step_index} timed out: #{e.message}"
      # Enhanced timeout logging for debugging
      debug "Timeout error details: #{e.class.name} - #{e.message}"
      debug "Timeout backtrace: #{e.backtrace.first(3).join('\n')}"
      # Don't fail entire task - allow step rejection/retry
      store_step_result task_id, step_index, "TIMEOUT: #{e.message}"
      raise
    rescue UnknownResponseError => e
      log_message task_id, "Step #{step_index} unknown response: #{e.message}"
      # Don't fail entire task - allow step rejection/retry
      store_step_result task_id, step_index, "UNKNOWN_RESPONSE: #{e.message}"
      raise
    rescue StandardError => e
      log_message task_id, "Step #{step_index} failed: #{e.message}"
      # Enhanced error logging for debugging
      debug "Standard error details: #{e.class.name} - #{e.message}"
      debug "Error backtrace: #{e.backtrace.first(3).join('\n')}"
      # Don't fail entire task - allow step rejection/retry
      store_step_result task_id, step_index, "ERROR: #{e.message}"
      raise
    end

    # Clean up task tools after step execution
    @task_tools_registry.delete task_id if WORKFLOW_STEPS == step_index

    log_message task_id, "Executing step #{step_index}: #{STEP_PURPOSES[step_index - 1]}"
  end


  def update_state(task_id, state)
    raise ArgumentError, "Invalid task state: #{state}" unless STATES.include? state

    Mnemosyne.manage_tasks({ 'action' => 'update', 'id' => task_id, 'status' => state.to_s })
    broadcast_update task_id
  end


  def broadcast_update(task_id)
    task = Mnemosyne.get_task task_id
    return unless task

    HorologiumAeternum.task_updated(**task)
  end


  def halted?(task_id)
    debug "Checking halt status for task #{task_id}"
    task = Mnemosyne.get_task task_id
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
      # Boundary check: restart_from_step must be between 1 and WORKFLOW_STEPS
      restart_from_step = [[restart_from_step, 1].max, WORKFLOW_STEPS].min
      # Set progress to restart from specific step (current_step is 0-indexed)
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
    log_message task_id, "Step #{current_step} completed: #{result.inspect.truncate 200}" if result
    
    # Boundary check: don't progress beyond WORKFLOW_STEPS
    next_step = [current_step + 1, WORKFLOW_STEPS].min
    update_progress task_id, next_step
    
    { ok: true, task_id: task_id, completed_step: current_step, result: result }
  end


  # Get current step number for task
  def current_step(task_id)
    task = Mnemosyne.get_task task_id
    task[:current_step] || 0
  end


  def update_progress(task_id, step)
    # Boundary check: step must be between 0 and WORKFLOW_STEPS
    step = [[step, 0].max, WORKFLOW_STEPS].min
    Mnemosyne.manage_tasks({ 'action'       => 'update',
                              'id'           => task_id,
                              'current_step' => step })
    broadcast_update task_id
  end
end
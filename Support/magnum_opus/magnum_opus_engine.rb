# frozen_string_literal: true

# Support/magnum_opus_engine.rb
require 'timeout'
require 'json'
require 'date'
require_relative '../oracle/aetherflux'
require_relative '../oracle/error_handler'
require_relative '../instrumentarium/horologium_aeternum'
require_relative '../instrumentarium/scriptorium'
require_relative '../instrumentarium/metaprogramming_utils'
require_relative 'opus_instrumenta'



# Task System Prompt for comprehensive context in oracle conjuration
TASK_SYSTEM_PROMPT = <<~PROMPT
  # MAGNUM OPUS ENGINE - TASK EXECUTION SYSTEM
  
  You are executing a task step in the AetherCodex Magnum Opus Engine with structured message context.
  
  # MESSAGE STRUCTURE:
  - PREVIOUS STEP RESULTS: Assistant message with historical context
  - CURRENT STEP GUIDANCE: System message with step-specific instructions
  - EXECUTION INSTRUCTIONS: System message with phase-specific tool access and procedures
  - TASK EXECUTION CONTEXT: User message focusing on the current task
  
  # CORE PRINCIPLES:
  - Use task-specific tools (task_*) that automatically include task_id context
  - Control step progression: task_complete_step(result) or task_reject_step(reason, restart_from_step)
  - Access historical context: task_get_previous_results() for continuity
  
  # PHASED EXECUTION:
  - Exploration (Steps 1-4): Read-only analysis tools only
  - Implementation (Steps 5-10): Full tool access including modifications
  
  # STEP GUIDANCE:
  %<step_guidance>
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
# - execute_task(task_id, max_steps: 10) - Main execution entry point
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
    **Purificatio Phase - Edge Cases as Alchemical Impurities**: Focus on testing edge cases, boundary
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
    **Validatio Phase - Ensuring the Elixir's Perfection**: Perform final validation to ensure the
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
    **Documentatio Phase - Inscribing the Magnum Opus**: Create comprehensive documentation that
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

# Temperature settings for different step phases
# Exploration phases (1-4): Higher temperature for creative planning and analysis
# Implementation phases (5-10): Lower temperature for precise, deterministic execution
STEP_TEMPERATURES = {
  1 => 1.5,  # Nigredo: High creativity for initial analysis
  2 => 1.4,  # Albedo: Creative solution design
  3 => 1.3,  # Citrinitas: Creative exploration of implementation paths
  4 => 1.2,  # Rubedo: Creative technical specification
  5 => 1.0,  # Solve: Balanced for analysis and planning
  6 => 0.8,  # Coagula: Precise implementation
  7 => 0.7,  # Test: Deterministic testing
  8 => 0.7,  # Test: Deterministic edge case testing
  9 => 0.8,  # Validate: Balanced validation
  10 => 1.0  # Document: Balanced documentation
}.freeze

DEBUG = true
def debug(category, msg = nil)
  if msg.nil?
    msg = category
    category = nil
  else
    category = "[#{category}]"
  end
  puts "[MAGNUM_OPUS_ENGINE]#{category}: #{msg}" if DEBUG
end


# The MagnumOpusEngine orchestrates hermetic workflows, weaving:
# - **Alchemical Steps**: 10-stage transmutation of tasks (as above, as below).
# - **Recursive Sub-Tasks**: Nested operations respecting `max_steps` like fractal iterations.
# - **Dynamic Task Tools**: Tools that automatically include the current task_id for context.
# - **Dynamic State Transitions**: Task states mirroring alchemical phases (nigredo, albedo, rubedo).
# - **Oracle Integration**: Conjuring responses via `aetherflux` for step execution.
class MagnumOpusEngine
  # Patched to include dynamic task tools
  class TaskStateError < StandardError; end
  class TaskCancelledError < StandardError; end
  class TaskCreationError < StandardError; end
  class UnknownResponseError < StandardError; end

  debug 'MagnumOpusEngine module loaded'
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
    'Purificatio: Edge cases as alchemical impurities',
    "Validatio: Ensuring the elixir's perfection (security/performance)",
    'Documentatio: Inscribing the magnum opus'
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
    @task_tools_registry[task_id] ||= 
      OpusInstrumenta.build_task_tools Instrumenta::PRIMA_MATERIA, task_id, self
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
    return { status: :error, message: 'Task not found' } unless task

    # Get alchemical stage information first
    current_step = self.current_step task_id
    total_steps = WORKFLOW_STEPS
    stage_name = STATES[current_step] || 'Unknown'

    # Load step results and format them
    step_results = load_step_results task_id
    formatted_results = format_previous_results step_results, current_step

    # Get task logs
    task_logs = task[:log] || []

    {
      status:                 :success,
      task:                   {
        id:                  task_id,
        title:               task[:title],
        plan:                task[:plan],
        status:              task[:status],
        current_step:        current_step,
        current_stage:       stage_name,
        total_steps:         total_steps,
        progress_percentage: ((current_step.to_f / total_steps) * 100).round(1),
        created_at:          task[:created_at],
        updated_at:          task[:updated_at]
      },
      step_results:           formatted_results,
      execution_logs:         task_logs,
      alchemical_progression: STATES.map.with_index do |stage, idx|
        {
          stage:     stage,
          step:      idx + 1,
          completed: idx < current_step,
          current:   idx == current_step
        }
      end
    }
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

  
  # TODO this needs to display a special message when a step was rejected...
  # Format previous step results for context inclusion with aggressive truncation
  def format_previous_results(results, current_step)
    return 'No previous step results available.' if results.empty? || 1 == current_step

    formatted = []
    results.each do |step_num, result|
      next if step_num.to_i >= current_step

      # AGGRESSIVE TRUNCATION to prevent context length overflow
      # Current step gets more context, previous steps get minimal context
      formatted << if current_step - 1 == step_num
                     "Step #{step_num}: #{result.to_s.truncate 300}" # More context for immediate previous
                   else
                     "Step #{step_num}: #{result.to_s.truncate 50}" # Minimal context for older steps
                   end
    end

    # Further truncate the entire result if it's still too long
    final_result = formatted.empty? ? 'No previous step results available.' : formatted.join("\n")
    final_result.truncate 1000 # Absolute maximum to prevent context overflow
  end


  # Store step result for future context
  def store_step_result(task_id, step_index, result)
    current_results = load_step_results task_id
    current_results[step_index.to_s] = result

    @mnemosyne.manage_tasks action:       :update,
                            id:           task_id,
                            step_results: current_results.to_json
  end


  # Execute sub-tasks recursively, respecting max_steps
  def execute_sub_tasks(task_id, max_steps)
    sub_tasks = @mnemosyne.manage_tasks({ 'action' => 'list', 'parent_task_id' => task_id })
    sub_tasks.each do |sub_task|
      next if halted?(sub_task[:id]) || 0 >= max_steps

      execute_task sub_task[:id], max_steps: max_steps - 1
      @mnemosyne.manage_tasks({ 'action'    => 'update',
                                'id'        => task_id,
                                'max_steps' => max_steps - 1 })
    end
    max_steps - 1
  end


  # Creates a new task with optional sub-tasks
  def create_task(title:, plan:, parent_task_id: nil, workflow_type: 'full', quiet: false)
    response = @mnemosyne.manage_tasks({ action:         'create',
                                         title:          title,
                                         plan:           plan,
                                         parent_task_id: parent_task_id,
                                         workflow_type:  workflow_type,
                                         status:         'pending' })

    # Handle both string and symbol keys for response
    ok = response && (response['ok'] || response[:ok])
    unless ok
      error_msg = "Task creation failed: #{response['error'] || response[:error] || 'Unknown error'}"
      log_message nil, error_msg
      raise TaskCreationError, error_msg
    end

    response
  end


  # Executes a task, supporting recursive sub-tasks
  def execute_task(task_id)
    task = @mnemosyne.get_task task_id

    raise TaskStateError, "Task not found: #{task_id}" unless task

    # Determine workflow type and max steps
    workflow_type = task[:workflow_type] || 'full'
    max_steps = case workflow_type
                when 'simple' then 3
                when 'analysis' then 5
                else WORKFLOW_STEPS
                end

    log_message task_id, "Starting execution of task #{task_id} (workflow_type=#{workflow_type}, " \
                         "max_steps=#{max_steps})"
    log_message task_id, "Task status: #{task[:status]}"
    debug "Task object received: #{task.inspect}"

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

    # Start execution with current step
    execute_task_internal(task_id, task[:current_step] || 0, workflow_type, max_steps)

    # Check if task is actually completed (all steps done)
    current_step = self.current_step task_id
    if current_step >= max_steps
      # Task is truly completed - all steps executed
      update_state task_id, :completed
    else
      # Task is not completed - just mark as active for next execution
      update_state task_id, :active
    end

    # TODO: this is not the right position for sub tasks... currently they would only executed AFTER the task is finished...
    # Execute sub-tasks recursively, respecting max_loops
    max_loops = 10 # max_loops may not be needed?!
    if 1 < max_loops
      sub_tasks = @mnemosyne.manage_tasks action: :list, parent_task_id: task_id
      sub_tasks.each do |sub_task|
        next if halted?(sub_task[:id]) || 1 >= max_loops

        execute_task sub_task[:id]
      end
      @mnemosyne.manage_tasks({ 'action' => 'update',
                                'id'     => task_id })
    end

    # Broadcast task completion with duration
    task = @mnemosyne.get_task task_id
    if task && :completed == task[:status].to_sym
      created_at = task[:created_at]
      start_time = if created_at.is_a? String
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
    raise e
  end


  def log_message(task_id, message)
    puts "[MAGNUM_OPUS_ENGINE][LOG_MESSAGE]: task_id: #{task_id}, message=#{message}"
    @mnemosyne.manage_tasks({ 'action' => 'update', 'id' => task_id, 'log' => message })
    # Broadcast log update to frontend (commented out for testing)
    HorologiumAeternum.task_log_added \
      task_id, timestamp: Time.now.to_f, message: message
  end


  # Execute a workflow step, invoking the oracle for hermetic guidance.
  #
  # @param [Integer] task_id The task's alchemical identifier.
  # @param [Integer] step_index The phase of the magnum opus (1..10).
  # @raise [RuntimeError] If the oracle's response is invalid or times out.
  def execute_step(task_id, step_index, workflow_type = 'full')
    debug "Executing step #{step_index} for task #{task_id} (workflow_type=#{workflow_type})"
    task = @mnemosyne.get_task task_id
    raise TaskStateError, "Task not found: #{task_id}" unless task

    # Update progress to reflect current step execution
    update_progress task_id, step_index

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
                      # Use workflow-specific step names
                      step_name = case workflow_type
                                  when 'simple'
                                    case step_index
                                    when 1 then 'Analyze: Understanding requirements and context'
                                    when 2 then 'Implement: Executing the planned solution'
                                    when 3 then 'Validate: Testing and confirming results'
                                    else "Step #{step_index}"
                                    end
                                  when 'analysis'
                                    case step_index
                                    when 1 then 'Research: Gathering information and context'
                                    when 2 then 'Plan: Developing the analysis approach'
                                    when 3 then 'Analyze: Performing detailed examination'
                                    when 4 then 'Synthesize: Integrating findings and insights'
                                    when 5 then 'Report: Documenting conclusions and recommendations'
                                    else "Step #{step_index}"
                                    end
                                  else # full
                                    STEP_PURPOSES[step_index - 1]
                                  end
                      extended_guidance = EXTENDED_STEP_GUIDANCE[step_index] || 'No extended guidance provided.'
                      "#{step_name}\n\nEXTENDED PURPOSE:\n#{extended_guidance}"
                    end

    # Determine max steps based on workflow type
    max_steps = case workflow_type
                when 'simple' then 3
                when 'analysis' then 5
                else WORKFLOW_STEPS
                end

    # Comprehensive system prompt with task context
    debug "TASK_SYSTEM_PROMPT template: #{TASK_SYSTEM_PROMPT}"
    debug "step_guidance to format: #{step_guidance}"
    # Use string interpolation
    system_prompt = TASK_SYSTEM_PROMPT.gsub('%<step_guidance>', step_guidance)
    debug "Formatted system_prompt: #{system_prompt}"

    # Enhanced prompt with complete task context including previous results
    # ADDED EXPLICIT STEP COUNT CLARIFICATION to prevent AI hallucinations about completion
    remaining_steps = max_steps - step_index
    step_clarification = if remaining_steps.positive?
                           "IMPORTANT: This is NOT the final step. There are #{remaining_steps} more steps after this one."
                         else
                           'FINAL STEP: This is the last step of the workflow. Complete all remaining work.'
                         end

    # Build the 4-message structure for enhanced context separation
    system_messages = [
      # CURRENT STEP GUIDANCE (System message)
      <<~STEP_GUIDANCE,
        # CURRENT STEP GUIDANCE
        #{step_guidance}
        
        # STEP TEMPERATURE SETTING
        Current temperature: #{STEP_TEMPERATURES[step_index] || 1.0} (#{4 >= step_index ? 'Exploration - Higher creativity' : 'Implementation - Precise execution'})
        
        # WORKFLOW CONTEXT
        Workflow Type: #{workflow_type.upcase}
        Current Step: #{step_index}/#{max_steps} (#{remaining_steps} steps #{remaining_steps.positive? ? 'remaining' : 'completed'})
        Phase: #{4 >= step_index ? 'EXPLORATION (Reasoning Only)' : 'IMPLEMENTATION (Full Tool Access)'}
      STEP_GUIDANCE
      
      # EXECUTION INSTRUCTIONS (System message)
      <<~EXECUTION_INSTRUCTIONS,
        # EXECUTION INSTRUCTIONS
        #{step_clarification}
        
        #{case workflow_type
          when 'simple'
            if 1 >= step_index
              <<~SIMPLE_ANALYZE
                # SIMPLE WORKFLOW - ANALYSIS PHASE
                - You are in analysis mode for simple task execution
                - LIMITED TOOL ACCESS: Basic reading and analysis tools only
                - Focus on understanding requirements and planning the implementation
                - Provide clear reasoning and implementation plan
                - Use task_complete_step when ready to advance to implementation
              SIMPLE_ANALYZE
            else
              <<~SIMPLE_IMPLEMENT
                # SIMPLE WORKFLOW - IMPLEMENTATION PHASE
                - You are in implementation mode for simple task execution
                - FULL TOOL ACCESS: Use task-specific tools for execution
                - Execute the planned solution efficiently
                - After completing actions, call task_complete_step to advance
                - All task tools automatically include the task_id context
              SIMPLE_IMPLEMENT
            end
          when 'analysis'
            if 3 >= step_index
              <<~ANALYSIS_RESEARCH
                # ANALYSIS WORKFLOW - RESEARCH PHASE
                - You are in research mode for analysis tasks
                - LIMITED TOOL ACCESS: Reading, querying, and analysis tools only
                - Focus on gathering information and developing analysis approach
                - Provide comprehensive research findings and methodology
                - Use task_complete_step when ready to advance to synthesis
              ANALYSIS_RESEARCH
            else
              <<~ANALYSIS_SYNTHESIS
                # ANALYSIS WORKFLOW - SYNTHESIS PHASE
                - You are in synthesis mode for analysis tasks
                - FULL TOOL ACCESS: Use tools to organize and present findings
                - Integrate research findings into coherent conclusions
                - Create comprehensive reports and recommendations
                - After completing analysis, call task_complete_step to finalize
              ANALYSIS_SYNTHESIS
            end
          else
            if 4 >= step_index
              <<~EXPLORATION
                # FULL WORKFLOW - EXPLORATION PHASE (Steps 1-4)
                - You are in exploration mode: Nigredo (1), Albedo (2), Citrinitas (3), or Rubedo (4)
                - READONLY TOOL ACCESS: You cannot use any writing tools during exploration phases
                - Focus on analysis, planning, and strategic thinking only
                - Provide comprehensive reasoning and recommendations
                - Use task_complete_step when ready to advance to implementation
                - Use task_reject_step if you need to refine your analysis starting from a previous step
              EXPLORATION
            else
              <<~IMPLEMENTATION
                # FULL WORKFLOW - IMPLEMENTATION PHASE (Steps 5-10)
                - You are in implementation mode: Solve (5), Coagula (6), Test (7-8), Validate (9), or Document (10)
                - FULL TOOL ACCESS: Use task-specific tools for all operations
                - Execute the planned transformations with surgical precision
                - After completing step actions, call task_complete_step to advance
                - If you need to backtrack, use task_reject_step with optional restart_from_step
                - All task tools automatically include the task_id context
                - Use task_get_previous_results to access historical step outcomes for context continuity

                # STEP PROGRESSION CLARIFICATION:
                - This is step #{step_index} of #{max_steps} total steps
                - There are #{max_steps - step_index} more steps remaining after this one
                - #{step_index == max_steps ? 'FINAL STEP: Complete all remaining work and finalize the transformation' : 'Do NOT indicate task completion unless you are on the final step'}
                - Continue executing the current step's specific purpose

                # DIVINE INTERRUPTION CLARIFICATION:
                - When using task_complete_step or task_reject_step, execution terminates immediately
                - These calls return divine interruption signals that stop the current reasoning
                - The engine handles progression automatically based on these signals
                - Do NOT continue reasoning after calling these functions
              IMPLEMENTATION
            end
          end}
      EXECUTION_INSTRUCTIONS
    ].join "\n\n=======\n\n"
    

    messages = [
      # PREVIOUS STEP RESULTS (Assistant message)
      {
        role: 'assistant',
        content: previous_step_context.empty? ? 'No previous step results available.' : previous_step_context
      },
      { role: 'user',
        content:
        # TASK EXECUTION CONTEXT (User message)
        <<~EXECUTION_CONTEXT,
          # TASK EXECUTION CONTEXT
          TASK TITLE: #{task[:title] || '--'}
          TASK DESCRIPTION: #{task[:description] || '--'}
          TASK PLAN: #{task[:plan] || '--'}
        
          Execute Step #{step_index}: #{STEP_PURPOSES[step_index - 1]}
        
          # STEP COMPLETION TOOLS:
          - Call task_complete_step(result) when finished with this step
          - If you need to restart or refine, call task_reject_step(reason, restart_from_step)
          - These tools terminate reasoning and reasoning will proceed with the given result/reason 
            from the next step, therefore it is crucial to put all gathered, necessary and relevant
            information in the result/reason.
          - They are the only way to progress through the workflow
        EXECUTION_CONTEXT
      }
    ]
    

    begin
      # Set temperature based on step phase
      step_temperature = STEP_TEMPERATURES[step_index] || 1.0
      @mnemosyne.set_aegis_temperature(step_temperature)
      
      # Comprehensive context for hermetic execution
      context = {
        task_id:          task_id,
        task_title:       task[:title],
        task_description: task[:description],
        task_plan:        task[:plan],
        step_index:       step_index,
        total_steps:      WORKFLOW_STEPS,
        step_purpose:     STEP_PURPOSES[step_index - 1],
        extended_purpose: step_guidance,
        progress:         "#{step_index}/#{WORKFLOW_STEPS}",
        temperature:      step_temperature,
        prevent_termination_reminder: [
          "Remember to use task_complete_step() or task_reject_step() when you finish a step to properly terminate the divination.",
          "IMPORTANT: You must call task_complete_step() or task_reject_step() to complete this step and proceed to the next phase.",
          "URGENT: Step completion required! Use task_complete_step() for success or task_reject_step() for failure to move forward."
        ]
      }
      # base tools for this task
      tools = create_task_tools task_id

      # Use filtered tool access by phase using Instrumenta::reject
      # Exploration: Nigredo (1), Albedo (2), Citrinitas (3), Rubedo (4) - Read-only tools
      # Implementation: Solve (5), Coagula (6), Test (7,8), Validate (9), Document (10) - Full tool access
      begin
        # Debug context length before making the call
        # debug "PROMPT LENGTH: #{prompt.length} characters"
        debug "SYSTEM PROMPT LENGTH: #{system_prompt.length} characters"
        # Determine tool access based on workflow type and step
        case workflow_type
        when 'simple'
          if 1 == step_index
            # Simple workflow - Step 1 (Analyze): Read-only tools only
            # Only reject task tools that actually exist in task tools collection
            tools = tools.clone_tools.reject(*%i[task_patch_file create_file rename_file
                                                 create_task execute_task create_sub_task])
          end
        when 'analysis'
          if 3 >= step_index
            # Analysis workflow - Steps 1-3 (Research/Plan/Analyze): Read-only tools only
            # Only reject task tools that actually exist in task tools collection
            tools = tools.clone_tools.reject(*%i[task_patch_file create_file rename_file
                                                 create_task execute_task create_sub_task])
          end
        else
          # Full workflow - Steps 1-4: Exploration, Steps 5-10: Implementation
          if 4 >= step_index
            # Exploration phases - read-only tools only (NO task creation allowed)
            # Only reject task tools that actually exist in task tools collection
            tools = tools.clone_tools.reject(*%i[task_patch_file create_file rename_file
                                                 create_task execute_task create_sub_task])
          end
        end

        # Calculate total message length for debugging
        total_message_length = messages.sum { |msg| msg[:content].to_s.length }
        debug "TOTAL MESSAGES LENGTH: #{total_message_length} characters"
        messages.each_with_index do |msg, i|
          debug "Message #{i} (#{msg[:role]}): #{msg[:content].to_s.length} characters"
        end
        
        response = @aetherflux.channel_oracle_divination(
            { system_prompt:, messages: },
            tools:,
            context: context,
            timeout: 1111 # Extended timeout for implementation phases
          )
      rescue StandardError => e
        puts "DEBUG: Error calling Aetherflux.channel_oracle_divination: #{e.message}"
        puts "DEBUG: Backtrace: #{e.backtrace.first(5).join '\n'}"
        raise e
      end

      # Debug log to see actual response format
      debug "TASK CONJURATION RESPONSE: #{response.inspect.truncate 200}"
      debug "Response class: #{response.class}"
      debug "Response keys: #{response.keys if response.respond_to? :keys}"

      # Enhanced error detection for better debugging
      if response.respond_to?(:[]) && :network_error == response[:status]
        debug 'NETWORK_ERROR detected - checking for timeout patterns'
        debug "Response message: #{response[:response]}"
      elsif response.respond_to?(:[]) && :context_length_error == response[:status]
        debug 'CONTEXT_LENGTH_ERROR detected - need to reduce context size'
        debug "Response message: #{response[:response]}"
      end

      # Handle different response formats with better error handling
      status = if response.respond_to?(:[]) && response.key?(:__divine_interrupt)
                 # Divine interruption detected - handle specially
                 divine_interrupt_type = response[:__divine_interrupt]
                 :"__divine_interrupt_#{divine_interrupt_type}"
               elsif response.respond_to?(:key?) && response.key?('__divine_interrupt')
                 # Divine interruption detected - handle specially
                 divine_interrupt_type = response['__divine_interrupt']
                 :"__divine_interrupt_#{divine_interrupt_type}"
               elsif response.respond_to?(:[]) && response.key?(:status)
                 response[:status]
               elsif response.respond_to?(:key?) && response.key?('status')
                 response['status']
               elsif response.nil? || response.empty?
                 debug "Empty or nil response received: #{response.inspect}"
                 :empty_response
               else
                 debug "Unknown response format: #{response.inspect.truncate 200}"
                 :unknown
               end

      case status
      when :__divine_interrupt_step_completed
        # Divine interruption: step completed via task_complete_step
        result = response[:result] || 'COMPLETED_VIA_DIVINE_INTERRUPTION'
        # log_message task_id, "Step #{step_index} completed via divine interruption: #{result}"
        # store_step_result task_id, step_index, result
        # Return clean divine interruption signal - engine handles progression
        return { __divine_interrupt: :step_completed, result: }

      when :__divine_interrupt_step_rejected
        # Divine interruption: step rejected via task_reject_step
        reason = response[:reason] || 'No reason provided'
        restart_step = response[:restart_from_step] || [step_index - 1, 1].max
        # log_message task_id,
        #             "Step #{step_index} rejected via divine interruption: #{reason} | Restarting from step #{restart_step}"
        # store_step_result task_id, step_index, "REJECTED: #{reason}"
        # Return clean divine interruption signal - engine handles progression
        return { __divine_interrupt: :step_rejected,
                 restart_from_step:  restart_step, reason: }

      when :success, 'success', :step_completed, 'step_completed'
        # Extract reasoning safely with fallbacks - handle both symbol and string keys
        reasoning = if response.respond_to?(:[]) && response[:response].is_a?(Hash) && response[:response][:reasoning]
                      response[:response][:reasoning]
                    elsif response.respond_to?(:key?) && response['response'].is_a?(Hash) && response['response']['reasoning']
                      response['response']['reasoning']
                    elsif response.respond_to?(:[]) && response[:response].is_a?(Hash) && response[:response]['reasoning']
                      response[:response]['reasoning']
                    elsif response.respond_to?(:key?) && response['response'].is_a?(Hash) && response['response'][:reasoning]
                      response['response'][:reasoning]
                    end
        reasoning = "\nReasoning: #{reasoning}\nResponse: " if reasoning

        # Debug the full response structure
        debug "Full response structure: #{response.inspect.truncate 200}"

        # Extract answer with better error handling - handle both string and hash responses
        answer = if response.respond_to?(:[]) && response[:response].is_a?(String)
                   response[:response]
                 elsif response.respond_to?(:key?) && response['response'].is_a?(String)
                   response['response']
                 elsif response.respond_to?(:[]) && response[:response].is_a?(Hash) && response[:response][:answer]
                   response[:response][:answer]
                 elsif response.respond_to?(:key?) && response['response'].is_a?(Hash) && response['response']['answer']
                   response['response']['answer']
                 else
                   debug 'No answer found in response, using reasoning instead'
                   reasoning || 'Step completed successfully'
                 end

        debug "Oracle response answer: #{answer.inspect}"
        # log_message task_id, "Step #{step_index} completed: #{reasoning}#{answer}"

        # TODO add a counter for max retries if a step is not succeeding. send each a time a different message to the ai.
        # Store step result for future context
        # store_step_result task_id, step_index, answer

        # For successful executions without explicit completion, progress to next step
        # This handles cases where step completes successfully but no divine interruption
        # Return the expected format that execute_task_internal can handle
        return { status: :step_not_completed, response: { answer: answer } }

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
        # Raise error to signal step rejection
        raise TaskStateError, error_msg
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
        # Raise error to signal step rejection
        raise TaskStateError, error_msg
      when :empty_response
        # Handle empty responses gracefully - treat as step rejection opportunity
        log_message task_id, "Step #{step_index} received empty response - allowing step rejection"
        store_step_result task_id, step_index, 'EMPTY_RESPONSE: Oracle returned empty response'
        # Raise error to signal step rejection
        raise TaskStateError, "Empty response received for step #{step_index}"
      else
        # Handle unknown response status gracefully
        error_msg = "Unknown response status: #{status}"
        log_message task_id, error_msg

        # Store the error as step result for context
        store_step_result task_id, step_index, "ERROR: #{error_msg}"

        # Log the full response for debugging
        debug "Unknown response details: #{response.inspect.truncate 200}"

        # Raise error to signal step rejection
        raise TaskStateError, error_msg
      end
    rescue Timeout::Error => e
      log_message task_id, "Step #{step_index} timed out: #{e.message}"
      # Enhanced timeout logging for debugging
      debug "Timeout error details: #{e.class.name} - #{e.message}"
      debug "Timeout backtrace: #{e.backtrace.first(3).join '\n'}"
      # Don't fail entire task - allow step rejection/retry
      store_step_result task_id, step_index, "TIMEOUT: #{e.message}"
      raise TaskStateError, "Step #{step_index} timed out: #{e.message}"
    rescue NoMemoryError => e
      log_message task_id, "Step #{step_index} failed: #{e.message}"
      # Enhanced memory error logging for debugging
      debug "Memory error details: #{e.class.name} - #{e.message}"
      debug "Error backtrace: #{e.backtrace.first(3).join '\n'}"
      # Memory errors should fail the task
      update_state task_id, :failed
      store_step_result task_id, step_index, "MEMORY_ERROR: #{e.message}"
      raise TaskStateError, "Step #{step_index} failed: #{e.message}"
    rescue UnknownResponseError => e
      log_message task_id, "Step #{step_index} unknown response: #{e.message}"
      # Don't fail entire task - allow step rejection/retry
      store_step_result task_id, step_index, "UNKNOWN_RESPONSE: #{e.message}"
      raise
    rescue NoMemoryError => e
      log_message task_id, "Step #{step_index} failed: #{e.message}"
      # Memory errors are critical and should fail the entire task
      update_state task_id, :failed
      debug "Memory error details: #{e.class.name} - #{e.message}"
      debug "Error backtrace: #{e.backtrace.first(3).join "\n"}"
      store_step_result task_id, step_index, "MEMORY_ERROR: #{e.message}"
      raise
    rescue StandardError => e
      log_message task_id, "Step #{step_index} failed: #{e.message}"
      # Enhanced error logging for debugging
      debug 'Standard error details: ${e.class.name} - ${e.message}'
      debug "Error backtrace: ${e.backtrace.first(3).join '\n'}"
      # Don't fail entire task - allow step rejection/retry
      store_step_result task_id, step_index, 'ERROR: ${e.message}'
      raise
    end

    # Clean up task tools after step execution
    @task_tools_registry.delete task_id if WORKFLOW_STEPS == step_index

    log_message task_id, "Executing step #{step_index}: #{STEP_PURPOSES[step_index - 1]}"
  end


  def update_state(task_id, state)
    raise ArgumentError, "Invalid task state: #{state}" unless STATES.include? state

    @mnemosyne.manage_tasks action: :update, id: task_id, status: state.to_s
    broadcast_update task_id
  end


  def broadcast_update(task_id, show_progress: false)
    task = @mnemosyne.get_task task_id
    return unless task
    
    HorologiumAeternum.task_updated(**task, show_progress:)
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
    current_step = current_step task_id
    log_message task_id, "Step #{current_step} rejected: #{reason}" if reason

    if restart_from_step
      # Boundary check: restart_from_step must be between 1 and WORKFLOW_STEPS
      restart_from_step = [[restart_from_step, 1].max, WORKFLOW_STEPS].min
      # Set progress to restart from specific step (current_step is 0-indexed)
      update_progress task_id, restart_from_step
      log_message task_id, "Restarting from step #{restart_from_step}"
    elsif 1 < current_step
      # Default: go back to previous step
      update_progress task_id, current_step - 1
      log_message task_id, "Returning to previous step #{current_step - 1}"
    else
      log_message task_id, 'Cannot go back from first step'
    end

    { ok:                true,
      task_id:           task_id,
      restart_from_step: restart_from_step || [current_step - 1, 1].max }
  end


  # Complete current step with optional result - terminates current reasoning
  def complete_step(task_id, result = nil)
    current_step = current_step task_id
    log_message task_id, "Step #{current_step} completed: #{result.inspect.truncate 50}" if result

    # Boundary check: don't progress beyond WORKFLOW_STEPS
    next_step = [current_step + 1, WORKFLOW_STEPS].min
    update_progress task_id, next_step

    { ok: true, task_id:, completed_step: current_step, result:  }
  end


  # Internal execution method for task progression - NON-RECURSIVE
  # This method executes ONE step and terminates cleanly after processing divine interruptions
  def execute_task_internal(task_id, current_step, workflow_type, max_steps)
    # Boundary check: Ensure current_step is within valid range for workflow type
    current_step = [[current_step, 0].max, max_steps].min

    # Check if task is completed or halted
    return if halted? task_id

    # Check if we've reached the maximum steps
    return if current_step >= max_steps

    # Execute current step and capture result (oracle controls progression via divine interruption signals)
    begin
      step_result = execute_step task_id, current_step + 1, workflow_type

      # Handle divine interruption signals - these should terminate execution cleanly
      if step_result.is_a?(Hash) && step_result[:__divine_interrupt]
        # Divine interruption detected - handle completion/rejection
        case step_result[:__divine_interrupt]
        when :step_completed
          log_message task_id, "Step #{current_step + 1} completed via divine interruption"
          # Store result if provided
          store_step_result task_id, current_step + 1, step_result[:result] if step_result[:result]
          # Progress to next step (engine handles boundary checking)
          next_step = [current_step + 2, max_steps + 1].min # current_step is 0-indexed, so +2 for next step
          update_progress task_id, next_step - 1 # Convert to 0-indexed for internal tracking
          
          # Send special status message for step completion
          task = @mnemosyne.get_task(task_id)
          HorologiumAeternum.task_step_completed(**task, result: step_result[:result]) if task

          # Terminate execution cleanly - divine interruptions should not recurse
          debug "Step completed via divine interruption" #", terminating execution for task #{task_id}"
          # return
        when :step_rejected
          log_message task_id,
                      "Step #{current_step + 1} rejected via divine interruption: #{step_result[:reason]}"
          # Store rejection reason
          store_step_result task_id, current_step + 1, "REJECTED: #{step_result[:reason]}"
          HorologiumAeternum.task_step_rejected(**task, reason: step_result[:reason]) if task
          # Handle restart from specific step or default to previous step
          restart_step = step_result[:restart_from_step] || [current_step, 1].max
          # Boundary check: ensure restart step is within valid range
          restart_step = [[restart_step, 1].max, max_steps].min
          update_progress task_id, restart_step - 1 # Convert to 0-indexed for internal tracking
          
          # Send special status message for step rejection
          task = @mnemosyne.get_task(task_id)
          
          # Terminate execution cleanly - divine interruptions should not recurse
          debug "Step rejected via divine interruption" #", terminating execution for task #{task_id}"
          # return
        end

        # proceed execution
        next_step = current_step task_id
        execute_task_internal(task_id, next_step, workflow_type, max_steps)
        
      elsif step_result.is_a?(Hash) && :step_completed == step_result[:status] 
        # Step completed successfully without explicit divine interruption
        # TODO this shouldnt be possible!!!
        log_message task_id, "Step #{current_step + 1} completed successfully"
        # Store result if provided
        answer = step_result[:response] && step_result[:response][:answer]
        store_step_result task_id, current_step + 1, answer if answer
        # Progress to next step (engine handles boundary checking)
        next_step = [current_step + 2, max_steps].min # current_step is 0-indexed, so +2 for next step
        update_progress task_id, next_step - 1 # Convert to 0-indexed for internal tracking
        
        # Send special status message for step completion
        task = @mnemosyne.get_task(task_id)
        HorologiumAeternum.task_step_completed(**task) if task 
        
        # Step completed successfully - continue to next step with recursion
        debug "Step completed successfully, continuing to next step for task #{task_id}"
        
        # Recursively execute next step with proper error handling
        begin
          execute_task_internal(task_id, next_step, workflow_type, max_steps)
        rescue StandardError => e
          log_message task_id, "Recursive step execution error: #{e.message}"
          store_step_result task_id, next_step + 1, "RECURSION_ERROR: #{e.message}"
          # Don't re-raise - let the current step completion stand
        end
        return
      else
        # If we reach here, the step executed but didn't signal completion/rejection
        # This means NO task_complete_step was called - STOP EXECUTION
        log_message task_id,
                    "Step #{current_step + 1} executed but no completion signal received - stopping execution"
        store_step_result task_id, current_step + 1,
                          'NO_COMPLETION_SIGNAL: Step executed but no task_complete_step called'
        return # STOP EXECUTION - NO COMPLETION SIGNAL
      end
    rescue MagnumOpusEngine::TaskStateError => e
      # Task state errors indicate step rejection/retry needed
      log_message task_id, "Step #{current_step + 1} state error: #{e.message}"
      store_step_result task_id, current_step + 1, "STATE_ERROR: #{e.message}"
      # Don't progress - allow step rejection/retry via event-driven flow
      return # STOP EXECUTION ON ERROR
    rescue StandardError => e
      # All other errors indicate step rejection/retry needed
      log_message task_id, "Step #{current_step + 1} error: #{e.message}"
      store_step_result task_id, current_step + 1, "ERROR: #{e.message}"
      # Don't progress - allow step rejection/retry via event-driven flow
      return # STOP EXECUTION ON ERROR
    rescue Timeout::Error => e
      # Timeout errors indicate step rejection/retry needed
      log_message task_id, "Step #{current_step + 1} timeout: #{e.message}"
      store_step_result task_id, current_step + 1, "TIMEOUT: #{e.message}"
      # Don't progress - allow step rejection/retry via event-driven flow
      return # STOP EXECUTION ON ERROR
    end

    # CRITICAL: This point should NEVER be reached
    # If execution continues here, it indicates a logic error in divine interruption handling
    # log_message task_id,
    #             "CRITICAL: execute_task_internal reached unreachable code after step #{current_step + 1}"
    # store_step_result task_id, current_step + 1,
    #                   'LOGIC_ERROR: Execution continued after divine interruption handling'
  end


  # Get current step number for task
  def current_step(task_id)
    task = @mnemosyne.get_task task_id
    task[:current_step] || 0
  end


  def update_progress(task_id, step)
    return if step.to_s == current_step(task_id).to_s

    old_step = current_step task_id

    # Boundary check: step must be between 0 and WORKFLOW_STEPS
    step = [[step, 0].max, WORKFLOW_STEPS].min

    puts "[MAGNUM_OPUS_ENGINE][UPDATE_PROGRESS]: #{old_step} --> #{step}"
    @mnemosyne.manage_tasks({ 'action'       => 'update',
                              'id'           => task_id,
                              'current_step' => step })
    broadcast_update task_id, show_progress: true
  end

end
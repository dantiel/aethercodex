# MAGNUM OPUS ENGINE - COMPREHENSIVE DOCUMENTATION

## OVERVIEW

The Magnum Opus Engine is a sophisticated, event-driven state machine for executing multi-step alchemical workflows following hermetic principles. It provides user-controlled step progression with proper error handling, graceful degradation, and database persistence.

## ARCHITECTURE PRINCIPLES

- **Event-driven state machine** (no infinite loops or forced progression)
- **User-controlled step completion/rejection** (hermetic user sovereignty)
- **Circuit breaker pattern** for error handling and graceful degradation
- **Adaptive timeout management** with context-aware durations
- **Database persistence** of task state via Mnemosyne
- **Comprehensive error categorization** and targeted recovery strategies
- **Context continuity** through step result storage and retrieval
- **Recursive sub-task execution** with loop limits and boundary checks

## KEY FEATURES

- **10-stage alchemical workflow** (Nigredo → Albedo → Citrinitas → Rubedo → Solve → Coagula → Test → Test → Validate → Document)
- **Dynamic task tools** with automatic task_id context inclusion
- **Response format standardization** to prevent "Unknown response status" errors
- **Boundary checks** for step progression (1..WORKFLOW_STEPS range enforcement)
- **Broadcast state updates** to HorologiumAeternum for real-time UI synchronization
- **Support for nested sub-tasks** with maximum loop protection

## AL CHEMICAL WORKFLOW STAGES

### 1. Nigredo Phase - Understanding the Prima Materia
**Purpose**: Thoroughly analyze task requirements and business context
**Activities**: 
- Read all relevant files to understand current state
- Identify what needs to be transformed
- Examine codebase structure, dependencies, and existing patterns
- Document constraints, edge cases, and potential pitfalls

### 2. Albedo Phase - Defining the Purified Solution
**Purpose**: Clarify and refine the solution approach
**Activities**:
- Define clean, purified state that should emerge
- Specify requirements, interfaces, and expected behaviors
- Design architectural patterns, data structures, and algorithms
- Document proposed architecture and validate against requirements

### 3. Citrinitas Phase - Exploring Golden Implementation Paths
**Purpose**: Explore multiple implementation approaches and select the most optimal
**Activities**:
- Research best practices, patterns, and existing solutions
- Evaluate different implementation strategies
- Create proof-of-concepts or prototypes if necessary
- Select implementation path balancing elegance, efficiency, and practicality

### 4. Rubedo Phase - Selecting the Philosopher's Stone
**Purpose**: Finalize implementation details and prepare for actual coding
**Activities**:
- Create detailed technical specifications
- Specify exact implementation details and third-party libraries
- Break down implementation into manageable chunks
- Define order of implementation and dependencies

### 5. Solve Phase - Identifying Required Dissolutions
**Purpose**: Begin transformation by identifying what needs to be dissolved or removed
**Activities**:
- Analyze existing code to determine refactoring needs
- Identify patterns, anti-patterns, and optimization opportunities
- Specify exact code changes needed
- Create detailed change plan minimizing disruption

### 6. Coagula Phase - Implementing Solid Transformations
**Purpose**: Execute planned code changes with surgical precision
**Activities**:
- Implement changes in small, manageable increments
- Verify code compiles and basic functionality works after each change
- Write clean, well-documented code following established patterns
- Ensure proper error handling and edge case coverage

### 7. Test Phase - Probing the Elixir's Purity
**Purpose**: Begin comprehensive testing of implemented changes
**Activities**:
- Test all primary use cases and scenarios
- Verify inputs produce correct outputs
- Test integration with existing components and systems
- Ensure data flows properly between different system parts

### 8. Purificatio Phase - Edge Cases as Alchemical Impurities
**Purpose**: Focus on testing edge cases, boundary conditions, and error scenarios
**Activities**:
- Test system limits (minimum/maximum values, empty inputs, extreme conditions)
- Verify graceful handling of boundary conditions
- Test failure conditions (network outages, invalid inputs, resource constraints)
- Ensure clear error messages and graceful failure without data loss

### 9. Validatio Phase - Ensuring the Elixir's Perfection
**Purpose**: Perform final validation ensuring solution meets quality standards
**Activities**:
- Review code for potential security vulnerabilities
- Test solution under load to ensure performance requirements
- Profile critical paths and optimize bottlenecks
- Verify resource usage within acceptable limits

### 10. Documentatio Phase - Inscribing the Magnum Opus
**Purpose**: Create comprehensive documentation capturing the transformation process
**Activities**:
- Write detailed technical documentation including architecture overview
- Create API references, deployment instructions, and troubleshooting guides
- Include code comments and inline documentation
- Enable knowledge transfer for other developers

## ERROR HANDLING ARCHITECTURE

The engine implements a layered error handling approach with specific recovery strategies:

### 1. Timeout::Error (120s normal, 300s extended timeout)
**Recovery**: Step rejection/retry, timeout adjustment
**Transient**: Network connectivity issues, API delays

### 2. NetworkError (HTTP errors, connectivity issues)
**Recovery**: Step rejection/retry, exponential backoff
**Transient**: Network outages, API availability

### 3. ContextLengthError (token limit exceeded)
**Recovery**: Context truncation, prompt optimization
**Requires**: Response format compliance, truncation logic

### 4. RateLimitError (API rate limiting)
**Recovery**: Exponential backoff, request pacing
**Requires**: Rate limit detection, backoff strategy

### 5. EmptyResponse (nil or empty oracle response)
**Recovery**: Step rejection, prompt refinement
**Treated as**: User intervention opportunity

### 6. UnknownResponse (unrecognized response format)
**Recovery**: Logging, step rejection with diagnostics
**Prevention**: Response format standardization

### 7. StandardError (general fallback)
**Recovery**: Graceful degradation, error logging
**Ensures**: Task doesn't crash, allows user intervention

## RESPONSE FORMAT STANDARD

All oracle responses (divination and conjuration) must follow this exact format:

```json
{
  "status": "success|failure|timeout|network_error|context_length_error|rate_limit_error",
  "response": {
    "reasoning": "AI reasoning text",
    "answer": "response text", 
    "html": "formatted HTML",
    "patch": "code patches",
    "tasks": "task data",
    "tools": "tool usage",
    "tool_results": [],
    "logs": [],
    "next_step": "guidance"
  }
}
```

**Critical**: The 'status' key must be present as a symbol for proper engine parsing.

## STATE MANAGEMENT

Task states follow alchemical progression with proper transitions:

- `:pending` → `:running` → `:completed` (normal hermetic flow)
- `:pending` → `:running` → `:failed` (terminal error, requires user intervention)
- `:pending` → `:running` → `:paused` (user-requested pause for refinement)
- Any state → `:cancelled` (user cancellation with graceful termination)

State transitions are persisted in Mnemosyne and broadcast to UI components.

## STEP PROGRESSION MECHANISM

Steps advance ONLY through explicit user-controlled signals:

- `task_complete_step(result)` - advances to next step with optional result storage
- `task_reject_step(reason, restart_from_step)` - returns to specified step for refinement
- **NO automatic progression** - user maintains complete control over workflow pace
- Boundary checks ensure steps stay within valid 1..WORKFLOW_STEPS range
- Step results are stored as JSON for context continuity across steps

## DATABASE INTEGRATION (MNEMOSYNE)

- All task state, progress, and results persisted in database
- Step results stored as JSON blobs for historical context access
- Progress tracking with boundary validation and consistency checks
- Broadcast updates to HorologiumAeternum for real-time UI synchronization
- Support for task resumption across sessions via persistent state

## STEP RESULTS DISPLAY SYSTEM

### Backend Architecture

**Result Storage Format**:
```json
{
  "1": "Nigredo analysis result text...",
  "2": "Albedo architecture definition...",
  "3": "Citrinitas implementation..."
}
```

**Key Methods**:
- `store_step_result(task_id, step_index, result)` - Stores results with type normalization
- `load_step_results(task_id)` - Loads and parses step results from database
- `format_previous_results(results, current_step)` - Applies balanced truncation:
  - Current step: 500 chars
  - Previous step: 200 chars  
  - Older steps: 100 chars
  - Overall limit: 1500 chars

### Frontend Architecture

**Enhanced Type Safety**:
- `safeSubstring(value, length)` - Handles all result types without errors
- `normalizeResult(result)` - Extracts meaningful content from objects

**UI Components**:
- Latest result preview with meaningful content
- Clickable step navigation with popup result display
- Progress bar with alchemical stage indicators
- Unified task panel with progress and logs

## TROUBLESHOOTING GUIDE

### 1. "Unknown response status" error
**Cause**: Missing or malformed 'status' key in oracle response
**Fix**: Ensure response follows format standard with status: symbol
**Verification**: Check both channel_oracle_divination and channel_oracle_conjuration

### 2. Timeout errors
**Cause**: Network issues or API delays exceeding timeout limits
**Fix**: Verify network connectivity, adjust Aetherflux timeout settings
**Recovery**: Engine automatically handles timeouts with step rejection capability

### 3. Context length errors
**Cause**: Token count exceeds model maximum (e.g., 245k > 131k limit)
**Fix**: Implement context truncation in oracle prompts and responses
**Prevention**: Use String#truncate method and monitor token usage

### 4. Rate limit errors
**Cause**: API request rate exceeded provider limits
**Fix**: Implement exponential backoff in Aetherflux request handling
**Strategy**: Progressive wait times with maximum attempt limits

### 5. Empty responses
**Cause**: Oracle connectivity issues or prompt design problems
**Fix**: Check oracle connectivity, refine prompt design, verify response parsing
**Handling**: Treated as step rejection opportunity for user intervention

### 6. Infinite loops
**Cause**: Missing step completion/rejection calls in oracle logic
**Fix**: Ensure all oracle responses include proper step management calls
**Prevention**: Event-driven architecture eliminates forced progression risks

## BEST PRACTICES

### 1. Always use task-specific tools
- `task_read_file`, `task_patch_file`, `task_recall_notes`, etc.
- These automatically include task_id context for proper execution

### 2. Implement proper error handling in oracle responses
- Always include status: symbol in responses
- Use specific error status codes for targeted recovery
- Provide detailed error information in response fields

### 3. Use context continuity features
- `task_get_previous_results()` for historical step context
- Store relevant data in step results for future reference
- Maintain state across steps for complex multi-step transformations

### 4. Design effective prompts
- Include clear step purposes and extended guidance
- Provide context about previous step outcomes when relevant
- Structure prompts for optimal token usage and clarity

### 5. Test error scenarios thoroughly
- Verify graceful degradation under various failure conditions
- Test timeout handling, network errors, and rate limiting
- Ensure proper state persistence and recovery mechanisms

### 6. Implement boundary checks
- Validate step progression within 1..WORKFLOW_STEPS range
- Enforce maximum loop limits for recursive operations
- Prevent index out-of-range errors and infinite recursion

## LESSONS LEARNED FROM ARCHITECTURAL REFACTOR

### 1. Original imperative loop architecture caused critical issues:
- Infinite loops from missing step completion calls
- Forced progression violated hermetic user sovereignty principles
- No graceful error handling - tasks would crash on failures

### 2. Event-driven state machine solved core problems:
- Eliminated infinite loops through explicit step control
- Restored user control over step progression timing
- Enabled proper error handling and graceful degradation
- Supported complex state transitions and recovery scenarios

### 3. Response format standardization was critical:
- Prevented "Unknown response status" errors completely
- Enabled consistent error handling across all oracle operations
- Simplified response parsing and state transition logic

### 4. Database persistence enabled robust recovery:
- Task state survives across sessions and interruptions
- Step results provide historical context for resumption
- Enables complex multi-session transformation workflows

### 5. Boundary checks prevent cascading failures:
- Step range validation prevents index errors
- Loop limits prevent infinite recursion in sub-tasks
- Progress validation ensures state consistency

## DEPLOYMENT INSTRUCTIONS

### 1. Database Configuration
- Ensure Mnemosyne database is properly configured and accessible
- Verify database connection settings and permissions

### 2. Aetherflux Configuration
- Set appropriate timeout values based on network conditions
- Configure retry strategies for network errors and rate limiting
- Implement context truncation logic for large responses

### 3. Error Handling Setup
- Test all error scenarios to verify graceful degradation
- Monitor execution logs for timeout patterns and adjust accordingly
- Implement proper logging for debugging and maintenance

### 4. Performance Tuning
- Adjust timeout values based on API performance characteristics
- Monitor context length usage and optimize prompt design
- Implement caching strategies for frequently accessed data

### 5. Monitoring and Maintenance
- Regularly review timeout settings based on API performance trends
- Monitor context length usage and implement truncation as needed
- Update error handling for new API error types and patterns
- Maintain response format compatibility across oracle operations

## API REFERENCE

### Core Methods

- `execute_task(task_id, max_steps: 10)` - Main execution entry point
- `execute_step(task_id, step_index)` - Execute specific workflow step
- `complete_step(task_id, result)` - Complete current step with result storage
- `reject_step(task_id, reason, restart_from_step)` - Reject current step with optional restart
- `create_task(title:, plan:, parent_task_id:)` - Create new task with optional parent context
- `update_progress(task_id, step)` - Update task progress with boundary validation
- `halted?(task_id)` - Check if task execution should halt (cancelled/paused/failed)

### Utility Methods

- `broadcast_state(task_id, state)` - Broadcast state changes to UI components
- `store_step_result(task_id, step_index, result)` - Persist step results for context
- `get_step_result(task_id, step_index)` - Retrieve historical step results
- `validate_step_range(step)` - Ensure step is within valid 1..WORKFLOW_STEPS range

## EXAMPLE USAGE

```ruby
engine = MagnumOpusEngine.new(mnemosyne: Mnemosyne, aetherflux: Aetherflux)
task = engine.create_task(title: "Refactor User Authentication", plan: "Modernize auth system")
engine.execute_task(task['id'])
```

The engine will execute the 10-step alchemical workflow, pausing at each step for user intervention through step completion or rejection signals.

## MAINTENANCE SCHEDULE

- **Daily**: Monitor execution logs for timeout and error patterns
- **Weekly**: Review context length usage and optimize truncation logic
- **Monthly**: Update error handling for new API error types
- **Quarterly**: Review timeout settings based on performance metrics
- **Annually**: Comprehensive architecture review and optimization

## SUPPORT CONTACTS

- **Primary**: AetherCodex Oracle System
- **Backup**: TextMate Bundle Maintenance Team
- **Emergency**: Direct database access via Mnemosyne

## VERSION INFORMATION

- **Version**: 2.0 (Post-Architectural Refactor)
- **Status**: Production Ready
- **Last Validated**: #{Time.now.strftime('%Y-%m-%d %H:%M:%S %Z')}

---

*"As above, so below. As within, so without." - Hermetic Principle of Correspondence*
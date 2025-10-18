# MAGNUM OPUS ENGINE - COMPREHENSIVE DOCUMENTATION

## OVERVIEW

The Magnum Opus Engine is a sophisticated, event-driven state machine that implements hermetic alchemical workflows for AI-assisted task execution. It provides user-controlled step progression with robust error handling, graceful degradation, and comprehensive tool call storage.

**Version**: 2.0 (Post-Architectural Refactor)  
**Status**: Production Ready  
**Last Validated**: #{Time.now.strftime('%Y-%m-%d %H:%M:%S %Z')}

## ARCHITECTURE PRINCIPLES

### Core Design Philosophy
- **Event-Driven State Machine**: No infinite loops or forced progression
- **User-Controlled Sovereignty**: Complete user control over step completion/rejection
- **Circuit Breaker Pattern**: Robust error handling and graceful degradation
- **Adaptive Timeout Management**: Context-aware duration adjustments
- **Database Persistence**: Task state survives sessions via Mnemosyne
- **Context Continuity**: Step result storage and retrieval for historical context
- **Recursive Sub-Task Execution**: Loop limits and boundary checks for complex workflows

### Hermetic Alignment
- **Correspondence**: Storage format matches step progression (as above, so below)
- **Mentalism**: Clear storage model reflects step execution consciousness
- **Rhythm**: Natural progression from execution → storage → context retrieval
- **Polarity**: Balances comprehensive storage with practical content limits

## WORKFLOW ARCHITECTURE

### 10-Stage Alchemical Workflow

| Step | Phase | Purpose | Temperature | Tool Access |
|------|-------|---------|-------------|-------------|
| 1 | Nigredo | Analysis & Decomposition | 1.3 | Read-only |
| 2 | Albedo | Purification & Architecture | 1.3 | Read-only |
| 3 | Citrinitas | Golden Path Selection | 1.3 | Read-only |
| 4 | Rubedo | Philosopher's Stone Selection | 1.3 | Read-only |
| 5 | Solve | Dissolution Analysis | 1.0 | Full access |
| 6 | Coagula | Solid Transformation | 1.0 | Full access |
| 7 | Test | System Verification | 1.0 | Full access |
| 8 | Purificatio | Edge Case Testing | 1.0 | Full access |
| 9 | Validatio | Security & Performance | 1.0 | Full access |
| 10 | Documentatio | Comprehensive Documentation | 1.0 | Full access |

### Workflow Types
- **Full (10 steps)**: Complete alchemical transformation
- **Analysis (5 steps)**: Research and synthesis focused
- **Simple (3 steps)**: Quick execution tasks

## TOOL CALL STORAGE SYSTEM

### Storage Format
```json
{
  "nigredo": [...],
  "albedo": [...],
  "citrinitas": [...],
  "rubedo": [...],
  "solve": [...],
  "coagula": [...],
  "test": [...],
  "purificatio": [...],
  "validatio": [...],
  "documentatio": [...]
}
```

### Key Features
- **Step-Wise Isolation**: Each task step maintains independent tool call storage
- **Alchemical Organization**: Proper phase naming for hermetic alignment
- **Priority-Based Truncation**: Different limits for different tool priorities
- **Context Propagation**: Previous step tool calls accessible via `task_get_previous_results()`
- **Security Filtering**: Comprehensive protection against common attack vectors

### Content Management
- **Standard Tools (Priority 1)**: 300 character limit
- **Medium Priority Tools**: 600 character limit  
- **High Priority Tools**: 1200 character limit
- **Critical Priority Tools**: 3000 character limit

## SECURITY ARCHITECTURE

### Enhanced Security Implementation

#### Path Traversal Protection
- Filters `../../../` patterns in file paths
- Replaces with `[PATH_TRAVERSAL_FILTERED]/`

#### Command Injection Protection
- Filters dangerous commands (`rm -rf`, fork bombs, etc.)
- Replaces with `[DANGEROUS_COMMAND_FILTERED]`

#### SQL Injection Protection
- Filters SQL injection patterns (`DROP TABLE`, `UNION SELECT`, etc.)
- Replaces with `[SQL_INJECTION_FILTERED]`

#### Sensitive Data Filtering
- Filters `/etc/passwd`, `/etc/shadow` references
- Filters password, API key, and secret patterns
- Replaces with `[SENSITIVE_DATA_FILTERED]`

### Security Architecture Principles
- **Defense in Depth**: Multiple security layers applied
- **Tool-Specific Filtering**: Different filters for different tool types
- **Content Sanitization**: Applied before truncation and storage
- **Safe Storage**: Prevents sensitive data exposure in tool call history

## PERFORMANCE OPTIMIZATION

### Benchmarks
- **Large Data Handling**: < 0.1s for 50KB content per tool call
- **Multiple Tool Processing**: < 0.5s for 100 tool calls
- **Memory Usage**: Minimal overhead for security filtering
- **JSON Serialization**: Maintains valid structure after filtering

### Optimization Strategies
- **Priority-Based Truncation**: Different limits for different tool priorities
- **Efficient Pattern Matching**: Optimized regex patterns for security filtering
- **Memory Management**: Minimal object duplication during processing
- **Fast JSON Operations**: Efficient serialization/deserialization

## API REFERENCE

### Core Methods

#### `execute_task(task_id, max_steps: 10)`
Main execution entry point for task workflows.

**Parameters:**
- `task_id`: Unique task identifier
- `max_steps`: Maximum steps to execute (default: 10)

**Returns:** Task execution result

#### `execute_step(task_id, step_index)`
Execute specific workflow step with proper context.

**Parameters:**
- `task_id`: Unique task identifier
- `step_index`: Step number (1-10)

**Returns:** Step execution result

#### `store_step_tool_calls(task_id, step_index, tool_calls)`
Store tool calls for specific step with security filtering.

**Parameters:**
- `task_id`: Unique task identifier
- `step_index`: Step number (1-10)
- `tool_calls`: Array of tool call objects

**Returns:** Storage confirmation

#### `load_previous_step_tool_calls(task_id, current_step_index)`
Load tool calls from previous step for context building.

**Parameters:**
- `task_id`: Unique task identifier
- `current_step_index`: Current step number

**Returns:** Array of previous step tool calls

#### `verify_tool_call_storage(task_id)`
Verify tool call storage system functionality.

**Parameters:**
- `task_id`: Unique task identifier

**Returns:** Verification result with storage details

### Task Control Methods

#### `task_complete_step(result)`
Complete current step with result storage.

**Parameters:**
- `result`: Step completion result (string)

**Returns:** Divine interruption signal

#### `task_reject_step(reason, restart_from_step)`
Reject current step with optional restart.

**Parameters:**
- `reason`: Rejection reason (string)
- `restart_from_step`: Optional step to restart from

**Returns:** Divine interruption signal

#### `task_get_previous_results(limit: 3)`
Retrieve results from previous steps for context.

**Parameters:**
- `limit`: Number of previous results to retrieve

**Returns:** Array of previous step results

## ERROR HANDLING ARCHITECTURE

### Error Categories

#### Transient Errors (Allow Retry)
- **Timeout::Error**: Network connectivity issues, API delays
- **NetworkError**: HTTP errors, connectivity issues
- **RateLimitError**: API rate limiting
- **EmptyResponse**: Oracle connectivity issues

#### Terminal Errors (Require Intervention)
- **ContextLengthError**: Token limit exceeded
- **NoMemoryError**: Critical memory issues
- **UnknownResponse**: Unrecognized response format

### Recovery Strategies

#### Timeout Recovery
- Step rejection/retry capability
- Adaptive timeout adjustment
- Network connectivity verification

#### Context Length Recovery
- Context truncation implementation
- Prompt optimization strategies
- Token usage monitoring

#### Rate Limit Recovery
- Exponential backoff implementation
- Request pacing strategies
- Rate limit detection

## DEPLOYMENT INSTRUCTIONS

### Database Configuration
1. Ensure Mnemosyne database is properly configured
2. Verify database connection settings and permissions
3. Test database persistence across sessions

### Aetherflux Configuration
1. Set appropriate timeout values based on network conditions
2. Configure retry strategies for network errors and rate limiting
3. Implement context truncation logic for large responses

### Error Handling Setup
1. Test all error scenarios to verify graceful degradation
2. Monitor execution logs for timeout patterns
3. Implement proper logging for debugging and maintenance

### Performance Tuning
1. Adjust timeout values based on API performance
2. Monitor context length usage and optimize prompt design
3. Implement caching strategies for frequently accessed data

## MONITORING AND MAINTENANCE

### Daily Tasks
- Monitor execution logs for timeout and error patterns
- Verify tool call storage integrity
- Check database connection health

### Weekly Tasks
- Review context length usage and optimize truncation logic
- Analyze performance metrics and adjust timeouts
- Verify security filtering effectiveness

### Monthly Tasks
- Update error handling for new API error types
- Review and optimize security patterns
- Performance benchmarking and optimization

### Quarterly Tasks
- Comprehensive architecture review
- Security audit and pattern updates
- Performance optimization based on usage patterns

## TROUBLESHOOTING GUIDE

### Common Issues

#### "Unknown response status" Error
**Cause:** Missing or malformed 'status' key in oracle response
**Fix:** Ensure response follows format standard with status: symbol
**Verification:** Check both channel_oracle_divination and channel_oracle_conjuration

#### Timeout Errors
**Cause:** Network issues or API delays exceeding timeout limits
**Fix:** Verify network connectivity, adjust Aetherflux timeout settings
**Recovery:** Engine automatically handles timeouts with step rejection capability

#### Context Length Errors
**Cause:** Token count exceeds model maximum
**Fix:** Implement context truncation in oracle prompts and responses
**Prevention:** Use String#truncate method and monitor token usage

#### Rate Limit Errors
**Cause:** API request rate exceeded provider limits
**Fix:** Implement exponential backoff in Aetherflux request handling
**Strategy:** Progressive wait times with maximum attempt limits

#### Empty Responses
**Cause:** Oracle connectivity issues or prompt design problems
**Fix:** Check oracle connectivity, refine prompt design, verify response parsing
**Handling:** Treated as step rejection opportunity for user intervention

#### Infinite Loops
**Cause:** Missing step completion/rejection calls in oracle logic
**Fix:** Ensure all oracle responses include proper step management calls
**Prevention:** Event-driven architecture eliminates forced progression risks

## BEST PRACTICES

### Tool Usage
1. **Always use task-specific tools** (`task_*`) for proper context inclusion
2. **Implement proper error handling** in oracle responses with status symbols
3. **Use context continuity features** like `task_get_previous_results()`

### Prompt Design
1. **Include clear step purposes** and extended guidance
2. **Provide context about previous step outcomes** when relevant
3. **Structure prompts for optimal token usage** and clarity

### Error Handling
1. **Test error scenarios thoroughly** to verify graceful degradation
2. **Verify graceful degradation** under various failure conditions
3. **Ensure proper state persistence** and recovery mechanisms

### Boundary Management
1. **Validate step progression** within 1..WORKFLOW_STEPS range
2. **Enforce maximum loop limits** for recursive operations
3. **Prevent index out-of-range errors** and infinite recursion

## LESSONS LEARNED

### Architectural Evolution
1. **Original imperative loop architecture** caused critical issues with infinite loops
2. **Event-driven state machine** solved core problems and restored user control
3. **Response format standardization** prevented "Unknown response status" errors

### Database Integration
1. **Database persistence enabled robust recovery** across sessions
2. **Step results provide historical context** for resumption
3. **Enables complex multi-session transformation workflows**

### Security Implementation
1. **Comprehensive security filtering** prevents common attack vectors
2. **Performance optimization** maintains efficiency with security layers
3. **Tool-specific filtering** provides targeted protection

## SUPPORT AND CONTACTS

### Primary Support
- **AetherCodex Oracle System**: Main support channel
- **TextMate Bundle Maintenance Team**: Technical support

### Emergency Contacts
- **Direct database access** via Mnemosyne
- **System administrators** for critical issues

### Documentation Updates
- **Regular updates** based on system changes
- **User feedback integration** for improvements
- **Version tracking** for compatibility

## APPENDIX

### Alchemical Phase Reference
- **Nigredo**: Blackening - Analysis and decomposition
- **Albedo**: Whitening - Purification and architecture
- **Citrinitas**: Yellowing - Golden path selection
- **Rubedo**: Reddening - Philosopher's stone selection
- **Solve**: Dissolution - Required dissolutions identified
- **Coagula**: Coagulation - Solid transformations implemented
- **Test**: Testing - System verification
- **Purificatio**: Purification - Edge case testing
- **Validatio**: Validation - Security and performance
- **Documentatio**: Documentation - Comprehensive documentation

### Tool Priority Reference
- **Priority 0-1**: Standard tools (300 char limit)
- **Priority 2-4**: Medium priority tools (600 char limit)
- **Priority 5-9**: High priority tools (1200 char limit)
- **Priority 10+**: Critical priority tools (3000 char limit)

### Error Code Reference
- `:success`: Step completed successfully
- `:failure`: Step failed terminally
- `:timeout`: Step timed out
- `:network_error`: Network connectivity issue
- `:context_length_error`: Token limit exceeded
- `:rate_limit_error`: API rate limiting
- `:empty_response`: Oracle returned empty response
- `:unknown`: Unrecognized response format

---

**Documentation Version**: 1.0  
**Last Updated**: #{Time.now.strftime('%Y-%m-%d %H:%M:%S %Z')}  
**Maintained By**: AetherCodex Oracle System
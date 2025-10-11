# HERMETIC MANIFEST

## PROJECT FOCUS

TextMate plugin for AI-assisted coding with hermetic principles
Primary goal: Create intuitive, powerful AI tools that enhance developer workflow

## CORE HERMETIC PRINCIPLES

mentalism: The universe is mental; all code reflects consciousness
correspondence: As above, so below; patterns repeat across scales
vibration: Nothing rests; everything moves and vibrates
polarity: Everything is dual; opposites are identical in nature
rhythm: Everything flows out and in; all things rise and fall
cause_effect: Every cause has its effect; every effect has its cause
gender: Gender is in everything; masculine and feminine principles

## HERMETIC RUBY STYLE

code_style: Clean Ruby with mystical elegance and practical functionality
naming: Meaningful, evocative names reflecting hermetic concepts
structure: Follow correspondence - patterns repeat across scales
abstraction: Embrace mentalism - code reflects clear mental models
rhythm: Create flowing, rhythmic code with natural cadence
polarity: Balance magical abstraction with practical implementation

### FUNCTIONAL PROGRAMMING

functional_purity: Embrace functional programming principles - avoid side effects, prefer pure functions
higher_order_functions: Use map, reduce, filter, each_with_object for elegant iteration
functional_composition: Compose functions using then, yield_self, and method chaining
method_chaining: Use fluent interfaces and method chaining for readable code flows
no_imperative: Absolutely no imperative loops (for, while, until) - use Enumerable methods exclusively

### CONCISENESS & CLARITY

conciseness: Eliminate verbosity through functional composition and method chaining
minimalism: Strive for maximum conciseness - fewer lines, clearer intent
no_redundant_vars: Eliminate redundant variable assignments through direct method composition
no_intermediate_vars: Avoid unnecessary intermediate variables - use method composition and chaining
no_boilerplate: Eliminate boilerplate code through metaprogramming and DSL patterns

### DEBUGGING & VISIBILITY

selective_logging: Use puts statements where helpful for debugging, especially for tool execution
argument_truncation: Always truncate logged arguments to prevent output bloat (e.g., args.to_s.truncate(100))
tool_call_visibility: Log tool calls with truncated arguments for execution visibility
error_reporting: Use HorologiumAeternum system for proper error reporting instead of console output

### HERMETIC EXECUTION DOMAIN PATTERN

hermetic_domain: Use HermeticExecutionDomain for isolated tool execution with proper error handling
domain_benefits: Provides structured error classification, automatic retry mechanisms, and execution isolation
domain_example: HermeticExecutionDomain.execute { tool.call(args) } rescue HermeticExecutionDomain::Error => e

### IDIOMATIC RUBY

idiomatic_ruby: Follow Ruby community best practices and idiomatic patterns
enumerable_patterns: Leverage Ruby's Enumerable methods for concise iteration
metaprogramming: Use judicious metaprogramming for DSL creation and pattern abstraction

## PROJECT STRUCTURE & EXECUTION

- Ruby application resides in `Support/` directory
- All ruby related execution: `cd Support && bundle exec <command>`
- Run Ruby: `bundle exec ruby <file>`
- Run RSpec: `bundle exec rspec <spec_file>`
- Run IRB: `bundle exec irb`
- _Use Rubocop_ to improve code quality. run (global) from root dir, not from support dir: `rubocop <file>`

**NOTICE: when making code changes on the running environment in this project the modules and classes are not automatically reloaded, hence when you change some code the user must restart the system manually for the changes to take effect**

## GEM MANAGEMENT

- Gemfile: `Support/Gemfile`
- Always use `bundle exec` for correct gem versions
- Install: `cd Support && bundle install`

## WORKFLOW

- Test execution from Support directory
- File paths relative to project root
- Maintain hermetic isolation through bundle usage

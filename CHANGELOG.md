# Changelog

## [0.6.0] — 2025-06-11

### Added
- **Tool execution times** — per-tool `execution_time` tracked and returned in response metadata
- **Thinking time display** — `thinking_complete` status event shows thinking duration in UI
- **Resume state support** — `Aetherflux.channel_oracle_divination` accepts `resume_state` parameter for paused/resumed divinations
- **Live observe toggle** — pair programming checkbox to disable live Hermetic updates
- **Terminal stream** — new `TerminalStream` module for terminal-based output
- **CLI entry point** — `cli.rb` for command-line oracle interaction
- **Tool execution group styling** — CSS for `.tool-execution-group`, `.tool-execution-item`, and resume button

### Changed
- **Tool display** — removed `tool_starting`/`tool_completed` status events from backend and frontend; tools now execute silently with results shown in final answer
- **Oracle revelation** — AI text now logged as `'system'` class instead of `'ai'` class for consistent styling
- **Completed events** — changed from `'status'` to `'system'` class
- **Answer handler** — now renders `result.html` or `result.answer` directly instead of `data.content`
- **Log method** — supports DOM element appending, renamed `is_near` to `is_near_bottom`
- **Oracle divination** — refactored to pass `resume_state` through to `Oracle.divination`
- **Response structure** — added `tool_execution_times` array to response hash

### Fixed
- **Scroll behavior** — corrected variable name in `@log` method for scroll detection

### Removed
- **Mnemosyne** — old `mnemosyne.rb` deleted (972 lines)
- **Test file** — `test_fim.rb` removed

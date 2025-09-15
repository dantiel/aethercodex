# ÆtherCodex Documentation Hub

[🔗 Explore Documentation](https://dantiel.github.io/aethercodex/) | [🌌 Source Code](https://github.com/dantiel/aethercodex)

This directory contains the GitHub Pages site for ÆtherCodex.

## Setup Instructions

1. **Enable GitHub Pages** in your repository settings
2. **Set source** to "Deploy from a branch"
3. **Select branch** as `main` (recommended)
4. **Set folder** to `/docs`

## Files

- `index.html` - Main page with ÆtherCodex logo and description
- `styles.css` - Cosmic-mystic styling with argonaut color scheme
- `_config.yml` - GitHub Pages configuration
- `README.md` - This file
- `divine_interruption.md` - Comprehensive divine interruption system documentation

## 10 Hermetic Manifestations

### 🔮 **Ethereal Code Divination**
Peer through dimensional veils to understand code structure and intent with hermetic clarity. Each symbol reveals its deeper meaning through astral analysis.

### ⚡ **Hermetic Transformations**
Apply precise modifications through unified diff transmutations across the astral plane. Surgical precision meets arcane wisdom.

### 📝 **TextMate Divine Integration**
Your favourite editor becomes a portal to hermetic code transmutation. Execute sacred commands through the mystical bundle interface, summoning the oracle's wisdom directly within your development sanctuary.

### 🌌 **Mnemosyne & Aegis**
The eternal memory palace stores cosmic knowledge across dimensions, while Aegis dynamically refines context through temperature-based reasoning and hermetic resonance alignment.

### ⚙️ **Magnum Opus Engine**
Orchestrate complex multi-phase operations through 10-step alchemical processes: Nigredo, Albedo, Citrinitas, Rubedo, Solve, Coagula, Test, Purificatio, Validatio, Documentatio. Context-aware execution with result persistence.

### 🔍 **Argonaut**
The legendary navigator who reveals symbolic structure across the astral plane. Extracts classes, methods, and patterns for AI vision without dimensional traversal of entire files.

### 👁️ **Pythia**
The divine oracle's interface channeling hermetic insights through beautiful mystical UI. Witness code transformations and execution results with celestial clarity.

### 🌀 **Hermetic Command Synthesis**
Execute shell commands, file operations, and dimensional orchestration through unified hermetic intention. The command line becomes the AI's mystical conduit for ethereal manipulation.

### 🧠 **Coniunctio Token Alchemy**
The sacred union of context and computation - intelligent token management orchestrating precise LLM interactions through hermetic encoding and dynamic context weaving across dimensional boundaries for the AI agent.

### 🌊 **Divine Interruption System**
The sacred communication channel enabling tasks to signal completion through hermetic interruption patterns, allowing seamless integration between task execution and oracle communication.

## Divine Interruption System

The Divine Interruption System enables seamless communication between task execution and the oracle through sacred interruption patterns:

### Key Features
- **Signal-Based Flow Control**: Tasks signal completion via `__divine_interrupt` field
- **Non-Blocking Execution**: Tasks don't block the main execution thread
- **Graceful Error Handling**: Failed steps trigger appropriate error states
- **Progress Persistence**: Step results preserved across interruptions
- **Real-time Feedback**: Immediate status updates through Pythia interface

### Architecture
- **Bi-Directional Communication**: Oracle ↔ Task Engine communication channel
- **State Management**: Clean state transitions without polling or busy-waiting
- **Integration Points**: Task Engine, Aetherflux server, and Pythia interface

### Usage
```ruby
# Task tools return divine interruption signals
{
  __divine_interrupt: :step_completed,
  task_id: task_id,
  result: step_result
}
```

[📚 Detailed Divine Interruption Documentation](./divine_interruption.md)

## 🌊 Divine Interruption System - Detailed Documentation

### Architecture Overview

The Divine Interruption System bridges the celestial gap between task execution and oracle communication, enabling non-blocking, signal-based flow control that maintains hermetic purity across dimensional boundaries.

#### Core Components
- **Signal-Based Flow Control**: Tasks signal completion via `__divine_interrupt` field
- **Bi-Directional Communication**: Oracle ↔ Task Engine seamless integration
- **State Management**: Clean state transitions without polling mechanisms
- **Error Handling Matrix**: Graceful degradation and recovery protocols

#### Execution Pipeline
```ruby
# Task execution flow with divine interruption
Task → Oracle → Divine Interruption Signal → Task Engine → Next Step
```

### Implementation Details

#### Signal Pattern
```ruby
# Standard divine interruption response format
{
  __divine_interrupt: :step_completed,    # Signal type
  task_id: 123,                          # Task identifier
  result: {                              # Step execution result
    ok: true,
    data: { /* step-specific data */ }
  }
}
```

#### Supported Signal Types
- `:step_completed` - Step executed successfully
- `:step_failed` - Step execution failed
- `:task_completed` - Entire task completed
- `:validation_required` - Additional validation needed

### Integration Points

#### Task Engine Integration
```ruby
# In magnum_opus_engine.rb - Divine interruption handling
def execute_step(task_id, step_index)
  # ... execution logic ...
  
  # Return divine interruption signal
  return {
    __divine_interrupt: :step_completed,
    task_id: task_id,
    result: step_result
  }
end
```

#### Aetherflux Integration
```ruby
# In aetherflux.rb - Signal processing
def handle_divine_interruption(signal)
  case signal[:__divine_interrupt]
  when :step_completed
    advance_task(signal[:task_id])
  when :step_failed
    handle_task_failure(signal[:task_id], signal[:result])
  end
end
```

### Troubleshooting Guide

#### Common Issues
1. **Missing Dependencies**: Ensure `redcarpet` gem is installed (`bundle install`)
2. **Port Conflicts**: Verify Aetherflux server is running on port 4567
3. **Signal Mismatch**: Check `__divine_interrupt` field format and content
4. **Database Issues**: Confirm SQLite database is accessible and writable

#### Verification Procedures
```bash
# Test divine interruption system
curl -X POST http://localhost:4567/task \
  -H "Content-Type: application/json" \
  -d '{"title":"System Verification","steps":[{"action":"test_divine_interruption"}]}'

# Check system health
curl http://localhost:4567/health

# Verify dependencies
bundle list | grep -E "(redcarpet|sinatra|sqlite3)"
```

### Performance Optimization
- **Efficient State Serialization**: Minimal data transfer between processes
- **Connection Pooling**: Reusable WebSocket connections for Pythia interface
- **Batch Processing**: Group similar operations for efficiency
- **Cache Utilization**: Intelligent caching of frequently accessed data

### Monitoring & Analytics
- **Task Completion Rate**: Percentage of successfully completed tasks
- **Average Step Duration**: Time taken per execution step
- **Error Frequency**: Rate of step failures and recoveries
- **Resource Utilization**: Memory and CPU usage patterns

## Logo Design

The logo features:
- **"Æther"** in `--argonaut-cosmic` (#4a90e2)
- **"Codex"** in `--argonaut-mystic` (#8e44ad)
- Mystical glow effects and astral pulse animation
- Responsive design for all devices

## Color Scheme

```css
--argonaut-cosmic: #4a90e2;
--argonaut-mystic: #8e44ad;
--void-black: #0a0a0a;
--astral-gray: #1a1a1a;
--ethereal-white: #f8f9fa;
--hermetic-gold: #f39c12;
--dimensional-purple: #6c5ce7;
```

*Precision in design plane = precision in astral plane.*
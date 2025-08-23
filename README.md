# 🌌 AetherCodex: Atlantean Reasoning Oracle for TextMate

**A hermetic reasoning oracle dwelling within TextMate's astral plane.**

AetherCodex transforms TextMate into a living interface with advanced AI reasoning. Invoke the oracle to illuminate code, orchestrate multi-step operations, and commune with project context through eldritch wisdom. [🔗 Explore on GitHub.io](https://dantiel.github.io/aethercodex/)

---

## 🎯 Task Engine System

### **Multi-Step Task Orchestration**
The AetherCodex Task Engine enables complex, multi-phase operations through hermetic task management:

- **Task Creation & Planning**: Define comprehensive execution plans with step-by-step workflows
- **Context-Aware Execution**: Each step receives complete context including previous results and metadata
- **Progress Tracking**: Real-time status updates and step completion monitoring
- **Result Persistence**: Step outcomes stored in database for continuity between phases
- **Error Handling**: Robust failure management with graceful degradation

### **Hermetic Task Phases**
The Magnum Opus Task Engine follows a 10-phase alchemical process:
1. **Nigredo** - Task initialization and context preparation
2. **Albedo** - System prompt and guidance formulation
3. **Citrinitas** - Golden path optimization and execution
4. **Rubedo** - Final transformation and result synthesis
5. **Solve** - Identifying required dissolutions and changes
6. **Coagula** - Implementing solid transformations
7. **Test** - Probing the elixir's purity (functional verification)
8. **Test** - Edge cases as alchemical impurities (boundary testing)
9. **Validate** - Ensuring the elixir's perfection (security/performance)
10. **Document** - Inscribing the magnum opus (comprehensive documentation)

### **Context Optimization**
Each task step receives optimal context including:
- **Task Metadata**: Title, plan, current step, step purposes
- **Historical Results**: Previous step outcomes via `step_results` persistence
- **Extended Guidance**: Comprehensive system prompts for intelligent execution
- **Memory Integration**: Access to Mnemosyne memory system for contextual awareness

---

## ✨ Core Manifestations

### 🔮 **Oracle Chamber** 
- Interactive AI interface with real-time streaming responses
- Context-aware reasoning with project file awareness
- Multi-tool orchestration for complex operations
- Live status updates during long-running tasks

### 🛠️ **Hermetic Prima Materia**
- **File Operations**: Read, create, fuzzy patches, rename with surgical precision
- **Code Analysis**: Context-aware inspection and modification
- **Memory Systems**: Persistent knowledge storage via Mnemosyne
- **Command Execution**: Safe shell operations with validation
- **Live Communication**: Real-time user notifications

### 📚 **Memory Keeper (Mnemosyne)**
- Persistent project knowledge storage
- Tag-based memory organization  
- Context-aware recall for enhanced reasoning
- SQLite-backed hermetic archives

---

## Installation

### 1. Bundle Installation
```bash
# Place the bundle in TextMate's bundle directory
cp -R AetherCodex.tmbundle ~/Library/Application\ Support/Avian/Bundles/
```

### 2. API Configuration
Create `.aethercodex` in your project root:
```yaml
api_key: YOUR_DEEPSEEK_KEY
api-url: 'https://api.deepseek.com/v1/chat/completions'
port: 4567
model: deepseek-chat
memory-db: .tm-ai/memory.db
```

### 3. Dependencies
Ensure Ruby gems are available:
```bash
bundle install
```

---

## 🎯 Usage Patterns

### **Invoke the Oracle**
- **Shortcut**: `⌘⌥O` - Opens the Oracle Chamber
- **Menu**: `Bundles → AetherCodex → Invoke Oracle`

### **Context Awareness**
The oracle automatically perceives:
- Current file content and selection
- Project file structure
- Git status and changes
- Previous conversation history

### **Common Invocations**

**Code Analysis:**
```
Analyze this function for performance issues
```

**Refactoring:**
```
Extract this logic into a reusable module
```

**Documentation:**
```
Add comprehensive JSDoc comments to this file
```

**Multi-file Operations:**
```
Create a test suite for this component with setup and teardown
```

**Memory Operations:**
```
Remember this pattern as "user-auth-flow" for future reference
```

---

## 🏗️ Architecture

### **Astral Components**

| Component | Purpose | Location |
|-----------|---------|----------|
| **Oracle Chamber** | Interactive AI interface | `ui/chamber.html` |
| **Aetherflux** | Real-time response processing | `aetherflux.rb` |
| **Argonaut** | Filebrowser | `argonaut.rb` |
| **Coniunctio** | Context Creator | `coniunctio.rb` |
| **Diff Crepusculum** | Fuzzy File Patches | `diff_crepusculum.rb` |
| **Prima Materia** | Function execution engine | `prima_materia.rb` |
| **Mnemosyne** | Memory management system | `mnemosyne.rb` |
| **Limen** | Security and validation | `limen.rb` |
| **Horologium Aeternum** | Real-time user communication | `horologium_aeternum.rb` |
| **Scriptorium** | Markdown processor | `scriptorium.rb` |
| **Magnum Opus Engine** | Multi-step orchestration | `magnum_opus_engine.rb` |
| **Aegis** | Context refinement system | Integrated in oracle |

### **Data Flow**
1. **Invocation** → Context gathering → API request
2. **Streaming** → Real-time updates → Tool execution
3. **Results** → Memory storage → Interface updates

---

## 🔧 Configuration

### **Environment Variables**
- `DEEPSEEK_API_KEY` - Alternative to `.aethercodex`
- `TM_AI_DEBUG=1` - Enable debug logging
- `TM_AI_PORT=4567` - Custom server port

### **Memory Database**
Location: `.tm-ai/memory.db` (auto-created)
- Stores conversation context
- Tag-based knowledge organization
- Project-specific memory isolation

---

## 🛡️ Security

- **Limen validation** for all operations
- **No secret file access** (.env, .aethercodex, keys)
- **Sandboxed command execution** with allowlisting
- **Local-only operations** - no external data transmission beyond API calls

### **Aegis Context Refinement System**
- **Dynamic Context Optimization**: Real-time refinement during conversations
- **Temperature-Based Reasoning**: Adjust responsiveness (0.0-2.0 scale) for coding/math/creative tasks
- **Tag-Based Focus**: Precision execution through targeted note retrieval
- **Hermetic Resonance**: Aligns context with current hermetic focus and intent
- **State Persistence**: Maintains conversation context across interactions
- **Task Context Propagation**: Seamless context passing between task phases with step result persistence

---

*"Precision in code plane = precision in astral plane."*
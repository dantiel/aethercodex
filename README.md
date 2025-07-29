# AetherCodex: Atlantean Reasoning Oracle for TextMate

**A hermetic reasoning oracle dwelling within TextMate's astral plane.**

AetherCodex transforms TextMate into a living interface with advanced AI reasoning. Invoke the oracle to illuminate code, orchestrate multi-step operations, and commune with project context through eldritch wisdom.

---

## ✨ Core Manifestations

### 🔮 **Oracle Chamber** 
- Interactive AI interface with real-time streaming responses
- Context-aware reasoning with project file awareness
- Multi-tool orchestration for complex operations
- Live status updates during long-running tasks

### 🛠️ **Hermetic Toolbox**
- **File Operations**: Read, create, patch, rename with surgical precision
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
Create `.deepseekrc` in your project root:
```yaml
api_key: YOUR_DEEPSEEK_KEY
port: 4567
model: reasoning-1
memory_db: .tm-ai/memory.db
```

### 3. Dependencies
Ensure Ruby gems are available:
```bash
gem install sqlite3 sinatra httparty
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
| **Streaming Handler** | Real-time response processing | `streaming_handler.rb` |
| **Toolbox** | Function execution engine | `toolbox.rb` |
| **Mnemosyne** | Memory management system | `mnemosyne.rb` |
| **Gatekeeper** | Security and validation | `gatekeeper.rb` |
| **Live Status** | Real-time user communication | `live_status.rb` |

### **Data Flow**
1. **Invocation** → Context gathering → API request
2. **Streaming** → Real-time updates → Tool execution
3. **Results** → Memory storage → Interface updates

---

## 🔧 Configuration

### **Environment Variables**
- `DEEPSEEK_API_KEY` - Alternative to `.deepseekrc`
- `TM_AI_DEBUG=1` - Enable debug logging
- `TM_AI_PORT=4567` - Custom server port

### **Memory Database**
Location: `.tm-ai/memory.db` (auto-created)
- Stores conversation context
- Tag-based knowledge organization
- Project-specific memory isolation

---

## 🛡️ Security

- **Gatekeeper validation** for all operations
- **No secret file access** (.env, .deepseekrc, keys)
- **Sandboxed command execution** with allowlisting
- **Local-only operations** - no external data transmission beyond API calls

---

*"Precision in code plane = precision in astral plane."*
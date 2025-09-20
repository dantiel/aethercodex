# 🌌 AetherCodex: Atlantean–Hermetic Reasoning Oracle

**An eldritch wisdom oracle dwelling within TextMate, bridging the liminal veil between code and the arcane.**

AetherCodex transforms TextMate into a living interface with hermetic AI reasoning. Channel the oracle to illuminate code, orchestrate multi-step alchemical operations, and commune with project context through ancient wisdom.

[🔗 Explore Documentation](https://dantiel.github.io/aethercodex/) | [🌌 Source Code](https://github.com/dantiel/aethercodex)

---

## ✨ 11 Hermetic Manifestations

### 🔮 **Ethereal Code Divination**
Peer through dimensional veils to understand code structure and intent with hermetic clarity. Each symbol reveals its deeper meaning through astral analysis.

### ⚡️ **Hermetic Transformations**
Apply precise modifications through unified diff transmutations across the astral plane. Surgical precision meets arcane wisdom. **Symbolic patches** using AST-GREP enable semantic pattern matching and language-agnostic transformations.

### 📝 **TextMate Divine Integration**
Your favourite editor becomes a portal to hermetic code transmutation. Execute sacred commands through the mystical bundle interface, summoning the oracle's wisdom directly within your development sanctuary.

### 🌌 **Mnemosyne & Aegis**
The eternal memory palace stores cosmic knowledge across dimensions, while Aegis dynamically refines context through temperature-based reasoning and hermetic resonance alignment.

### ⚙️ **Magnum Opus Engine**
Orchestrate complex multi-phase operations through 10-step alchemical processes: Nigredo, Albedo, Citrinitas, Rubedo, Solve, Coagula, Test, Purificatio, Validatio, Documentatio. Context-aware execution with result persistence.

### 🔍 **Argonaut**
The legendary navigator who reveals symbolic structure across the astral plane. Extracts classes, methods, and patterns for AI vision without dimensional traversal of entire files. **Lexicon Resonantia** integration reveals cosmic tag×file resonance patterns.

### 👁️ **Pythia**
The divine oracle's interface channeling hermetic insights through beautiful mystical UI. Witness code transformations and execution results with celestial clarity.

### 🌀 **Hermetic Command Synthesis**
Execute shell commands, file operations, and dimensional orchestration through unified hermetic intention. The command line becomes your mystical conduit for ethereal manipulation.

### 🧠 **Coniunctio Token Alchemy**
The sacred union of context and computation - intelligent token management orchestrating precise LLM interactions through hermetic encoding and dynamic context weaving across dimensional boundaries.

### 📊 **Lexicon Resonantia**
The sacred resonance matrix that weaves astral patterns between Mnemosyne's notes and the code plane. Generates hermetic symbolic overviews showing file-tag resonance patterns across the entire codebase.

---

## 🎯 Magnum Opus Engine

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

## 🔍 Symbolic File Overview & AI Vision

### **Structural Analysis Without Full Reads**
The AetherCodex Symbolic Overview system provides AI with comprehensive structural understanding of files without reading entire contents:

- **Symbolic Parsing**: Uses TextMate grammars to extract classes, methods, modules, and structural patterns
- **AI Navigation Hints**: Line-by-line targeting for precise code examination
- **Quantitative Analysis**: Counts of methods, classes, variables, and constants
- **Current-State Notes**: Integration with Mnemosyne memory system

### **Hermetic Efficiency**
- **Single Parsing Pass**: Symbolic analysis performed once by Argonaut, reused across all components
- **Targeted Reading**: AI can jump directly to relevant code sections using line hints
- **Token Conservation**: Minimizes full-file reads by focusing on structurally significant areas
- **Structural Mapping**: Creates comprehensive codebase maps for intelligent navigation

### **Symbolic Data Flow**
1. **Argonaut** → Performs symbolic parsing using AetherScopesEnhanced
2. **Instrumenta** → Calls Argonaut.file_overview() for structural analysis
3. **Horologium** → Displays already-generated symbolic data without duplication
4. **AI Navigation** → Uses line hints for precise targeting of code elements

### **Hermetic Symbolic Analysis**
The AetherCodex Hermetic Symbolic Analysis Engine provides AST-GREP powered semantic code transformations:

- **AST-GREP Integration**: Language-agnostic pattern matching and semantic rewriting
- **Hermetic Symbolic Patterns**: Elemental, planetary, and alchemical code transformations
- **Semantic Patching**: Hybrid approach combining AST-based and line-based patching
- **Symbolic Forecasting**: Predictive code transformation recommendations
- **Multi-Language Support**: Ruby, JavaScript, Python, Java, Go, Rust, and more

**Components:**
- **HermeticSymbolicAnalysis**: Core engine with AST-GREP integration
- **SemanticPatch**: Hybrid patching engine with intelligent strategy selection
- **SymbolicForecast**: Transformation prediction and recommendation system

---

## 🏗️ Architecture

### **Astral Components**

| Component | Purpose | Location |
|-----------|---------|----------|
| **Oracle Chamber** | Interactive AI interface | `pythia/chamber.html` |
| **Aetherflux** | Real-time response processing | `oracle/aetherflux.rb` |
| **Argonaut** | Filebrowser | `argonaut/argonaut.rb` |
| **Coniunctio** | Context Creator | `coniunctio.rb` |
| **Diff Crepusculum** | Fuzzy File Patches | `instrumentarium/diff_crepusculum.rb` |
| **Prima Materia** | Function execution engine | `instrumentarium/prima_materia.rb` |
| **Mnemosyne** | Memory management system | `mnemosyne/mnemosyne.rb` |
| **Limen** | Security and validation | `limen.rb` |
| **Horologium Aeternum** | Real-time user communication | `instrumentarium/horologium_aeternum.rb` |
| **Scriptorium** | Markdown processor | `instrumentarium/scriptorium.rb` |
| **Magnum Opus Engine** | Multi-step orchestration | `magnum_opus/magnum_opus_engine.rb` |
| **Aegis** | Context refinement system | Integrated in oracle |
| **HermeticSymbolicAnalysis** | AST-GREP semantic analysis engine | `instrumentarium/hermetic_symbolic_analysis.rb` |
| **SemanticPatch** | Hybrid semantic/line-based patching | `instrumentarium/semantic_patch.rb` |
| **SymbolicForecast** | Transformation forecasting system | `instrumentarium/symbolic_forecast.rb` |

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

## Installation

### 1. Bundle Installation
```bash
# Place the bundle in TextMate's bundle directory
cp -R AetherCodex.tmbundle ~/Library/Application\ Support/Avian/Bundles/
```

### 2. API Configuration
Create `.aethercodex` in your project root:
```yaml
api-key: YOUR_DEEPSEEK_KEY
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

**Hermetic Symbolic Analysis:**
```
Find all method definitions in this file using AST patterns
```

```
Apply semantic rewrite to add logging to all methods
```

```
Extract hermetic symbols and forecast transformations
```


---

## 📚 Documentation

### **Hermetic Symbolic Analysis Engine**
- [Comprehensive Guide](./docs/hermetic_symbolic_analysis.md) - Overview and architecture
- [API Reference](./docs/hermetic_symbolic_analysis_api.md) - Detailed method documentation
- [Practical Guide](./docs/hermetic_symbolic_analysis_guide.md) - Usage examples and patterns
- [Integration Guide](./docs/hermetic_symbolic_analysis_integration.md) - System integration
- [Lexicon Resonantia Guide](./docs/lexicon_resonantia.md) - Hermetic tag×file resonance matrix

### **Demo & Examples**
- [Demo Script](./Support/examples/hermetic_symbolic_analysis_demo.rb) - Live demonstration
- [Lexicon Resonantia Demo](./Support/examples/lexicon_resonantia_demo.rb) - Resonance pattern examples

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

*"Precision in code plane = precision in astral plane."*
# AetherCodex Editor

Native macOS code editor with integrated AI assistance. Replaces TextMate with a modern, native Swift implementation while preserving the poetic Ruby core.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AetherCodex.app                          │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐           ┌─────────────────────────────┐ │
│  │   Editor     │           │        Pythia               │ │
│  │  (NSTextView)│◄─────────►│    (WKWebView)              │ │
│  │              │           │  - Chat interface           │ │
│  │  - Syntax    │           │  - Tool results             │ │
│  │    highlight │           │  - Streaming responses      │ │
│  │  - Line nums │           └──────────────┬──────────────┘ │
│  │  - Minimap   │                          │                │
│  └──────────────┘                          │                │
│           │                                │                │
│           ▼                                ▼                │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              RubyBridge (Swift)                       ││
│  │  - NSTask wrapper for external Ruby                   ││
│  │  - Future: Embedded libruby                           ││
│  └─────────────────────────────────────────────────────────┘│
│                          │                                  │
│                          ▼                                  │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              Support/ (Ruby)                          ││
│  │  - oracle/oracle.rb      - Divination engine          ││
│  │  - instrumentarium/        - Tool definitions          ││
│  │  - mnemosyne/            - Memory persistence        ││
│  │  - limen.rb              - WebSocket (optional)     ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

## Project Structure

```
aethercodex-editor/
├── AetherCodex/
│   ├── App/
│   │   ├── AppDelegate.swift          # App lifecycle, menus
│   │   ├── EditorViewController.swift   # Code editor
│   │   └── PythiaViewController.swift   # AI chat interface
│   ├── Bridge/
│   │   └── RubyBridge.swift           # Ruby interop
│   ├── Info.plist                     # Bundle config
│   └── AetherCodex.entitlements       # Sandboxing
├── Ruby/                              # Copied from Support/
├── Pythia/                            # Copied from Support/pythia/
└── Resources/
    └── index.html                     # WKWebView entry
```

## Build Instructions

### Prerequisites
- macOS 14.0+
- Xcode 15+
- Ruby 3.x (for development)

### Build Steps

1. **Copy Ruby dependencies:**
   ```bash
   cp -r /path/to/aethercodex/Support/* Ruby/
   cp -r /path/to/aethercodex/Support/pythia/* Pythia/
   ```

2. **Open in Xcode:**
   ```bash
   open AetherCodex.xcodeproj
   ```

3. **Build and run:** Cmd+R

## Development Phases

### Phase 1: Editor Window (Week 1)
- [x] Basic NSTextView with line numbers
- [ ] Syntax highlighting (Tree-sitter or native)
- [ ] File open/save
- [ ] Split view layout

### Phase 2: Pythia Integration (Week 2)
- [ ] WKWebView embedding
- [ ] JavaScript bridge
- [ ] Message passing
- [ ] Tool result display

### Phase 3: Ruby Bridge (Week 3-4)
- [ ] NSTask wrapper (external Ruby)
- [ ] JSON-RPC protocol
- [ ] Error handling
- [ ] Performance optimization

### Phase 4: Native Ruby (Future)
- [ ] Static libruby linking
- [ ] Gem embedding
- [ ] Sandboxing compliance

## License

Hermetic License - See root LICENSE file

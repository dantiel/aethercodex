# AetherCodex Native Mac App — Implementation Plan

## Philosophy
Preserve the Ruby poetic core. The hermetic architecture — oracle, instrumenta, mnemosyne — remains the soul. Adapt only what's necessary for native execution.

---

## Phase 1: Editor Window Prototype (Week 1-2)

**Goal:** Local testable editor window with basic file operations

### 1.1 Xcode Project Setup
- New macOS App project (AppKit, not SwiftUI — more control)
- Deployment target: macOS 13.0 (Ventura)
- Bundle identifier: `com.dantiel.aethercodex`
- Code signing: Development certificate initially

### 1.2 Editor Core
```
Components:
├── EditorWindowController (NSWindowController)
│   ├── TextView (NSTextView with code highlighting)
│   ├── Sidebar (NSOutlineView for file tree)
│   └── Toolbar (NSToolbar with run/ai buttons)
├── Document (NSDocument subclass)
│   ├── Auto-save / versions
│   └── File wrapper support
└── Syntax Highlighting
    ├── Tree-sitter integration (or native NSTextStorage)
    └── Language detection by extension
```

### 1.3 Ruby Integration (Local Dev)
- Embed Ruby via `libruby` static linking
- Load path: `AetherCodex.app/Contents/Resources/ruby/`
- Copy `Support/` directory to Resources
- Bridge: `RubyBridge` class (Objective-C → Ruby via `ruby.h`)

```objc
// RubyBridge.h
@interface RubyBridge : NSObject
- (void)initializeRuby;
- (id)callMethod:(NSString *)method 
       onClass:(NSString *)className 
      withArgs:(NSArray *)args;
- (void)requireFile:(NSString *)path;
@end
```

### 1.4 First Milestone
- [ ] Open/save files
- [ ] Basic syntax highlighting (Ruby, JS, Coffee)
- [ ] Run Ruby code from embedded interpreter
- [ ] Load existing `oracle.rb` and call simple method

---

## Phase 2: AI Integration (Week 3-4)

**Goal:** Port the divination flow to native app

### 2.1 WebSocket Bridge
Replace `limen.rb` with native WebSocket:
- `StarlightBridge` (Objective-C WebSocket server)
- Same message format as current JSON protocol
- Frontend: Embed `pythia/` in WKWebView

```
┌─────────────────┐     WebSocket      ┌─────────────────┐
│   WKWebView     │ ◄────────────────► │  StarlightBridge│
│  (pythia UI)    │   JSON messages    │   (Objective-C) │
└─────────────────┘                    └────────┬────────┘
                                              │
                                       ┌──────┴──────┐
                                       │ RubyBridge  │
                                       │  (oracle)   │
                                       └─────────────┘
```

### 2.2 Port Critical Ruby Files
Priority order:
1. `mnemosyne.rb` — SQLite persistence (paths need sandbox adaptation)
2. `conduit.rb` — LLM API calls (add ATS exceptions for HTTP)
3. `instrumenta.rb` — Tool definitions (register with native bridge)
4. `oracle.rb` — Divination orchestration
5. `aetherflux.rb` — Streaming responses

### 2.3 Sandboxing Prep
- Replace direct file paths with Security-scoped bookmarks
- Adapt `Argonaut.project_summary` to use `NSFileCoordinator`
- Move SQLite from `~/Library/Application Support/` to app container

---

## Phase 3: Polish & Distribution (Week 5-6)

### 3.1 UI Polish
- Native macOS aesthetics (vibrancy, proper dark mode)
- Keyboard shortcuts (⌘R run, ⌘⇧A ask AI)
- Touch Bar support
- Window restoration

### 3.2 Code Signing & Notarization
- Developer ID certificate
- `codesign --deep --force --verify`
- `xcrun notarytool submit`
- Staple: `xcrun stapler staple`

### 3.3 Distribution
- DMG with drag-drop install
- Sparkle framework for updates
- Website with download

---

## Phase 4: App Store (Future)

**Blockers to resolve:**
- [ ] Sandboxing: Replace `NSTask` calls with XPC services
- [ ] Ruby embedding: Must be fully static, no external gems
- [ ] Entitlements: `com.apple.security.temporary-exception.files.home-path.read-write`

---

## File Structure

```
AetherCodex.app/
├── Contents/
│   ├── MacOS/
│   │   └── AetherCodex          # Swift/Obj-C main
│   ├── Resources/
│   │   ├── ruby/
│   │   │   └── lib/             # Embedded Ruby stdlib
│   │   ├── Support/             # Copied from TextMate bundle
│   │   │   ├── oracle/
│   │   │   ├── instrumentarium/
│   │   │   ├── mnemosyne/
│   │   │   └── pythia/          # Frontend assets
│   │   └── gems/                # Bundled Ruby gems
│   └── Frameworks/
│       └── Ruby.framework       # Static Ruby build
```

---

## Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| UI Framework | AppKit + WKWebView | Full control, pythia reuse |
| Ruby Strategy | Static embed + gem bundling | Preserve poetic core |
| Persistence | SQLite (sandboxed) | mnemosyne compatibility |
| AI Bridge | Native WebSocket | Same protocol, native speed |
| Distribution | Notarized first | Faster iteration than App Store |

---

## Immediate Next Steps

1. **Create Xcode project** — `AetherCodex.xcodeproj`
2. **Build Ruby static** — `ruby-build` with `--static` flags
3. **Hello Ruby** — Call `puts "Hello from embedded Ruby"` from native code
4. **Editor scaffold** — NSTextView with line numbers

---

*The Ruby soul persists. The vessel becomes native.*

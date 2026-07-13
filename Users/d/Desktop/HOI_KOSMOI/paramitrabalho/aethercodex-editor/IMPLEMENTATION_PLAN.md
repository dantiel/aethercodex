# ÆtherCodex Editor — Glass-Native Implementation Plan

## Design Philosophy

**Every surface translucent. Every panel frosted. No flat colors.**

Apple's HIG materials replace all opaque backgrounds. The window becomes a single cohesive glass envelope — Finder-style sidebar blur, editor surface with subtle frost, and Pythia as an ever-present card flip behind every view.

> *"The source lies open, yet the veil remains."*

---

## Core UX Concept

### The Editor is the Center

The app has one primary surface: the **editor window**. Everything else orbits it.

### File Browser — Two Modes (Settings Toggle)

| Mode | Behavior | Implementation |
|---|---|---|
| **Attached** | Sidebar within the TabView, shares window space, content pushes/resizes | `TabView` + `.tabViewStyle(.sidebarAdaptable)` |
| **Detached** | Free-floating panel, non-overlapping, independently positionable | `NSPanel` or secondary `WindowGroup` |

Toggle in Settings → takes effect immediately. The sidebarAdaptable TabView gives us both for free — macOS manages collapse, icon-only mode, and the toggle button natively.

### Pythia — The Omnipresent Veil

Pythia is **not** a tab, not a split column, not a panel. She is a **full-size sheet** that flips over the editor like turning a card:

```
┌─────────────────┐       ┌─────────────────┐
│                 │       │                 │
│    EDITOR       │  →⟳→  │    PYTHIA       │
│  (front card)   │ FLIP  │  (back card)    │
│                 │       │                 │
└─────────────────┘       └─────────────────┘
```

- **Card flip animation** — 3D rotation `.rotation3DEffect` with spring
- **Takes full editor size** — no squeeze, no split; the editor gives way entirely
- **Omnipresent** — Pythia is a singleton. Any window, any tab, any context can summon her. She follows like the æther itself.
- **Dismissible** — flip back or ⌘W; editor returns exactly as it was
- **Extensible** — future tools can also occupy the flip side (terminal, debugger, diff viewer)

```swift
// Conceptual — any view can summon Pythia
@Environment(\.summonPythia) var summonPythia

Button("Ask Pythia") { summonPythia() }
// → editor flips → Pythia appears full-size → dismiss → editor flips back
```

She is a **modal overlay in spirit** but a **card flip in form** — present, watching, one turn away.

---

## File Structure

```
AetherCodex/
├── App/                              # ✅ Active (SwiftUI glass-native)
│   ├── AetherCodexApp.swift          # @main, WindowGroup, .commands
│   ├── AppDelegate.swift             # NSApplicationDelegateAdaptor (Ruby init)
│   ├── RootView.swift                # TabView(.sidebarAdaptable) — Files | Editor only
│   ├── DocumentManager.swift         # @ObservableObject file state
│   ├── EditorView.swift              # CodeEditor NSViewRepresentable + gutter
│   ├── FileBrowserView.swift         # Recursive pure-SwiftUI tree (sidebar or detached)
│   ├── PythiaSheet.swift             # Full-overlay card-flip sheet, omnipresent singleton
│   ├── PythiaView.swift              # Pure SwiftUI chat with AttributedString
│   ├── OracleViewModel.swift         # @ObservableObject chat state
│   └── SettingsView.swift            # File browser mode toggle, preferences
│
├── Bridge/
│   └── RubyBridge.swift              # ✅ C Ruby FFI bridge
│
├── Resources/
│   ├── Info.plist
│   └── AetherCodex.entitlements
│
├── Editor/                           # 🗑️ Legacy AppKit — delete after migration
├── AI/                               # 🗑️ Legacy AppKit
├── Pythia/                           # 🗑️ Legacy AppKit
└── Ruby/                             # 🗑️ Duplicate RubyBridge
```

---

## Phase 0: Glass Migration + Core UX 🔄 IN PROGRESS

### 0.1 Window Envelope
```swift
WindowGroup {
    RootView()
        .containerBackground(.ultraThickMaterial, for: .window)
}
.windowStyle(.hiddenTitleBar)
.windowToolbarStyle(.unifiedCompact)
```

### 0.2 RootView — TabView with Sidebar (Files | Editor only)
No Oracle tab. The TabView switches between Files sidebar and the Editor. Pythia is not a tab — she is the flip side.

```swift
TabView(selection: $selectedTab) {
    FileBrowserView(documentManager: doc)
        .tabItem { Label("Files", systemImage: "folder") }
        .tag(Tab.files)

    EditorView(text: $doc.content)
        .tabItem { Label("Editor", systemImage: "doc.text") }
        .tag(Tab.editor)
}
.tabViewStyle(.sidebarAdaptable)
// Pythia overlay lives above everything
.pythiaOverlay(viewModel: oracleVM)  // custom modifier
```

### 0.3 File Browser — Dual Mode
```swift
enum FileBrowserMode {
    case attached   // sidebarAdaptable TabView sidebar
    case detached   // free-floating NSPanel
}
```

- `attached`: The default TabView sidebar. MacOS manages collapse, icon-only, keyboard nav.
- `detached`: A secondary `NSPanel` (utility style, floats above but doesn't steal focus). Same `FileBrowserView` rendered inside.

Toggle in Settings (`@AppStorage("fileBrowserMode")`). Switching modes re-parents the view — SwiftUI handles the lifecycle.

### 0.4 PythiaSheet — The Card Flip
```swift
struct PythiaSheet: View {
    @EnvironmentObject var pythiaPresence: PythiaPresence  // singleton
    let front: AnyView   // the editor (or whatever summoned her)
    let back: PythiaView

    var body: some View {
        ZStack {
            front
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            if isFlipped {
                back
                    .opacity(isFlipped ? 1 : 0)
                    .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isFlipped)
    }
}
```

**PythiaPresence** — a global `@ObservableObject` singleton:
```swift
class PythiaPresence: ObservableObject {
    static let shared = PythiaPresence()
    @Published var isPresented = false
    @Published var contextMessage: String?  // pre-fill input

    func summon(with context: String? = nil) { ... }
    func dismiss() { ... }
}
```

Any window, any view, any context:
```swift
@EnvironmentObject var pythia: PythiaPresence

// Highlight some code, right-click → "Ask Pythia"
pythia.summon(with: "Explain this: \(selectedCode)")
// → card flips → PythiaView appears with pre-filled context → user chats → dismiss → flips back
```

### 0.5 Materials Cheat Sheet
| Element | Material + Tint | Notes |
|---|---|---|
| Window envelope | `.containerBackground(.ultraThickMaterial)` + `tint.window` | Edge-to-edge glass |
| Sidebar (TabView chrome) | `.ultraThinMaterial` + `tint.sidebar` | macOS manages natively via sidebarAdaptable |
| Sidebar list rows | `.scrollContentBackground(.hidden)` + `tint.sidebar` | Let glass bleed through |
| Editor surface | `.regularMaterial` + `tint.editor` | Readable but translucent |
| Editor gutter | `.thinMaterial` | Subtle separation, no tint |
| Pythia card back | `.regularMaterial` + `tint.oracle` | Full-size chat surface |
| Pythia message bubbles | `.ultraThinMaterial` + `RoundedRectangle` + `tint.bubble` | Frosted glass bubbles |
| Pythia input field | `.thickMaterial` + `RoundedRectangle` | Interactive affordance, no tint |
| Toolbar | `.toolbarBackground(.ultraThinMaterial)` + `tint.toolbar` | Unified with content |

### 0.6 Tinting Materials (ThemeManager Repurposed)

`ThemeManager` no longer owns flat backgrounds — materials handle that. Instead it provides **tint presets** washed over the glass:

```swift
class ThemeManager: ObservableObject {
    @Published var theme: ThemePreset = .amethyst

    struct ThemePreset {
        let name: String

        // Each tint = (color, opacity, blendMode)
        let window:   (Color, Double, BlendMode)  // → .ultraThickMaterial overlay
        let sidebar:  (Color, Double, BlendMode)  // → .ultraThinMaterial overlay
        let editor:   (Color, Double, BlendMode)  // → .regularMaterial overlay
        let oracle:   (Color, Double, BlendMode)  // → .regularMaterial overlay
        let bubble:   (Color, Double, BlendMode)  // → .ultraThinMaterial overlay
        let toolbar:  (Color, Double, BlendMode)  // → .ultraThinMaterial overlay

        // Accent for cursor, selection, syntax highlights (opaque)
        let accent:   Color
    }

    static let amethyst = ThemePreset(
        name:    "Amethyst",
        window:   (Color.purple,  0.08, .hue),
        sidebar:  (Color.indigo,  0.06, .hue),
        editor:   (Color.purple,  0.04, .hue),
        oracle:   (Color.indigo,  0.06, .hue),
        bubble:   (Color.purple,  0.10, .hue),
        toolbar:  (Color.purple,  0.05, .hue),
        accent:   Color.purple
    )
}
```

**Why overlay + blend mode?** Materials are translucent — you can't recolor them directly. A thin color wash with `.blendMode(.hue)` shifts the warmth of the glass without destroying the material's adaptive light/dark behavior. Opacity stays subtle (0.04–0.10) — the material always wins.

**Usage:**
```swift
// View modifier for tinted material
extension View {
    func glassSurface(_ material: Material, tint: (Color, Double, BlendMode)) -> some View {
        self.background(material)
            .overlay(tint.0.opacity(tint.1).blendMode(tint.2))
    }
}

// In FileBrowserView:
List { ... }
    .glassSurface(.ultraThinMaterial, tint: theme.sidebar)
    .scrollContentBackground(.hidden)
```

`ThemeManager` stays — but it stores **tints for glass**, not opaque backgrounds. Zero hex codes, zero flat `Color`s (except `accent` for opaque elements like cursor/caret).

### 0.7 Accessibility
```swift
@Environment(\.accessibilityReduceTransparency) var reduceTransparency

// Fallback: bump tint opacity slightly so color still reads through thicker materials
// Never fall back to opaque flat colors — keep the material hierarchy
```

### 0.8 Delete Legacy AppKit Files
Once all views use glass+tint materials, the old AppKit view controllers are dead code:
- `EditorViewController.swift`, `PythiaViewController.swift`, `LineNumberView.swift`
- `MainWindowController.swift`, `EditorWindowController.swift`
- Stale `RubyBridge.swift` duplicate in `App/`

`ThemeManager.swift` stays — repurposed as `ThemePreset` tint catalog (see 0.6).

---

## Phase 1: Editor Core ✅ COMPLETE
- `EditorView.swift` — `NSTextView` in `NSViewRepresentable` + SwiftUI gutter
- `DocumentManager.swift` — open/save/dirty state
- `RootView.swift` — TabView with sidebarAdaptable (Files | Editor)
- `FileBrowserView.swift` — recursive native SwiftUI tree

---

## Phase 2: Pythia Card Flip

### 2.1 PythiaPresence Singleton
- `@Published isPresented` — drives the flip
- `summon(with:)` — flips, optionally pre-fills context
- `dismiss()` — flips back
- `contextMessage` — pre-fill the input field

### 2.2 PythiaSheet Modifier
```swift
extension View {
    func pythiaOverlay(viewModel: OracleViewModel) -> some View {
        self.modifier(PythiaSheetModifier(viewModel: viewModel))
    }
}
```
Applied once at `RootView` level. Covers the entire TabView. Pythia flips over everything.

### 2.3 Summon from Anywhere
- **Menu bar**: View → Pythia (⌘⇧P)
- **Editor right-click**: "Ask Pythia about selection"
- **File browser right-click**: "Ask Pythia about this file"
- **Keyboard**: ⌘⇧P toggles the flip
- **Toolbar button**: sparkles icon

All routes go through `PythiaPresence.shared.summon(with:)`.

---

## Phase 3: Ruby Embedding
- Static libruby, `ruby_init()`, load oracle from embedded bundle
- `RubyBridge.sendToOracle(message:completion:)`

---

## Phase 4: AI Integration
- Message pipeline: SwiftUI → RubyBridge → Oracle → streaming back
- Tool call cards (collapsible, status: pending/running/done)
- Markdown rendering with `AttributedString`

---

## Phase 5: File Browser Detached Mode
- `SettingsView` with `@AppStorage("fileBrowserMode")` picker
- Detached mode: open `FileBrowserView` in `NSPanel` (utility, non-activating)
- Re-parenting: `FileBrowserView` is the same component, just hosted differently
- Panel position persists via `@AppStorage`

---

## Phase 6: Polish & Distribution
- Spring animations for card flip, sidebar toggle
- Reduce-transparency fallback
- Code signing, sandbox, notarization
- DMG + Sparkle auto-update

---

## Legacy Cleanup (post-migration)
```
🗑️ AetherCodex/Editor/EditorViewController.swift
🗑️ AetherCodex/Editor/EditorWindowController.swift
🗑️ AetherCodex/Editor/LineNumberView.swift
🗑️ AetherCodex/AI/PythiaViewController.swift
🗑️ AetherCodex/Pythia/PythiaViewController.swift
🗑️ AetherCodex/Ruby/RubyBridge.swift
🗑️ AetherCodex/App/ThemeManager.swift
```
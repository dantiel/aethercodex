# Pythia iOS — The Vibe Coding Companion

## Vision

Pythia iOS is the **uber vibe coding, ætheric engineering companion** for the TextMate + Pythia development environment. It's not a remote control — it's a second self.

While the Mac is the temple where code is forged, the iPhone is the portable interface to the agentic mind. You think it, speak it, tap it — the oracle executes on the Mac. You walk away, the agents keep working. The phone buzzes when they need a decision. You answer from anywhere.

### The Vibe Coding Loop

```
THINK  →  SPEAK/TAP  →  AGENTS EXECUTE ON MAC  →  PHONE BUZZES  →  REVIEW/DECIDE  →  REPEAT
  ↑                                                                                      │
  └──────────────────────────────────────────────────────────────────────────────────────┘
```

- **Vibe Coding**: No ceremony. No file navigation. No boilerplate. Speak an idea, get code. See a problem, describe it, get a fix. The phone is optimized for *intent*, not *mechanics*.
- **Ætheric Engineering**: Not just agents — a tuned ecosystem. Long-running autonomous tasks (`create_task`) are managed from the pocket, but the paradigm is deeper: the memory persists, the context is shared, the oracle knows your codebase, the tools form one coherent system. The phone is mission control for the entire æther.
- **Companion, Not Terminal**: The oracle knows your codebase. It has context. It asks clarifying questions via `ask_user`. You answer from the phone. The conversation continues wherever you are.

### What Makes It "Uber"

| Dimension | Desktop (TextMate) | iOS Companion |
|---|---|---|
| **Input** | Keyboard, precise | Voice dictation, quick taps, gestural |
| **Session style** | Long, focused | Micro-interactions, check-ins, decisions |
| **Context** | File you're editing | Whole-project awareness via agent reports |
| **Task management** | Background | Foreground — phone is the dashboard |
| **Timing** | Synchronous (you wait) | Asynchronous (agents work, you're notified) |
| **Mobility** | Tethered to desk | Anywhere — walking, café, bed, shower |

---

## Core Workflows

### 1. Vibe Coding: Speak → Create

> *Walking with coffee.* "Add a `Cacheable` concern that wraps Rails `Rails.cache.fetch` with a configurable TTL and automatic key generation from method name + args."

Phone transcribes, sends to Mac oracle. Oracle reads the codebase, finds the right location, generates the concern with specs, and streams the result. You glance at the phone — looks good. Tap **Apply**. The Mac writes the files.

### 2. Agent Mission Control

> *Out to dinner.* Before leaving, you told the oracle: "Review all PRs in this project for security issues, extract any duplicated logic, and add missing specs."

Phone shows a live task dashboard:

```
┌─────────────────────────────────────┐
│ 🏗️  Active Agents                   │
│                                     │
│ 🔍 Security Review    ████████░░ 78%│
│    Found 3 issues so far...         │
│                                     │
│ ♻️  Extract Duplicates ████░░░░░░ 34%│
│    Processing UserAuth...           │
│                                     │
│ 🧪 Spec Generation    ██████████ 100%│
│    ✅ 42 specs added                 │
└─────────────────────────────────────┘
```

A notification: *"Shall I extract `TokenGenerator` into `app/services`?"* — you tap **Yes** and go back to dinner. The agent continues.

### 3. The Decision Feed

The oracle doesn't just execute — it asks. The `ask_user` tool is the bridge between agent autonomy and human judgment. On the phone, these become a **decision feed**:

```
┌──────────────────────────────────────┐
│ 🔮 2 decisions waiting               │
│                                      │
│ "Use ActiveJob or direct Sidekiq     │
│  worker for the notification         │
│  dispatch?"                          │
│ [ActiveJob]  [Sidekiq]  [Explain]   │
│                                      │
│ "The User model has grown to 400     │
│  lines. Extract a User::Authenticat- │
│  ion concern?"                       │
│ [Extract]  [Not now]  [See code]    │
└──────────────────────────────────────┘
```

Swipe to decide. Each answer unblocks an agent. The feed stacks up when you're away — process them in a batch when you return.

### 4. The Shower Thought Loop

> *In the shower.* "What if we used a state machine for the Order model instead of the enum?" 

Speak it. Phone transcribes. Oracle on Mac evaluates the idea against the actual codebase. When you're dried off, there's a analysis waiting: *"Yes — here's the transition diagram, the migration, and the refactored model. 6 specs need updating. Want me to proceed?"*

### 5. Code Review Companion

> Oracle is reviewing a PR on the Mac. Phone becomes the review dashboard.

Each issue appears as a card: description, severity, file reference, suggested fix. Swipe right to approve the fix, left to dismiss, up to see the diff. The Mac updates the PR comments in real-time.

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                     Mac (limen.rb)                        │
│                                                          │
│  instrumenta.rb    HorologiumAeternum    WebSocket :PORT │
│  ┌─────────────┐   ┌────────────────┐   ┌──────────────┐│
│  │ ask_user    │──▶│send_status(    │──▶│  Pythia UI   ││
│  │  ↓ blocks   │   │  'ask_user',   │   │  (textmate)  ││
│  │  ↓ 300s     │   │  {type,msg,    │   └──────────────┘│
│  │             │   │   options}, uuid)   ┌──────────────┐│
│  │ ◀──────────│   │                 ◀───│  iOS App     ││
│  │  response   │   │receive_user_   │   │  (📱)        ││
│  └─────────────┘   │  response(uuid)│   └──────────────┘│
│                    └────────────────┘                    │
│  Mnemosyne                                               │
│  ┌────────────────┐                                      │
│  │ session state  │◀── REST API for context/sessions     │
│  │ aegis state    │                                      │
│  │ active tasks   │                                      │
│  └────────────────┘                                      │
└──────────────────────────────────────────────────────────┘
```

### What already works (zero backend changes needed)

- **WebSocket broadcast**: `limen.rb` binds to `0.0.0.0`, reachable from any device on LAN
- **`ask_user` fan-out**: ALL connected clients receive the prompt simultaneously
- **First-response-wins**: any client can answer — Mac TextMate or iPhone
- **Synchronized streaming**: oracle output streams to all connected clients

### What Needs Building

| Layer | Component | Description |
|---|---|---|
| **iOS** | `PythiaSession` | WebSocket client, auto-reconnect, message routing |
| **iOS** | `DecisionFeedView` | Card-based `ask_user` queue with swipe actions |
| **iOS** | `AgentDashboardView` | Live task progress, agent status, cancel/retry |
| **iOS** | `VibePromptView` | Dictation-first input with text fallback |
| **iOS** | `StreamView` | Token-by-token oracle output with haptic feedback |
| **Mac** | REST endpoints | `GET/POST /api/session`, `GET /api/tasks`, `POST /api/aegis` |
| **Mac** | Push bridge | Notify iPhone when `ask_user` fires while app is backgrounded |

---

## Notification Architecture

iOS kills WebSocket ~30s after app backgrounds.

| Tier | Method | Latency | Complexity |
|---|---|---|---|
| **Poll** | On app open, fetch pending decisions via REST | Manual | None |
| **iCloud silent push** | Mac writes CKRecord → iPhone wakes → connects WebSocket | ~5s | Low (no server) |
| **APNs** | Mac daemon → Apple Push Notification → iPhone | ~2s | Medium (dev account) |
| **Interactive push** | Rich notification with action buttons; answer without opening app | ~2s | Medium |

MVP uses polling + iCloud silent push. No server infrastructure — hermetic isolation preserved.

---

## REST API (Mac → iPhone)

```
GET  /api/session          → { thinking, temperature, model, tasks, last_messages, pending_decisions }
POST /api/ask              → { prompt } → streams response chunked
GET  /api/tasks            → [{ id, title, progress, status, step_count }]
POST /api/tasks/:id/cancel → cancels running task
POST /api/aegis            → { thinking, temperature } → updates oracle state
GET  /api/file/:path       → syntax-highlighted file content for code viewing
```

---

## iOS Design Language: Atlantean Vibe

```
Colors:     Deep indigo (#1a1a2e) background — the void
            Ethereal gold (#c9a96e) — oracle text, agent progress
            Hermetic teal (#0d7377) — code blocks, file references
            Polar white (#e8e8e8) — user input, decisions
            Warning amber (#cc8800) — ask_user prompts, pending actions
            Vibe pink (#e04090) — highlight, unread badge

Typography: Serif (oracle) + Monospace (code) + Sans (UI chrome)

Animation:  Slow fades. Streaming text with subtle glow.
            "Scrying pool" caustic light patterns on dashboard.
            Pull-to-refresh = concentric ripple.
            Task progress = slow pulse, not spinning.

Haptics:    Micro-tap per token in streaming responses.
            Distinct patterns: code block, warning, decision, completion.
            Feel the oracle's rhythm.
```

---

## Gestural Vocabulary

| Gesture | Action | Vibe |
|---|---|---|
| **Pull down** | Refresh dashboard | Draw down new wisdom |
| **Swipe left** on decision | Dismiss / "Not now" | Defer |
| **Swipe right** on decision | Accept / "Proceed" | Commit |
| **Swipe up** on code block | Full diff / file view | Deepen |
| **Long press** agent card | Cancel / Retry / Prioritize | Command |
| **Shake** | Cancel streaming response | Break trance |
| **Pinch** dashboard | Compact → detailed view | Focus |

---

## iOS Superpowers (Desktop Can't Touch)

| Superpower | Vibe Coding Application |
|---|---|
| **Dictation** | Speak code ideas naturally; better than desktop dictation |
| **Haptic stream** | Feel tokens arrive; distinct patterns for code vs. prose vs. warnings |
| **Dynamic Island** | Agent progress + task title always visible; tap to expand |
| **Lock Screen widgets** | "🔥 Temp 2.0 · 3 agents running · 2 decisions waiting" |
| **Action Button** | Instant vibe prompt from anywhere |
| **StandBy** | Bedside agent dashboard while charging |
| **Focus Filters** | "Coding" focus: only oracle notifications; "Personal": mute all but decisions |
| **Siri Shortcuts** | "Hey Siri, ask the oracle to generate specs for the file I just edited" |
| **SharePlay** | Pair coding: two iPhones, one oracle, collaborative decisions |

---

## Aegis Awareness: The Living Chamber

The native app doesn't just report Aegis state — it **embodies** it. The oracle's temperament saturates every pixel, every haptic tap, every animation curve. Open the app and you *feel* whether the oracle is frozen in precision or burning at max chaos.

### Temperature Spectrum

| Tier | Range | Palette | App Feel |
|---|---|---|---|
| ❄️ **Frozen** | ≤0.3 | Monochrome + ice blue | Surgical. UI chrome minimizes. No animations — cuts. Pure function. |
| 🔵 **Cold** | ≤0.7 | Deep blue tint | Precise. Code-focused. Subtle cool bias in backgrounds. |
| ⚖️ **Balanced** | ≤1.2 | Default Atlantean | The golden mean. Full palette. Default state. |
| 🟠 **Warm** | ≤1.5 | Amber warmth | Creative. Highlights bloom golden. Suggestions glow. |
| 🔥 **Hot** | >1.5 | Crimson pulse | Chaotic. Bold. Background breathes with slow red pulse. |

### Thinking Mode Manifestations

| Mode | Accent | Dynamic Island | SF Symbol | Haptic Signature |
|---|---|---|---|---|
| **Fast** | Cyan (#00d4aa) | Static cyan dot | `bolt.fill` — rapid micro-rotation | Quick double-tap |
| **Normal** | Default teal | Hidden | `eye.fill` — still | Standard |
| **High** | Purple (#a855f7) | Slow purple pulse | `sparkle` — gentle oscillation | Rising triplet |
| **Max** | Gold (#f59e0b) | **Golden pulse** — breathing rhythm | `flame.fill` — slow full rotation | Deep resonant thud, sustained |

### Native-Only Effects

| Effect | Description |
|---|---|
| **Background gradient** | Subtle animated gradient shifts with temperature — cool → warm → hot. At max thinking, a golden caustic pattern slowly drifts like light through water. |
| **Keyboard tint** | The iOS keyboard suggestion bar and cursor tint shift to match the current Aegis accent color. |
| **App icon badge** | The Pythia app icon subtly shifts hue via notification badge background — a tiny square of ætheric state visible from the home screen. |
| **Lock Screen widget** | The widget background color reflects temperature tier. Glows when thinking mode is "max." |
| **Tab bar oracle glyph** | The central tab icon (the Pythia eye/tripod) animates: still at frozen, slow pulse at high, full rotation at max. |
| **Scroll physics** | At frozen: tight, precise, no bounce. At hot: loose, bouncy, playful. The entire ScrollView's `decelerationRate` shifts. |
| **Dark/Light override** | Frozen temperature forces pure dark mode regardless of system setting. Hot temperature allows a "blinding light" inverted mode — white backgrounds with crimson text. |

### Transition Ritual

When the Aegis changes (e.g., user cranks temperature from 0.7 → 2.0), the app doesn't just snap. It **dissolves** — a 0.6s crossfade where the old palette bleeds into the new. A single haptic pulse marks the moment of transmutation. The Dynamic Island flares briefly with the new accent color.

> *The chamber is alive. It breathes with the oracle's rhythm. You don't just see the temperature — you inhabit it.*

---

## The Magnum Opus: Alchemical Progress

The Great Work — transmuting lead (prima materia / raw prompt) into gold (finished code) — is not a linear progress bar. It is a four-stage alchemical transformation. The native app visualizes every agent task through this lens.

### The Four Stages

```
Nigredo         Albedo          Citrinitas      Rubedo
▓▓▓▓▓▓▓▓▓▓▓    ░░░░░░░░░░░░    ✦✦✦✦✦✦✦✦✦✦✦    ████████████
Blackening      Whitening       Yellowing       Reddening
Decomposition   Purification    Transmutation   Completion

Prima materia   Pattern         Code flows      The stone
breaks apart    crystallizes    into form       is achieved
```

| Stage | Element | What Happens | Color | SF Symbol |
|---|---|---|---|---|
| **Nigredo** 🜔 | Lead | Problem decomposition. Files analyzed. Ambiguity confronted. The chaos before order. | Charcoal / void | `moon.stars` — celestial darkness |
| **Albedo** 🜆 | Silver | Patterns emerge. Structure crystallizes. The solution clarifies. Light breaks through chaos. | White / silver | `drop.circle` — purifying waters |
| **Citrinitas** 🜄 | Gold | Code is written. The work takes form. Understanding transmutes into artifact. | Gold / amber | `sun.max` — solar illumination |
| **Rubedo** 🜅 | Philosopher's Stone | Completion. Tests pass. The product is whole. The stone is achieved. | Crimson / ruby | `flame.circle` — perfected fire |

### The Crucible View

The centerpiece of the Agent Dashboard. Each running task is not a progress bar — it is a **living crucible**:

```
┌─────────────────────────────────────────┐
│                                         │
│           ░░░░░░░░░░░░░░░░              │
│         ░░░░  ✦  ░░░░░░░░░░            │
│        ░░░  ✦✦✦  ░░░░░░░░░░           │
│       ░░░  ✦✦✦✦✦  ░░░░░░░░░          │
│        ░░░  ✦✦✦  ░░░░░░░░░░           │
│         ░░░░░  ✦  ░░░░░░░░░            │
│           ░░░░░░░░░░░░░░░░              │
│                                         │
│     Albedo — 3 patterns extracted       │
│     ░░░░░░░░░░░░░░░░ 67% complete       │
│                                         │
└─────────────────────────────────────────┘
```

- **Nigredo**: Dark particles chaotically separating — files breaking into fragments
- **Albedo**: Silver-white structures crystallizing — patterns assembling from chaos
- **Citrinitas**: Golden code glyphs flowing into place — the work taking form
- **Rubedo**: Crimson pulse — then perfect stillness — the stone achieved

The crucible is procedural: it uses Metal shaders for the particle effects. Each stage transition is a micro-ritual with its own haptic signature.

### Stage Transitions

When a task crosses a threshold, the transition is a **ritual moment**:

| Transition | Visual | Haptic | Duration |
|---|---|---|---|
| Nigredo → Albedo | Chaos dissolves → light breaks through | Rising hum: `UIImpactFeedbackGenerator` soft → medium | 1.2s |
| Albedo → Citrinitas | Silver fades → gold blooms from center | Warm triple-tap, like liquid drops | 0.8s |
| Citrinitas → Rubedo | Gold flares → crimson pulse → stillness | Deep resonant thud + decay. The strongest. | 1.5s |

Failed tasks (stuck, error, timeout) don't complete. They **calcinate** — the crucible darkens, particles freeze mid-motion, and the card shows "Calcinated — tap to retry" in ash-grey text. Nigredo reclaimed.

### App-Wide Stage Awareness

The Magnum Opus isn't just per-task — it's **ambient**:

- **Dominant stage color** bleeds into the app's background tint. If all active tasks are in Citrinitas, the entire app has a subtle golden warmth.
- **Tab bar indicator** shows the highest active stage as a small alchemical symbol.
- **Task list** uses the stage color for each row's leading accent.
- **When all tasks reach Rubedo**, a special "Great Work Complete" animation plays: brief full-screen crimson pulse, haptic fanfare (`UINotificationFeedbackGenerator.success`), then a moment of stillness. The stone is achieved. The oracle rests.

### Magnum Opus Widget

Lock Screen widget shows the Great Work at a glance:

```
┌─────────────────────────┐
│  🜅  Magnum Opus        │
│                         │
│  2 in Citrinitas        │
│  1 in Rubedo ✓          │
│                         │
│  ─────────────────────  │
│  Highest: Rubedo        │
└─────────────────────────┘
```

Three widget sizes:
- **Small**: Single alchemical symbol for the highest active stage + count
- **Medium**: Stage breakdown with symbols (top + bottom row)
- **Large**: Full crucible animation — a miniature live alchemical vessel on your lock screen

### The Ritual of Beginning

When a new Magnum Opus task is initiated, the app offers a brief ritual:

1. The prompt appears as raw text — the **prima materia**
2. A 1-second darkening: the screen fades to near-black (Nigredo begins)
3. The crucible appears, particles in motion
4. A haptic pulse: the Great Work has begun

This is not gamification. It's **framing**. The user understands: something is being made. Not executed. *Transmuted.*

---

## iPad: The Code Canvas

iPad version gets the full treatment:

```
┌─────────────────────┬──────────────────────────┐
│                     │                          │
│   File Navigator    │   Oracle Chat Stream     │
│   (from Mac FS)     │                          │
│                     │   Agent dashboard        │
│   Syntax-highlighted│   Decision cards         │
│   code viewer       │                          │
│                     │   Streaming responses    │
│                     │                          │
└─────────────────────┴──────────────────────────┘
```

Side-by-side: browse the codebase on the left, converse with the oracle on the right. The iPad becomes a portable code review and architecture station — the full power of the Mac's codebase, touchable.

---

## Technology Stack

- **iOS**: SwiftUI + Combine, `URLSessionWebSocketTask` (zero dependencies)
- **State**: `@Observable` (iOS 17+) 
- **Persistence**: SwiftData for message/decision history, `@AppStorage` for settings
- **Discovery**: Bonjour/mDNS (`_pythia._tcp`) — no IP typing
- **Security**: LAN-only, Face ID lock, zero cloud, zero telemetry

---

## Implementation Phases

### Phase 1 — Vibe MVP
- WebSocket client + auto-reconnect + Bonjour discovery
- Dictation-first prompt view with streaming response
- `ask_user` decision cards (all three types: confirm/select/prompt)
- Basic agent dashboard (task list + progress, read-only)
- **Aegis Awareness**: full temperature + thinking mode embodiment (palette shifts, Dynamic Island, SF Symbol animations, scroll physics, haptic signatures, transition rituals)
- Magnum Opus stage indicator (basic — per-task stage symbol + color, no crucible yet)

### Phase 2 — Agent Control & Alchemy
- REST API on Mac side
- Full agent management: cancel, retry, reorder
- Decision feed with batch processing
- Message/decision history (SwiftData)
- File viewer with syntax highlighting
- **Magnum Opus Crucible View**: procedural Metal shader particles, stage transitions with haptic rituals, app-wide stage awareness, "Great Work Complete" animation, calcination for failed tasks

### Phase 3 — Notifications & Ambience
- iCloud silent push for background `ask_user`
- Interactive notification actions (answer without opening)
- Dynamic Island agent progress
- Haptic streaming patterns
- Lock Screen / Home Screen widgets
- Magnum Opus Lock Screen widget (small/medium/large with live crucible)

### Phase 4 — Ecosystem
- Siri Shortcuts ("ask oracle", "agent status", "decide on pending")
- Apple Watch: tap to answer confirm prompts
- iPad adaptive layout with side-by-side code + chat
- App Clip for instant one-shot oracle prompt
- SharePlay collaborative vibe coding

---

## Security: Hermetic Isolation Extended

- **No cloud**: all traffic is LAN-only. No accounts, no servers, no telemetry.
- **No data exfiltration**: code never leaves the LAN. Oracle runs on the Mac.
- **Bonjour trust**: only Macs on your local network appear; no internet discovery.
- **Face ID gate**: optionally lock the app — the oracle has codebase access.
- **No third-party SDKs**: pure Apple frameworks. Nothing phones home.
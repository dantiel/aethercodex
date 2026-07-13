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
- Aegis state indicator (thinking mode, temperature, model)

### Phase 2 — Agent Control
- REST API on Mac side
- Full agent management: cancel, retry, reorder
- Decision feed with batch processing
- Message/decision history (SwiftData)
- File viewer with syntax highlighting

### Phase 3 — Notifications & Ambience
- iCloud silent push for background `ask_user`
- Interactive notification actions (answer without opening)
- Dynamic Island agent progress
- Haptic streaming patterns
- Lock Screen / Home Screen widgets

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
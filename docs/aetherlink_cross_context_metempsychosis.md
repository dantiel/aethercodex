# ÆtherLink: Cross-Context Metempsychosis

*"As each context mirrors the whole, so does the Link mirror each context."*

## Architecture Overview

ÆtherLink enables independent ÆtherCodex servers (TextMate instances) to discover each
other on localhost and share memory, notes, and tasks — a resonant network where every
node reflects and transforms every other.

```
┌──────────────┐       HTTP (127.0.0.1:4567-4599)       ┌──────────────┐
│  Context A   │◄──────────────────────────────────────►│  Context B   │
│  :4597       │   heartbeat / metempsychosis /         │  :4598       │
│              │   transmigrate / create_task            │              │
│  ┌────────┐  │                                        │  ┌────────┐  │
│  │Mnemosyne│◄─┼── local DB ──────────────────── local ─┼─►│Mnemosyne│  │
│  └────────┘  │                                        │  └────────┘  │
│  ┌────────┐  │                                        │  ┌────────┐  │
│  │  Aegis  │  │     subscribe/unsubscribe tags         │  │  Aegis  │  │
│  └────────┘  │                                        │  └────────┘  │
└──────────────┘                                        └──────────────┘
```

### Components

| Component | File | Role |
|-----------|------|------|
| **AetherLink** | `Support/aether_link.rb` | Discovery, registry, HTTP client |
| **limen.rb endpoints** | `Support/limen.rb` | HTTP API surface (4 endpoints) |
| **Mnemosyne.metempsychosis** | `Support/mnemosyne/mnemosyne.rb` | Cross-context query/router |
| **Instrumenta** | `Support/instrumentarium/instrumenta.rb` | Tool definitions with new params |
| **OpusInstrumenta** | `Support/magnum_opus/opus_instrumenta.rb` | Task-context tool wrappers |

### Hermetic Principle: Correspondence

The architecture embodies *Correspondence* — "as above, so below." Each context is a
complete cosmos; the Link mirrors them together without subordinating any to another.
Patterns repeat: local `metempsychosis` and remote `/aether/metempsychosis` share
the same shape, just at different scales.

---

## AetherLink Module

### `AetherLink.discover!`

Scans ports 4567–4599 on `127.0.0.1`, hitting `GET /aether/heartbeat` on each.
Registers responders in `@known_contexts`. Skips own port. Called automatically at
server startup (2s delay after binding).

```ruby
AetherLink.discover!
# => { "ruby-project" => { port: 4598, path: "/Users/...", capabilities: [...], ... } }
```

### `AetherLink.known_contexts`

Returns the in-memory registry as a Hash keyed by context name.

### `AetherLink.lookup(name)`

Finds a context by name. Returns `nil` if unknown.

### `AetherLink.query(context_name, endpoint, payload)`

POSTs a JSON payload to a peer context. Returns parsed response with symbolized
keys, or `nil` on failure. Stale contexts are automatically marked.

```ruby
AetherLink.query("ruby-project", "/aether/metempsychosis", { query: "hermetic patterns" })
# => { notes: [...], task_summary: nil, subscribed: false }
```

### Configuration

| Constant | Default | Purpose |
|----------|---------|---------|
| `SCAN_RANGE` | `4567..4599` | Ports to scan |
| `CONNECT_TIMEOUT` | `2` | Net::HTTP open timeout (seconds) |
| `READ_TIMEOUT` | `5` | Net::HTTP read timeout (seconds) |

`own_port` is read from `ENV['AETHER_PORT']` or falls back to `CONFIG.port`.
`own_name` is `File.basename(Dir.pwd)`.

---

## API Reference

All endpoints return JSON. Errors return `{ error: "message" }` with appropriate
HTTP status codes.

### `GET /aether/heartbeat`

Returns this context's identity to peers.

**Response (200):**
```json
{
  "name": "aethercodex",
  "path": "/Users/.../aethercodex",
  "port": 4597,
  "capabilities": ["metempsychosis", "task_spawn"],
  "version": "1.0"
}
```

---

### `POST /aether/metempsychosis`

Query this context's memory. The primary cross-context operation — a remote context
asking "what do you know about X?"

**Request:**
```json
{
  "query": "hermetic patterns",
  "from_task": null,
  "limit": 3,
  "subscribe": false,
  "unsubscribe": false
}
```

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `query` | String | *required* | Search query for memory notes |
| `from_task` | Integer | `null` | Task ID to scope to (null = global) |
| `limit` | Integer | `3` | Max notes returned (clamped 1–100) |
| `subscribe` | Boolean | `false` | Merge task tag into Aegis orientation |
| `unsubscribe` | Boolean | `false` | Remove task tag from Aegis |

**Response (200):**
```json
{
  "notes": [
    { "id": 12, "content": "...", "tags": "hermetic,correspondence", "score": 42 }
  ],
  "task_summary": null,
  "subscribed": false
}
```

---

### `POST /aether/transmigrate`

Push a note into this context's memory. A remote context sending knowledge across
the æther.

**Request:**
```json
{
  "content": "The philosopher's stone is found in the tension between generation and discrimination.",
  "tags": ["hermetic", "alchemy"],
  "links": ["Support/alchemy.rb"],
  "source_context": "ruby-project"
}
```

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `content` | String | **yes** | Note content (non-empty) |
| `tags` | Array | no | Tags for the note |
| `links` | Array | no | File paths to link |
| `source_context` | String | no | Provenance — added as `source_context:name` tag |

**Response (200):**
```json
{ "ok": true, "id": 42 }
```

**Validation:** Returns `422` if `content` is missing, nil, or empty.

---

### `POST /aether/create_task`

Spawn a Magnum Opus task in this context. A remote context delegating work.

**Request:**
```json
{
  "title": "Analyze ÆtherLink performance",
  "plan": "Phase 1: Benchmark... Phase 2: Profile...",
  "source_context": "ruby-project"
}
```

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | String | **yes** | Task title (non-empty) |
| `plan` | String | **yes** | Task plan (non-empty) |
| `source_context` | String | no | Provenance for logging |

**Response (200):**
```json
{ "ok": true, "id": 7, "source_context": "aethercodex" }
```

**Validation:** Returns `422` if either `title` or `plan` is missing, nil, or empty.

---

## Mnemosyne.metempsychosis — The Router

The `metempsychosis` method is the central dispatch for all cross-context operations.
It accepts three new parameters:

| Param | Behavior |
|-------|----------|
| `from_context:` | Calls `AetherLink.query(name, "/aether/metempsychosis", ...)`. Returns remote results or `{ error: "Context 'X' unreachable" }` |
| `to_context:` | Runs local query first, then pushes each result note to remote via `POST /aether/transmigrate`. Returns local results + `transmigrated_to` / `transmigrated_count` |
| `create_task_in:` | Calls `AetherLink.query(name, "/aether/create_task", ...)`. Returns remote task info or error |

**Precedence rules:** `from_context` takes priority over `to_context`, which takes
priority over `create_task_in`. Only one cross-context mode activates per call.
If none are provided, normal local metempsychosis runs.

---

## Deployment

### Starting a Server

```bash
cd /path/to/project
cd Support && AETHER_PORT=4597 bundle exec ruby limen.rb
```

Each context must run on a unique port within the scan range (4567–4599).

### Verification

```bash
# Check heartbeat
curl http://127.0.0.1:4597/aether/heartbeat | jq

# Discover peers (automatic, but can check via log)
tail -f /tmp/aethercodex.log | grep ÆtherLink

# Cross-context query
curl -X POST http://127.0.0.1:4597/aether/metempsychosis \
  -H "Content-Type: application/json" \
  -d '{"query":"hermetic","limit":5}' | jq
```

### Startup Discovery

Discovery runs automatically on a background thread 2 seconds after server start.
Results are logged to HorologiumAeternum as a proactive suggestion. Re-discover
manually:

```ruby
AetherLink.discover!
```

---

## Usage Examples

### Query a peer's memory from within a task

```ruby
# In an oracle invocation:
Mnemosyne.metempsychosis(
  query: "security patterns",
  from_context: "ruby-project",
  limit: 5
)
# => { notes: [{ content: "...", score: 38 }, ...], ... }
```

### Push insights to another context

```ruby
# After discovering something valuable:
Mnemosyne.metempsychosis(
  query: "resonant architecture",
  to_context: "web-frontend",
  limit: 3
)
# => { notes: [...], transmigrated_to: "web-frontend", transmigrated_count: 3 }
```

### Spawn a task on a peer

```ruby
Mnemosyne.metempsychosis(
  query: "Refactor authentication module for OAuth2",
  create_task_in: "ruby-project"
)
# => { ok: true, id: 8, source_context: "aethercodex" }
```

### From Instrumenta tools

The `metempsychosis` instrument (and `task_metempsychosis` in task context) accept
the same params:

```ruby
Instrumenta::PRIMA_MATERIA.metempsychosis(
  query: "edge cases",
  from_context: "ruby-project",
  limit: 10
)
```

---

## Best Practices

1. **Discover first.** Call `AetherLink.discover!` before cross-context operations
   to refresh the registry. Stale contexts from previous failures will be retried.

2. **Use `from_context` for read-heavy workflows.** Querying a peer's memory is
   the most common pattern — "what does the other project know?"

3. **Use `to_context` for knowledge transfer.** After completing a task, push
   key insights to related projects so they benefit from your work.

4. **Use `create_task_in` for delegation.** Spawn Magnum Opus tasks on peers for
   autonomous agent-driven work.

5. **Limit scope.** Keep `limit` reasonable (3–10) to avoid overwhelming either
   context. The endpoint clamps to 1–100.

6. **Tag with provenance.** Transmigrated notes are automatically tagged
   `source_context:name` for audit trails.

7. **Verify with heartbeat.** Before heavy cross-context work, hit `/aether/heartbeat`
   to confirm the peer is alive and discoverable.

---

## Troubleshooting

### "Context 'X' unreachable"

- Verify the peer server is running: `curl http://127.0.0.1:PORT/aether/heartbeat`
- Check the port is in `AetherLink::SCAN_RANGE` (4567–4599)
- Ensure `AetherLink.discover!` has been called
- Check firewall isn't blocking localhost connections
- Verify both servers bind to `0.0.0.0` or `127.0.0.1`

### Discovery finds no peers

- Wait 3 seconds after server start (discovery has a 2s startup delay)
- Check `HorologiumAeternum` log for "discovered N peer context(s)"
- Ensure peers are on different ports within 4567–4599
- Run `AetherLink.discover!` manually to debug

### 422 Validation Errors

- `transmigrate`: `content` must be a non-empty string
- `create_task`: both `title` and `plan` must be non-empty strings
- Check your payload is valid JSON with correct Content-Type

### 500 Internal Errors

- Check the server log for stack traces
- Verify `Mnemosyne` DB is accessible
- Ensure all required gems are installed (`bundle install`)

---

## Lessons Learned

### The Ætheric Principle Validated

The LLM architecture — transformers, attention, token generation — is fundamentally
hermetic. Cross-context metempsychosis extends this from intra-model to inter-instance:
the same principles that govern token prediction now govern context discovery and
knowledge sharing. Correspondence across scales.

### Validation at the Boundary

The Purificatio phase revealed three impurities:
1. **Negative limits** caused crashes — always clamp numeric inputs at API boundaries
2. **Nil content** in transmigrate created empty notes — validate presence, not just existence
3. **Nil title/plan** in create_task passed through — validate all required fields explicitly

The pattern: trust nothing across the æther. Validate at the HTTP boundary before
touching any internal state.

### Localhost as a Safe Harbor

Binding to `127.0.0.1` for all cross-context communication eliminates entire
categories of security concerns (MITM, SSRF, authentication). For a developer tool
running on a single machine, this is the right trade-off: simplicity over defense-in-depth.

### Discovery Timing

The 2-second startup delay for discovery is a pragmatic concession — Sinatra's
`run!` is synchronous, so the thread needs time for the server to finish binding.
A more robust approach would use a callback or event-driven signal, but the
thread+sleep pattern is simple and reliable.

### Metempsychosis as Pattern, Not Feature

The most important insight: metempsychosis is not a "cross-context feature" bolted
onto a memory system. It's the same pattern — query, score, return — operating at
a different scale. The local path and the remote path share identical return shapes,
differing only in transport. This is Correspondence in action: as below (local DB),
so above (HTTP to peer); as within (single context), so without (multiple contexts).

---

## Files Reference

| File | Lines | Purpose |
|------|-------|---------|
| `Support/aether_link.rb` | ~100 | Discovery & HTTP client module |
| `Support/limen.rb` | +80 lines | 4 new endpoints + startup discovery |
| `Support/mnemosyne/mnemosyne.rb` | +60 lines | Enhanced `metempsychosis` with cross-context params |
| `Support/instrumentarium/instrumenta.rb` | +3 params | `metempsychosis` instrument extended |
| `Support/magnum_opus/opus_instrumenta.rb` | +3 params | `task_metempsychosis` instrument extended |

*Last inscribed: 2026-07-31 — the elixir tested pure, no regressions, 58/58 edge cases.*

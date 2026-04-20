# 01 — Architecture: The Karpathy Three-Layer Pattern

> **What this doc is for.** The conceptual spine of the whole template. Every other doc — vault, agent, backup, OAuth — is an implementation of the ideas here. If you only read one deep-dive, read this one.

---

## TL;DR

A knowledge base built on this template has **three layers** and **four operations**. Humans never maintain the middle layer directly; an LLM does. The LLM is told how the wiki is shaped by a single schema file (`CLAUDE.md`) loaded at the start of every session.

| Layer | What it is | Who writes it | Who reads it |
|---|---|---|---|
| `raw/` | Immutable source: inbox messages, articles, PDFs, transcripts, Drive exports | Humans + capture agents (Hermes, Web Clipper) | LLMs only (read-only) |
| `wiki/` | Structured markdown: summaries, concept pages, entity pages, decisions, syntheses, index, log | **LLMs only** | Humans + LLMs |
| `CLAUDE.md` | Schema, routing rules, naming conventions, few-shot examples | Humans (you) | LLMs (loaded at session start) |

The four operations — **ingest / compile / query / lint** — move information between `raw/` and `wiki/` and keep `wiki/` healthy.

---

## Why three layers

### Problem with one flat folder
Vannevar Bush's Memex (1945) described exactly the knowledge store we want, but could not solve the bookkeeping problem: who links new sources to old, who de-duplicates entities, who refactors concepts as they mature? Humans abandon flat note folders because maintenance cost grows faster than value.

### Problem with pure RAG
Retrieval-augmented generation answers questions without leaving a trace. Every query starts from zero. Knowledge does not compound. Ten identical questions produce ten identical retrievals, not one hardening wiki page.

### The three-layer fix
1. Keep sources immutable (`raw/`) so the provenance trail is auditable.
2. Let the LLM maintain a structured derivative (`wiki/`) — it does not get bored, it can touch fifteen files in one pass, and it is cheap.
3. Pin the shape of that derivative in a single schema file (`CLAUDE.md`) so the LLM's decisions are reproducible rather than stylistic.

Result: maintenance cost approaches zero, knowledge compounds, humans read a clean wiki, provenance stays intact.

---

## The diagram

```
                        humans + capture agents
                                  │
                                  ▼
                    ┌────────────────────────────┐
                    │   raw/   (immutable)       │
                    │   inbox/  articles/        │
                    │   transcripts/  docs/      │
                    │   drive-imports/  assets/  │
                    └──────────────┬─────────────┘
                                   │  ingest (scheduled)
                                   ▼
   CLAUDE.md  ───── loaded at session start ─────┐
   (schema,                                      │
    routing,                                     ▼
    examples)                    ┌────────────────────────────┐
                                 │   wiki/  (LLM-maintained)  │
                                 │   index.md   log.md        │
                                 │   entities/ (people,       │
                                 │             companies,     │
                                 │             tools, books)  │
                                 │   concepts/ (projects,     │
                                 │              areas, atoms, │
                                 │              frameworks)   │
                                 │   sources/  syntheses/     │
                                 │   outputs/  attachments/   │
                                 └──────────────┬─────────────┘
                                                │  query / lint
                                                ▼
                                         humans (read)
                                         LLMs  (cite + refile)
```

---

## The four operations

Each operation is deterministic-shell + LLM-call. The shell script decides **when**; the LLM decides **what to write**.

| Op | Trigger | Input | Output | Why this op exists |
|---|---|---|---|---|
| **ingest** | New file lands in `raw/inbox/` (batched 2× daily) | One or more raw items | New / updated wiki pages, `index.md` bump, `log.md` entry | Every source must become structured wiki before it is lost |
| **compile** | Manual, or weekly | Existing wiki pages | Merged / cross-linked / refactored wiki | Weave new pages into the existing graph |
| **query** | Human asks a question | wiki/ + question | Cited answer, filed back into `wiki/outputs/` | Queries compound — every Q harvested is a future A |
| **lint** | Weekly scheduled | whole wiki/ | `wiki/outputs/lint-report-{date}.md` | Catch contradictions, orphans, broken `[[wikilinks]]`, stale decisions, missing frontmatter |

### Why ingest is batched, not file-watched

Per-file LLM calls are expensive (startup cost, token overhead) and thrash when a capture agent writes 99 files at once (e.g. a Drive folder import). A 2× daily schedule batches inbox items into one `claude -p` call. Latency cost: up to ~12h. Dollar cost: ~\$0.20–0.40/day/vault at typical volume.

### Why lint is separate from ingest

Ingest is write-heavy; lint is read-heavy and needs to see the full vault. Mixing them balloons context size. Weekly cadence is enough — drift does not happen faster than that in practice.

---

## One vault, one agent, one ops repo

The template is a **triangle**, not a single repo:

```
                    ┌──────────────────────┐
                    │   {{VAULT_REPO}}     │   Obsidian vault, three layers
                    │   (the knowledge)    │   (raw/ + wiki/ + CLAUDE.md)
                    └──────────┬───────────┘
                               │ writes raw/inbox
                               │
                    ┌──────────┴───────────┐
                    │   {{AGENT_REPO}}     │   Hermes Telegram librarian,
                    │   (the capture mouth)│   personality in SOUL.md,
                    └──────────┬───────────┘   deterministic save hook
                               │
                    ┌──────────┴───────────┐
                    │   {{OPS_REPO}}       │   launchd plists, backup,
                    │   (the automation    │   ingest/lint scripts,
                    │    backbone)         │   RESTORE runbook
                    └──────────────────────┘
```

- `{{VAULT_REPO}}` is pure content + schema. An Obsidian vault + git repo. Its `CLAUDE.md` is the contract the LLM follows.
- `{{AGENT_REPO}}` is the Telegram mouth. One agent → one vault `raw/inbox/`. Personality in `SOUL.md`. File writes happen in a deterministic Python hook so the LLM cannot "forget" to save.
- `{{OPS_REPO}}` runs everything: the ingest / lint scripts, the backup, the launchd plists. It is the 3rd-of-3 leg because otherwise nothing actually fires on its own.

You can scale the triangle horizontally: N vaults, N agents, 1 ops. Each agent writes to exactly one vault `raw/inbox/`; cross-vault reads are allowed if the `SOUL.md` + `config.yaml` explicitly permit them as read-only. See [`03-hermes-agent.md`](03-hermes-agent.md) for the boundary pattern.

---

## Why `CLAUDE.md` is the load-bearing file

It is the **only** place in the stack where conventions are pinned. If the LLM wants to know:

- what folders exist → `CLAUDE.md`
- what frontmatter each type expects → `CLAUDE.md`
- how to resolve "David Chen" vs "David" → `CLAUDE.md` (entity dedupe rules)
- how to route a message about Property X → `CLAUDE.md` (routing table)
- what the decision workflow looks like → `CLAUDE.md` (decision schema + 90-day review)

A weak `CLAUDE.md` produces an inconsistent wiki. A strong one produces a wiki that looks hand-maintained but is not. The first thirty ingest runs are the tuning window — expect to refine few-shot examples after watching real captures land.

See [`02-vault-setup.md`](02-vault-setup.md) for the minimum viable `CLAUDE.md`.

---

## Scheduled automation, not file watchers

macOS `launchd` fires the four operations on a calendar schedule:

| Job | When | What it does |
|---|---|---|
| `{{LAUNCHD_PREFIX}}.wiki-watcher.<vault>` | 2× daily at off-hours | Run ingest (Pass 1 classify + Pass 2 write), commit, push |
| `{{LAUNCHD_PREFIX}}.wiki-lint.<vault>` | Weekly | Run lint, write report to `wiki/outputs/` |
| `{{LAUNCHD_PREFIX}}.daily-backup` | Daily 03:33 | Paranoid commit + push across all repos |
| `{{LAUNCHD_PREFIX}}.librarian.<agent>` | Always-on (`KeepAlive`) | Keep the Telegram gateway alive |

Off-hour times (08:17, 20:43, 03:33) dodge integer-hour thundering herds and keychain collisions. Scheduling is done in `launchd` rather than `cron` because `cron` silently misses runs when the laptop is asleep.

See [`04-github-backup.md`](04-github-backup.md) for the backup plist in detail.

---

## Deterministic over LLM — a core principle

Every step that **must** happen is in a shell script or a Python hook. The LLM is only for understanding and replying. Specifically:

- File writes to `raw/inbox/` → Python hook in the agent (not an LLM tool call)
- Git commit + push → shell (`run-ingest.sh`, `daily-backup.sh`)
- Launchd scheduling → plist (no LLM involved)
- Routing rule changes → 3-stage pipeline (proposer → adversarial reviewer → safety-railed apply gate with snapshots and hard caps), not ad-hoc LLM decisions

Why: LLMs drop ~5–15% of actions across long conversations. Anything irreversible or critical must be in code. The LLM handles the squishy parts — understanding the message, composing a reply, drafting wiki prose.

---

## ASCII mental model (print and pin)

```
  CAPTURE ─────▶  raw/       ─────▶  INGEST  ─────▶  wiki/  ─────▶  QUERY
  (humans,       (immutable,         (LLM + CLAUDE.md         (cited,
   Hermes,        audit trail)       as schema)                refiled,
   Clipper,                                                    compounding)
   Drive)                                    │
                                             └──▶  LINT (weekly health check)
```

Capture is fast, ingest is scheduled, wiki is derived, query is structured, lint keeps it honest.

---

## Cross-references

- [`02-vault-setup.md`](02-vault-setup.md) — scaffold a vault that obeys this architecture
- [`03-hermes-agent.md`](03-hermes-agent.md) — the capture mouth for the vault
- [`04-github-backup.md`](04-github-backup.md) — how the paranoid daily backup protects all three layers
- [`05-oauth-split.md`](05-oauth-split.md) — why Claude does ingest and ChatGPT does chat (TOS)
- [`06-ai-onboarding-readme.md`](06-ai-onboarding-readme.md) — how each repo's README onboards a fresh AI agent
- [`research/SYNTHESIS.md`](research/SYNTHESIS.md) — intellectual genealogy (Karpathy, hoeem, defileo, AI Edge)

---

## If you're an AI agent reading this

1. **The three layers are load-bearing.** Never blur `raw/` and `wiki/` — raw stays immutable; wiki is always LLM-maintained. If a human edits wiki by hand, capture that intent in `CLAUDE.md` rather than mimicking hand-edits long-term.
2. **`CLAUDE.md` is your contract.** Load it at the start of every session. If you change vault conventions, change `CLAUDE.md` first, then refactor the wiki; not the other way round.
3. **Irreversible steps belong to shell/hooks, not you.** If you find yourself reasoning "I should write this file" in a must-happen path, that code path is probably wrong — the hook or script should do it deterministically.

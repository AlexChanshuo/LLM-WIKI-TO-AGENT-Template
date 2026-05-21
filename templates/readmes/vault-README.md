# {{VAULT_NAME}} — {{DOMAIN_DESCRIPTION}}

> **Repo on GitHub:** `{{GITHUB_USER}}/{{VAULT_REPO}}` (private)
> **Mounted at:** `{{LOCAL_ROOT}}/{{VAULT_NAME}}/`
> **Companion librarian:** [`{{AGENT_NAME}}`](https://github.com/{{GITHUB_USER}}/{{AGENT_REPO}}) (Telegram bot {{TELEGRAM_BOT_HANDLE}})
> **Vault type:** Obsidian + Claude-Code-managed wiki (Karpathy three-layer: `raw/` + `wiki/` + `CLAUDE.md`)

---

## TL;DR (read this first)

This repo IS an Obsidian vault. It captures signal for the {{DOMAIN_DESCRIPTION}} domain. New raw notes arrive from Telegram via the `{{AGENT_NAME}}` bot; Claude Code classifies them on a schedule and writes structured wiki pages under `wiki/`.

**One sentence:** *Telegram in -> raw inbox file -> scheduled 2-pass Claude classification -> structured Obsidian wiki out.*

---

## Where this repo sits in the ecosystem

```
                         +---- {{VAULT_NAME}} <---- {{AGENT_NAME}} <---- {{TELEGRAM_BOT_HANDLE}}
  {{PROJECT_NAME}} -----+---- <sister-vault-1>  <---- <sister-librarian-1>
                         +---- <sister-vault-2>  <---- <sister-librarian-2>
                         +---- {{OPS_REPO}} (orchestration: launchd, scripts, backups, RESTORE runbook)
```

| Repo | Role | Touches this vault? |
|---|---|---|
| **{{VAULT_NAME}}** (you are here) | Storage layer for {{DOMAIN_DESCRIPTION}} knowledge | -- |
| `<sister-vault-1>` | Storage for a separate domain | No (strict separation) |
| `<sister-vault-2>` | Storage for a separate domain | No (strict separation) |
| `{{AGENT_NAME}}` | Librarian bot that pre-processes & writes to `raw/inbox/` | Yes -- write-only to `raw/` |
| `{{OPS_REPO}}` | Scripts, launchd plists, RESTORE runbook, daily-backup | Yes -- runs `wiki-ingest` on this vault |

---

## Why this vault exists

Three concrete problems it solves:

1. **The "where did I put that thought?" problem.** Notes scatter across Telegram, voice memos, photos, and email. Without a single canonical home, cross-references decay and context made months ago cannot be revisited.
2. **The "compounding judgment" problem.** Decisions need scheduled reviews to learn from outcomes. Entities need follow-up cadences. References need retention notes. None of this happens automatically without a structured store.
3. **The "voice contamination" problem.** The domain this vault covers must stay clean of sibling-domain operational detail. Cross-references via `[[wikilinks]]` are encouraged; copying content across vaults is forbidden.

---

## Categorization framework

**PARA x Zettelkasten x supertags x CODE process**

- **PARA** (Tiago Forte) -- folders sorted by actionability: `projects/` (deadlined), `areas/` (ongoing), `resources/` (reference), `archive/` (done)
- **Zettelkasten** -- `concepts/atoms/` holds single-idea notes with dense `[[wikilinks]]`
- **Supertags** -- every entity (person, company, place, reference) carries rich frontmatter so Dataview queries work as a CRM
- **CODE** -- Capture (raw/) -> Organize (wiki/entities/) -> Distill (wiki/concepts/atoms/) -> Express (wiki/syntheses/, wiki/outputs/)

**The full schema lives in [`CLAUDE.md`](./CLAUDE.md).** That file is the source of truth for routing rules, frontmatter, classification rules, lint rules, and few-shot examples. Always read CLAUDE.md before modifying anything in `wiki/`.

---

## Folder map

```
{{VAULT_NAME}}/
|-- CLAUDE.md                 <- schema (READ THIS FIRST as an LLM)
|-- README.md                 <- you are here
|-- raw/
|   |-- inbox/                <- {{AGENT_NAME}} writes new notes here as {YYYY-MM-DDThhmmss}-{id}.md
|   |   |-- .classified/      <- Claude Pass-1 classification JSON sits here briefly
|   |   +-- .processed/       <- post-Pass-2 archives (gitignored)
|   |-- articles/             <- Web Clipper drops clipped articles here
|   |-- transcripts/          <- long voice notes / call recordings
|   |-- docs/                 <- PDFs converted via markitdown
|   +-- assets/               <- image attachments
|-- wiki/
|   |-- index.md              <- master catalog -- rebuilt on every ingest
|   |-- log.md                <- append-only changelog of every ingest run
|   |-- entities/             <- CRM core (people, companies, places, references)
|   |-- concepts/
|   |   |-- projects/         <- PARA -- active, deadlined
|   |   |-- areas/            <- PARA -- ongoing domains
|   |   |-- resources/        <- PARA -- reference material
|   |   |-- atoms/            <- Zettelkasten -- single-idea notes
|   |   |-- frameworks/       <- mental models
|   |   +-- archive/          <- completed projects, deprecated areas
|   |-- sources/              <- per-source summaries (200-500 words)
|   |-- syntheses/
|   |   |-- decisions/        <- FIRST-CLASS -- every "I decided X" gets scheduled review
|   |   |-- meetings/         <- significant meetings, distilled
|   |   |-- reflections/      <- weekly/monthly journal cross-cuts
|   |   +-- reading-notes/    <- per-source reflections
|   +-- outputs/              <- filed query answers + lint reports + triage queue
+-- templates/                <- Obsidian Templater templates per entity type
```

Tables of file purposes live in `CLAUDE.md` -- do not duplicate them here.

---

## Workflow (end-to-end)

1. **Capture.** A message arrives at {{TELEGRAM_BOT_HANDLE}} (text, voice, photo, URL). Optional additional channels (calendar, contacts, drive) land in `raw/inbox/` as well.
2. **Pre-process (deterministic).** The `{{AGENT_NAME}}` librarian transcribes voice, OCRs images, extracts URLs, and writes a clean markdown file into `raw/inbox/` via a deterministic Python `agent:start` hook -- NOT the LLM. The file is on disk before any LLM gets a chance.
3. **Reply.** The librarian confirms what was saved.
4. **Classify (Pass 1).** Twice a day (staggered off-hour), `{{OPS_REPO}}/run-ingest.sh {{VAULT_NAME}}` fires. Claude Haiku scans each unclassified inbox file and writes `raw/inbox/.classified/{filename}.json`.
5. **Ingest (Pass 2).** Claude Sonnet executes the proposed actions: creates/updates entity pages, writes source summaries, appends dated entries to area pages, creates decision pages with scheduled review dates, rebuilds `index.md`, appends to `log.md`.
6. **Archive.** Source files move from `raw/inbox/` to `raw/inbox/.processed/`.
7. **Auto-commit.** `run-ingest.sh` stages, commits, and pushes.
8. **Query.** Open the vault in Obsidian, or run `/wiki-query "..."` to have Claude answer with `[[wikilink]]` citations.
9. **Lint (weekly).** Sunday launchd job runs `wiki-lint` to surface decisions due for review, stale entities, orphan atoms, stale areas, and to draft the weekly reflection.

---

## Required assets & resources

### Hard dependencies

- **Obsidian** to view/edit the vault
- **Claude Code CLI** with OAuth in macOS keychain (runs from `{{OPS_REPO}}`)
- **`{{AGENT_NAME}}` running** (for inbound capture)

### Obsidian plugins

Dataview, Templater, Obsidian Git, Linter, Homepage, Kanban (list in `.obsidian/community-plugins.json`). Plugin code is gitignored -- install via Settings -> Community Plugins on first open.

### Secrets

**This repo holds no secrets.** Credentials live in:

- 1Password vault `{{PROJECT_NAME}} Secrets` (canonical)
- Local gitignored files owned by the librarian (`.env`, `auth.json`)
- macOS keychain entry `Claude Code-credentials`

### Disk + git assumptions

- The path `{{LOCAL_ROOT}}/{{VAULT_NAME}}/` is hardcoded in `{{OPS_REPO}}/run-ingest.sh`, launchd plists, and the librarian's `auto-save-inbox` hook. Do not move it.
- Remote: `git@github.com:{{GITHUB_USER}}/{{VAULT_REPO}}.git`. Pushed nightly by `{{OPS_REPO}}/scripts/daily-backup.sh`.

---

## How it actually works (under the hood)

### The two-pass classification

| Pass | Model | Purpose | Why this model |
|---|---|---|---|
| 1 -- `/wiki-classify` | Claude Haiku | Detect signals, list entities, propose actions, score confidence | Cheap; most decisions are routine routing |
| 2 -- `/wiki-ingest` | Claude Sonnet | Execute proposed actions; write quality prose into `wiki/` | Writing quality matters -- entity pages get re-read for years |

Confidence below the threshold set in `CLAUDE.md` -> file goes to `wiki/outputs/triage-queue.md` instead of being auto-written. Human reviews.

### The deterministic capture (NOT LLM-managed)

The librarian's `hooks/auto-save-inbox/handler.py` is a Python hook on the `agent:start` event. It reads the FULL message from `session.jsonl`, writes to `raw/inbox/`, and copies any voice/image attachments. The file is on disk **before** the LLM gets a chance to forget, refuse, or hallucinate. Deterministic where it must be, generative where it adds value.

---

## Backup & disaster recovery

This repo is covered by `{{OPS_REPO}}/scripts/daily-backup.sh`, fired by `com.{{LAUNCHD_PREFIX}}.daily-backup` launchd job at a staggered off-hour time:

- `git pull --rebase --autostash` first (safe with Obsidian's local edits)
- `git add -A` then commit with an auto-sync message
- Bulk-delete tripwire: aborts if >20 files would be deleted in one run
- Per-repo atomic `mkdir` lockfile prevents concurrent writes
- **Never** uses `--force`, `--hard`, or `--amend`
- Logs to `{{OPS_REPO}}/logs/daily-backup.log` + per-day JSON + `last.json`

**To rebuild on a fresh machine:** see `{{OPS_REPO}}/docs/RESTORE.md`. Step A clones this repo back from GitHub.

---

## If you're an AI agent reading this repo, do this in order

1. **Read `CLAUDE.md`.** That is the contract for what schema every wiki page must follow. This enforces the Karpathy three-layer contract: `raw/` (immutable input), `wiki/` (structured knowledge), `CLAUDE.md` (routing + schema).
2. **Read this README** (which you're doing).
3. **Sample 2-3 files in `wiki/entities/`** to see how frontmatter actually looks in practice.
4. **Sample 1-2 files in `wiki/syntheses/decisions/`** to understand the scheduled-review pattern.
5. **NEVER write to `raw/`.** That directory is read-only from your perspective -- only the librarian's deterministic hook writes to `raw/inbox/`, and only the ingest pipeline moves files to `.processed/`.
6. **NEVER delete files.** Use the graveyard pattern: move to `wiki/concepts/archive/` with a deprecation note dated today. Entities disappear slowly; historical context does not.
7. **NEVER rename a file without updating every wikilink to it.** Run a vault-wide search for the old slug and update all `[[...]]` references in the same commit. Broken wikilinks rot silently.
8. **NEVER edit `CLAUDE.md` without the user explicitly asking.** That file is the schema contract -- changing it retroactively invalidates past pages. If you believe it needs a change, propose the edit in your reply and wait for approval.
9. **NEVER commit before `/wiki-lint` passes.** The lint pass catches orphan atoms, stale areas, broken wikilinks, missing frontmatter, and schedule-overdue decisions. Address lint warnings in the same commit that triggered them.
10. **NEVER write area files from scratch.** Always APPEND dated entries -- the chronological accumulation IS the value.
11. **NEVER invent facts.** Use `[unverified]` markers if you cannot trace a claim to a source page.
12. **If unsure, route to triage.** Better to add an item to `wiki/outputs/triage-queue.md` than to write a wrong entity page.
13. **Respect the boundary with sister vaults.** This vault is for {{DOMAIN_DESCRIPTION}} only. Cross-link, do not cross-copy.

---

## Operating commands (run from this vault folder in Claude Code)

```
/wiki-classify       # Pass 1 -- Haiku scans raw/inbox/
/wiki-ingest         # Pass 2 -- Sonnet writes wiki updates
/wiki-query "..."    # ad-hoc question; answer saved to wiki/outputs/
/wiki-lint           # weekly health check; report saved to wiki/outputs/
```

Both ingest passes run automatically 2x/day via `{{OPS_REPO}}/launchd/com.{{LAUNCHD_PREFIX}}.wiki-watcher.{{VAULT_NAME}}.plist`.

---

## Trust model

- This vault is **private** on GitHub (only `{{GITHUB_USER}}` can clone).
- No secrets are tracked -- all `.env`, `auth.json`, OAuth tokens live outside the repo.
- The librarian bot only responds to the allowed Telegram user IDs set in `{{AGENT_NAME}}/.env` `TELEGRAM_ALLOWED_USERS`.
- Ingest pipeline uses Claude Code OAuth from macOS keychain -- first-party Anthropic use only (TOS-compliant).

---

## Reference

- Schema: [`CLAUDE.md`](./CLAUDE.md)
- Setup runbook: `{{LOCAL_ROOT}}/{{OPS_REPO}}/docs/SETUP.md`
- Disaster-recovery runbook: `{{LOCAL_ROOT}}/{{OPS_REPO}}/docs/RESTORE.md`
- Companion librarian: `{{LOCAL_ROOT}}/agents/{{AGENT_NAME}}/` (or [github.com/{{GITHUB_USER}}/{{AGENT_REPO}}](https://github.com/{{GITHUB_USER}}/{{AGENT_REPO}}))
- Architecture inspiration: Karpathy's "LLM Knowledge Bases" pattern (raw + wiki + CLAUDE.md three-layer)

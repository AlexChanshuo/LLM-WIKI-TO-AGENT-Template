# 06 — Writing a README an AI Agent Can Onboard From

> **What this doc is for.** A meta-guide. Every repo in the template stack — vault, agent, ops — needs a README that another AI agent (and a human) can read and be productive inside in 10 minutes. This doc prescribes the exact section order, what goes in each section, and a set of concrete examples.

---

## Why README-for-AI matters

A human can tolerate a chatty, rambling README because they skim, page-down, and gestalt-match. An AI agent gets one pass through the file with limited context, then starts making changes. A README that makes a human nod can make an AI produce a bad PR.

The pattern below is directive, predictable, and front-loads the things an AI needs before touching anything.

---

## The canonical section order

```
1. Title + one-line description
2. TL;DR (read this first)
3. Where this repo sits in the ecosystem
4. Why this repo exists
5. Folder map (what's where, in plain English)
6. End-to-end workflow
7. Required assets & resources
8. How it actually works (under the hood)
9. Setup (one-time, on a fresh Mac)
10. Logs & debugging
11. Backup / DR pointer
12. If you're an AI agent reading this repo, do this in order  ← NEVER rules live here
13. Reference
```

Ship every section. Empty sections are cheap; surprises to an AI agent are expensive.

---

## Section-by-section contract

### 1. Title + one-line description

First line: `# {{REPO_NAME}} — {10-word purpose}`. Second line: three metadata hits in a blockquote.

```markdown
# {{AGENT_NAME}} — Hermes Telegram Bot for {{VAULT_NAME}}

> **Repo on GitHub:** `{{GITHUB_USER}}/{{AGENT_REPO}}` (private)
> **Mounted at:** `{{LOCAL_ROOT}}/agents/{{AGENT_NAME}}/`
> **Telegram bot:** @{{TELEGRAM_BOT_HANDLE}}
> **Serves vault:** `{{VAULT_NAME}}` (`{{LOCAL_ROOT}}/{{VAULT_NAME}}/`)
```

### 2. TL;DR

Three to five lines, closed by **One sentence:** italic summary. The AI reader decides here whether to keep reading.

```markdown
## TL;DR (read this first)

This repo IS a Hermes agent. Telegram-native bot that captures the
operator's {{DOMAIN_DESCRIPTION}} signal and writes into the
{{VAULT_NAME}} Obsidian vault.

**One sentence:** *Telegram message in → Python hook deterministically writes
to `{{VAULT_NAME}}/raw/inbox/` → ChatGPT replies → Claude in `_ops/`
classifies into `{{VAULT_NAME}}/wiki/`.*
```

### 3. Where this repo sits in the ecosystem

ASCII diagram + "you are here" marker. Then a table that names each sister repo and what this one does to or for it.

```
                    ┌─── {{VAULT_NAME}} ◀── {{AGENT_NAME}} ◀── @bot   ← YOU ARE HERE
  ecosystem ────────┼─── {{OTHER_VAULT}} ◀── {{OTHER_AGENT}}      (optional, if multi-vault)
                    └─── _ops (orchestration)
```

### 4. Why this repo exists

Three numbered problems this repo solves. Each in plain English, 2–3 sentences. This is the "you do not actually need this, do you?" test that saves AIs from inventing duplicates.

### 5. Folder map

ASCII tree with a one-line description to the right of each file and directory. Runtime artifacts (`sessions/`, `state.db`, `*.log`) called out as gitignored.

### 6. End-to-end workflow

Split into **Inbound** (what happens when input arrives) and **Downstream** (what the next link in the chain does). Numbered, 5–10 steps each. The AI now knows the happy path.

### 7. Required assets & resources

Table or bullets covering:
- Secrets and where they live (1Password item name → local path, with `chmod` notes)
- External services (Telegram, OpenAI, Google, GitHub, launchd)
- Hard dependencies on the host machine (binary names, versions)

### 8. How it actually works (under the hood)

The architectural trivia that is easy to get wrong without context:

- Why the hook is deterministic (LLMs drop actions ~5–15% in long chats)
- Why `HERMES_HOME` is the repo root (not a `.hermes/` subdir)
- Why no `fallback_model: anthropic` (TOS — link to [`05-oauth-split.md`](05-oauth-split.md))
- Why this repo is backed up paranoidly (link to [`04-github-backup.md`](04-github-backup.md))
- Any deprecated file that stays as a breadcrumb (explain why)

### 9. Setup (one-time, on a fresh Mac)

Copy-pasteable block. Explicit `chmod 600` lines for secrets. Ends with a smoke-test.

```bash
cd {{LOCAL_ROOT}}/agents/{{AGENT_NAME}}

# 1. Restore secrets from 1Password
#    Paste "{{SECRET_VAULT_ITEM}}: .env"     into ./.env
#    Paste "{{SECRET_VAULT_ITEM}}: auth.json" into ./auth.json
chmod 600 .env auth.json

# 2. Verify Hermes installed
hermes --version         # expect v0.10+

# 3. Test boot (Ctrl-C to stop)
HERMES_HOME=$(pwd) ./scripts/start.sh

# 4. Register with launchd
ln -sf {{LOCAL_ROOT}}/_ops/launchd/{{LAUNCHD_PREFIX}}.librarian.{{AGENT_NAME}}.plist \
       ~/Library/LaunchAgents/
launchctl load -w ~/Library/LaunchAgents/{{LAUNCHD_PREFIX}}.librarian.{{AGENT_NAME}}.plist

# 5. Smoke test — message the bot, expect reply within 30s
```

### 10. Logs & debugging

`tail -f` commands for every log an AI might need. One per output stream, clearly labelled.

### 11. Backup / DR pointer

Two paragraphs: "This repo is backed up nightly at 03:33 via `_ops/scripts/daily-backup.sh`; full disaster-recovery runbook at `_ops/docs/RESTORE.md`." Plus a **what you LOSE** vs **what you KEEP** table — acceptable losses (ephemeral conversation state) vs preserved state (personality, config, hooks).

### 12. If you're an AI agent reading this repo, do this in order

The load-bearing section. Number a reading order (1–8 typical), then enumerate the NEVER rules. This is where you reinforce:

- NEVER commit `.env`, `auth.json`, `sessions/`, `memories/`, `state.db`, etc.
- NEVER add `fallback_model: anthropic` anywhere. TOS.
- NEVER write to sister vaults from this agent.
- NEVER weaken the daily-backup safety guarantees.
- NEVER add LLM calls inside the auto-save hook.
- NEVER hardcode secrets in any tracked file.
- NEVER move the repo — absolute paths are everywhere.

Count 8–15 of these for each repo, phrased as imperatives.

### 13. Reference

External and sibling links. Keep it short — Hermes docs, vault schema, RESTORE runbook, sister repos.

---

## Worked example — the NEVER rules for a vault

From a vault `README.md`:

```markdown
## If you're an AI agent reading this repo, do this in order

1. **Read `CLAUDE.md` first.** It is the schema that defines every convention
   in this vault.
2. **Read `wiki/index.md`** to see what is currently indexed.
3. **Read `wiki/log.md`'s last 30 entries** to see what changed recently.
4. **Never touch `raw/` files.** Raw sources are immutable; you may only move
   to `.processed/` via the ingest pipeline, never edit in place.
5. **Never commit `.env`, `.obsidian/workspace*.json`, or the `.classified/`
   and `.processed/` submarkers.** `.gitignore` covers these.
6. **Never hand-rewrite `wiki/index.md`.** It is rebuilt each ingest run.
7. **Never rewrite `wiki/log.md` history.** Append-only.
8. **Never cross-write** into sister vaults. Their agents own capture into them.
9. **Schema changes go into `CLAUDE.md` first, then downstream refactor follows.**
   Not the other way round.
```

---

## Worked example — the NEVER rules for the ops repo

```markdown
## If you're an AI agent reading this repo, do this in order

1. Read this README.
2. Read `docs/RESTORE.md` — how the system rebuilds on a fresh Mac.
3. Read `docs/SETUP.md` + `docs/SETUP-AGENTS.md`.
4. Read `scripts/daily-backup.sh`. Understand the 8 safety guarantees.
5. Read `run-ingest.sh` to understand the keychain → `claude -p` flow.
6. Sample one launchd plist to see the schema in use.
7. NEVER weaken the daily-backup safety guarantees. No `--force`, no `--hard`,
   no `--amend`, no removing the bulk-delete tripwire.
8. NEVER hardcode secrets in any committed file. 1Password is canonical.
9. NEVER add `fallback_model: anthropic` anywhere in librarian configs.
10. If you change a launchd plist, also update the `~/Library/LaunchAgents/`
    symlink and reload via `launchctl unload && launchctl load -w`.
11. If you add a new plist/script/secret, update RESTORE.md AND the
    matching 1Password item the same day.
12. All paths are absolute. Do not move the repo.
```

---

## What *not* to do in these READMEs

| Anti-pattern | Why it fails an AI reader |
|---|---|
| Marketing prose / "revolutionary second brain" | Wastes context; AI has to skim past it |
| A single giant "Getting Started" section | AI cannot tell what is mandatory vs optional |
| Silent assumptions ("the usual .env file") | AI may invent a different `.env` contract |
| Relative paths in setup blocks | Absolute paths only. Copy-paste must work from anywhere. |
| Implicit NEVER rules buried in prose | Make them numbered imperatives. |
| No DR pointer | AI cannot assess whether a mutation is recoverable |
| No "how it actually works" section | AI will rebuild the same mistake you already fixed |

---

## Minimum viable README checklist

- [ ] Title line `# {repo} — {purpose}`
- [ ] Metadata blockquote (GitHub path, mount path, role)
- [ ] TL;DR with an italic **One sentence** summary
- [ ] Ecosystem diagram with "YOU ARE HERE" marker
- [ ] Table of sister repos and this repo's relationship to each
- [ ] Three numbered "Why this repo exists" problems solved
- [ ] Folder map with one-line descriptions
- [ ] End-to-end workflow (inbound + downstream)
- [ ] Required assets table (secrets → paths → 1Password items)
- [ ] "How it actually works" explaining non-obvious design choices
- [ ] Setup block (copy-pasteable, absolute paths, `chmod 600` where needed)
- [ ] Logs section with `tail -f` commands
- [ ] Backup/DR pointer + lose-vs-keep table
- [ ] **AI onboarding section with NEVER rules as imperatives** (8–15 items)
- [ ] Reference section with sibling repos + external docs

---

## Cross-references

- [`01-architecture.md`](01-architecture.md) — the three-layer pattern every repo instantiates
- [`02-vault-setup.md`](02-vault-setup.md) — what the vault README documents
- [`03-hermes-agent.md`](03-hermes-agent.md) — what the agent README documents
- [`04-github-backup.md`](04-github-backup.md) — what every README's backup section refers to
- [`05-oauth-split.md`](05-oauth-split.md) — the NEVER rule that belongs in every agent README

---

## If you're an AI agent reading this

1. **Before writing a repo README, copy the 13-section order verbatim.** Do not invent a new structure; consistency across repos is what makes the system legible.
2. **Put NEVER rules as numbered imperatives, not prose.** An AI reader can enumerate and respect imperatives; it cannot reliably extract rules from narrative paragraphs.
3. **Always include absolute paths, `chmod 600` lines for secrets, and a DR pointer.** The README is the contract for how a fresh machine rebuilds this repo — every missing detail is a future incident.

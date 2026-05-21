# {{AGENT_NAME}} -- Hermes Librarian Bot for {{VAULT_NAME}}

> **Repo on GitHub:** `{{GITHUB_USER}}/{{AGENT_REPO}}` (private)
> **Mounted at:** `{{LOCAL_ROOT}}/agents/{{AGENT_NAME}}/`
> **Telegram bot:** {{TELEGRAM_BOT_HANDLE}}
> **Serves vault:** `{{VAULT_NAME}}` (`{{LOCAL_ROOT}}/{{VAULT_NAME}}/`)

---

## TL;DR (read this first)

This repo IS a [Hermes](https://hermes-agent.nousresearch.com/) agent. It is a Telegram-native bot that captures {{DOMAIN_DESCRIPTION}} signal (text, voice, photos, URLs, optional Drive folders) and writes it into the `{{VAULT_NAME}}` Obsidian vault for downstream Claude classification.

The repo is also `HERMES_HOME` -- Hermes runtime files (sessions, memories, gateway state) live here but are gitignored. What's tracked is the agent's PERSONALITY (`SOUL.md`), MEMORY index (`MEMORY.md`), CONFIG (`config.yaml`), HOOKS, SKILLS, and START SCRIPT.

**One sentence:** *Telegram message in -> deterministic Python hook writes to `{{VAULT_NAME}}/raw/inbox/` -> non-Anthropic LLM replies -> 2x daily Claude (in `{{OPS_REPO}}`) classifies into `{{VAULT_NAME}}/wiki/`.*

---

## Where this repo sits in the ecosystem

```
                         +---- {{VAULT_NAME}} <---- {{AGENT_NAME}} <---- {{TELEGRAM_BOT_HANDLE}}   <- YOU ARE HERE
  {{PROJECT_NAME}} -----+---- <sister-vault-1> <---- <sister-librarian-1>
                         +---- <sister-vault-2> <---- <sister-librarian-2>
                         +---- {{OPS_REPO}} (orchestration)
```

| Repo | Role | Touches this librarian? |
|---|---|---|
| **{{AGENT_NAME}}** (you are here) | Hermes agent for {{DOMAIN_DESCRIPTION}} | -- |
| `{{VAULT_NAME}}` | Vault this librarian writes to | **Yes** -- write-only to `raw/inbox/` |
| `<sister-vault-1>` | Sister domain vault | No -- sister librarian handles it |
| `<sister-vault-2>` | Sister domain vault | No -- sister librarian handles it |
| `{{OPS_REPO}}` | launchd plists keep this librarian alive; runs Claude on the vault | **Yes** -- `com.{{LAUNCHD_PREFIX}}.librarian.{{AGENT_NAME}}.plist` |

---

## Why this librarian exists

Three concrete problems it solves:

1. **The "I had a thought 5 minutes ago and now it's gone" problem.** Capture has to be one-tap-fast. Telegram is always open; Obsidian on phone is friction. Voice memos work because Whisper transcribes them cleanly.
2. **The "LLMs don't reliably write files" problem.** Letting an LLM decide whether to save a message, where to save it, and what to call it failed in early experiments -- sometimes the file got skipped, mislabeled, or hallucinated. The fix: a deterministic Python hook on `agent:start` writes the file BEFORE the LLM gets to think. The LLM's job is just to reply nicely.
3. **The "voice contamination" problem.** Multiple vaults, multiple voices. This librarian is single-vault-write by design -- three layers of defense ensure captures land in the correct vault.

---

## Voice & personality

Defined in [`SOUL.md`](./SOUL.md). The full personality contract including tone, language mix, awareness of the vault's domain, and redirection rules for out-of-scope requests lives there.

---

## Folder map

```
{{AGENT_NAME}}/                     <- HERMES_HOME (the dir IS the home)
|-- README.md                       <- you are here
|-- SOUL.md                         <- personality + voice rules (agent's "constitution")
|-- USER.md                         <- profile of the user from this librarian's lens
|-- MEMORY.md                       <- working memory index
|-- config.yaml                     <- Hermes config -- model routing, allowed tools, vault path
|-- .env                            <- SECRETS (gitignored): TELEGRAM_BOT_TOKEN, allowed users, API keys
|-- .env.example                    <- template (committed) -- copy to .env on setup
|-- .gitignore                      <- excludes .env, auth.json, sessions/, memories/, state.db, etc.
|-- auth.json                       <- SECRETS (gitignored): OpenAI Codex OAuth (or equivalent non-Anthropic OAuth)
|-- hooks/
|   +-- auto-save-inbox/
|       |-- HOOK.yaml               <- fires on agent:start
|       +-- handler.py              <- reads session.jsonl, writes to vault, copies attachments
|-- skills/                         <- custom callable skills (markdown, agentskills.io standard)
|-- scripts/
|   +-- start.sh                    <- launchd entry point: sets HERMES_HOME, loads .env, starts gateway
|-- platforms/                      <- runtime state (gitignored)
|-- sessions/                       <- runtime state (gitignored): per-conversation .jsonl
|-- memories/                       <- runtime state (gitignored): Hermes long-term memory store
|-- logs/                           <- runtime state (gitignored)
|-- state.db                        <- runtime state (gitignored): SQLite for sessions
|-- gateway.pid                     <- runtime state (gitignored)
+-- gateway_state.json              <- runtime state (gitignored)
```

---

## Workflow (end-to-end)

### Inbound (Telegram -> vault)

1. User sends a Telegram message to {{TELEGRAM_BOT_HANDLE}}. It may be plain text, a voice memo (Whisper transcribed), a photo (Claude Vision OCR), a forwarded URL (Readability extracted), or a Drive folder URL (optional sub-flow).
2. Hermes routes the message into the agent. The `agent:start` event fires.
3. **`hooks/auto-save-inbox/handler.py` runs (deterministic):**
   - Reads the FULL message from `sessions/{session_id}.jsonl` (NOT the truncated `ctx`)
   - Writes `{{VAULT_NAME}}/raw/inbox/{compact_ts}-{id}-{hash}.md` with frontmatter (source, tg_message_id, sender, date)
   - Copies voice/image attachments to `{{VAULT_NAME}}/raw/assets/` and links them
   - Detects Drive URLs (if the sub-flow is enabled) and spawns `{{OPS_REPO}}/drive-ingest.sh` detached
   - Returns control to Hermes. The file is on disk BEFORE the LLM has any choice.
4. Hermes gives the LLM (non-Anthropic -- see TOS section) the message + tools. The LLM composes a reply confirming what was saved.
5. Reply goes back to Telegram.

### Downstream (Claude classifies)

This librarian's responsibility ENDS at writing to `raw/inbox/`. Deep classification -- entity extraction, decision pages, atom notes, CRM updates -- is done by **Claude Code in `{{OPS_REPO}}/run-ingest.sh`**, fired by launchd 2x daily.

Why split this way:

- The non-Anthropic LLM is good at conversation; mediocre at structured extraction against a tight schema.
- Claude, with the vault's `CLAUDE.md` schema in context, is good at structured extraction.
- Splitting this way also keeps Anthropic OAuth use compliant (TOS allows it inside `claude -p`, NOT inside third-party agent frameworks).

---

## Required assets & resources (NOT in this repo)

### Secrets (1Password vault `{{PROJECT_NAME}} Secrets`)

- `.env` with:
  - `TELEGRAM_BOT_TOKEN` (from @BotFather)
  - `TELEGRAM_ALLOWED_USERS` (comma-separated user IDs; only they can talk to the bot)
  - `OPENAI_API_KEY` (for Whisper voice transcription)
  - `OBSIDIAN_VAULT_PATH={{LOCAL_ROOT}}/{{VAULT_NAME}}` (defensive -- pinned in case skills look up wrong default)
- `auth.json` with:
  - Non-Anthropic LLM OAuth credentials (e.g. OpenAI Codex -- `access_token`, `refresh_token`)
  - Any fallback credentials (e.g. GitHub Copilot PAT)

Both files are `chmod 600` and gitignored.

### External services

- Telegram (bot platform)
- A non-Anthropic LLM provider for chat (e.g. OpenAI Codex)
- OpenAI API (Whisper for voice)
- macOS launchd (keeps the bot alive)
- The `{{VAULT_NAME}}` repo at `{{LOCAL_ROOT}}/{{VAULT_NAME}}/` (write target)
- Optional: `{{OPS_REPO}}/drive-ingest.sh` (called for Drive URLs)

### Hermes

Installed globally. Each librarian uses `HERMES_HOME={{LOCAL_ROOT}}/agents/{{AGENT_NAME}}` to be fully isolated -- its own sessions, memories, state DB, model cache.

---

## How it actually works (under the hood)

### The auto-save-inbox hook is the critical piece

Without this hook, the system devolves to "ask the LLM nicely to save the file." That fails ~5-15% of the time across long conversations. With the hook:

- Reading from `sessions/*.jsonl` gives the COMPLETE message body (not the truncated `ctx` Hermes provides to skills)
- Python `pathlib` + atomic write is deterministic
- Drive URL detection happens at the same layer, in the same call -- no race condition
- Even if the LLM crashes mid-reply, the file is already saved

Source: `hooks/auto-save-inbox/handler.py`. Trigger config: `hooks/auto-save-inbox/HOOK.yaml`.

### Model routing

`config.yaml` sets:

- `model.default` to a non-Anthropic model (e.g. via `provider: openai-codex`)
- `smart_model_routing.cheap_model` for trivial responses
- `session_reset.telegram.idle_minutes: 60` (after an hour idle, next message starts a fresh session)
- Allowed tools restricted; filesystem tools scoped to the vault path
- **NO** `fallback_model: anthropic`, **NO** `anthropic` entry anywhere in config -- Claude is reserved for the official `claude -p` ingest pipeline only (TOS-compliant)

### Why `HERMES_HOME` IS the repo dir

Earlier architectures had `HERMES_HOME=$repo/.hermes/`. Flattened because:

- One repo per librarian -> one HERMES_HOME per librarian -> no path math
- Simpler `.gitignore`
- launchd plist is one line: `WorkingDirectory` and `EnvironmentVariables.HERMES_HOME` point to the same repo root

---

## Setup (one-time, on a fresh machine)

```bash
cd {{LOCAL_ROOT}}/agents/{{AGENT_NAME}}

# 1. Restore secrets from 1Password
#    Paste the "{{PROJECT_NAME}}: {{AGENT_NAME}}/.env" Secure Note into ./.env
#    Paste the "{{PROJECT_NAME}}: {{AGENT_NAME}}/auth.json" Secure Note into ./auth.json
chmod 600 .env auth.json

# 2. Verify Hermes installed
hermes --version

# 3. Test boot (Ctrl-C to stop)
HERMES_HOME=$(pwd) ./scripts/start.sh

# 4. Register with launchd
ln -sf {{LOCAL_ROOT}}/{{OPS_REPO}}/launchd/com.{{LAUNCHD_PREFIX}}.librarian.{{AGENT_NAME}}.plist \
       ~/Library/LaunchAgents/
launchctl load -w ~/Library/LaunchAgents/com.{{LAUNCHD_PREFIX}}.librarian.{{AGENT_NAME}}.plist

# 5. Smoke test -- message the bot on Telegram, expect a reply within 30s
```

Full disaster-recovery runbook: `{{LOCAL_ROOT}}/{{OPS_REPO}}/docs/RESTORE.md`.

---

## Logs

```bash
tail -f {{LOCAL_ROOT}}/{{OPS_REPO}}/logs/librarian-{{AGENT_NAME}}.out.log
tail -f {{LOCAL_ROOT}}/{{OPS_REPO}}/logs/librarian-{{AGENT_NAME}}.err.log
```

The launchd plist also restarts the gateway automatically (`KeepAlive=true`) if it crashes.

---

## Boundary (filesystem + cross-vault)

| Path | Access |
|---|---|
| `{{VAULT_NAME}}/raw/inbox/` | **WRITE** (via auto-save hook only) |
| `{{VAULT_NAME}}/wiki/` | READ + WRITE (via `wiki/outputs/` for query results) |
| Sister vaults' `wiki/` | **READ-ONLY** (via `query-vault` skill if enabled; redirects capture attempts) |
| Any vault's `raw/`, `.obsidian/`, `.git/`, `.env`, `auth.json`, `state.db` | NO access |
| Sister vaults -- any WRITE | NO -- redirect user to the sister librarian's Telegram handle |

**Three layers of defense:**

1. `SOUL.md` + `query-vault` skill -- explicit READ-ONLY instructions for sister vaults; redirect on cross-vault CAPTURE attempts
2. `.env` `TELEGRAM_ALLOWED_USERS` -- bot only responds to the configured user IDs
3. `hooks/auto-save-inbox/handler.py` hardcodes `{{VAULT_NAME}}/raw/inbox/` as the only write target -- even if the LLM tries to write elsewhere, the hook is the only deterministic WRITE path that auto-fires

---

## Backup

This repo (config, hooks, skills, SOUL.md, USER.md, MEMORY.md, scripts) is committed and pushed nightly by `{{OPS_REPO}}/scripts/daily-backup.sh`. Runtime state (sessions, memories, state.db, gateway state, model caches) is gitignored -- those are per-machine and regenerated each session.

**What you LOSE on a restore (acceptable):**

- Conversation history (sessions/*.jsonl)
- Long-term memories (memories/)
- Pairing state (sometimes) -- re-pair via `hermes pairing approve`

**What you KEEP (everything that matters):**

- SOUL.md, USER.md, MEMORY.md
- All hooks (especially auto-save-inbox)
- All skills
- config.yaml
- Start script

---

## If you're an AI agent reading this repo, do this in order

1. **Read [`SOUL.md`](./SOUL.md).** The agent's personality + behavioral contract.
2. **Read [`USER.md`](./USER.md).** Profile of the user from this bot's lens.
3. **Read [`config.yaml`](./config.yaml).** Model routing, tool allowlists, session policy.
4. **Read [`hooks/auto-save-inbox/handler.py`](./hooks/auto-save-inbox/handler.py).** The deterministic critical path.
5. **Read [`MEMORY.md`](./MEMORY.md).** Index of long-term memories Hermes has accumulated.
6. **NEVER commit `auth.json`.** Along with `.env`, `sessions/`, `memories/`, `state.db`, `gateway.pid`, `gateway_state.json`, or anything in `platforms/`. The `.gitignore` covers them but double-check before committing. A leaked `auth.json` is an account takeover.
7. **NEVER add `anthropic` to any config.** No `fallback_model: anthropic`, no `provider: anthropic`, no Anthropic API key in `.env`, no Anthropic OAuth in `auth.json`. Anthropic credentials are reserved for the `claude -p` pipeline in `{{OPS_REPO}}` (TOS enforced from Apr 4, 2026 -- using Anthropic auth inside a third-party agent framework like Hermes is a violation). If chat needs an LLM, it is a non-Anthropic model.
8. **NEVER let the LLM be the first touch on an inbound message.** Message capture MUST flow through the deterministic `hooks/auto-save-inbox/handler.py` hook BEFORE the LLM sees the message. No LLM calls inside `handler.py` -- only filesystem + regex + subprocess. The LLM's job is to reply, not to decide whether/where/how to save.
9. **NEVER write outside `{{VAULT_NAME}}/raw/inbox/`.** That is the only write target this librarian is permitted. No writes to sister vaults. No writes to `wiki/` (the ingest pipeline owns that). No writes to any path outside the bound vault. Redirect users to sister librarians for sister-vault captures.
10. **If you change the hook, test that:** (a) the full message body is captured (not truncated), (b) Drive URL detection still spawns `drive-ingest.sh` in background (if enabled), (c) attachments are copied, (d) atomic write semantics are preserved.
11. **Sister librarians follow the same architecture.** Cross-reference for consistency.

---

## Reference

- [Hermes Agent docs](https://hermes-agent.nousresearch.com/docs/)
- [Hermes GitHub](https://github.com/NousResearch/hermes-agent)
- Vault this librarian serves: `{{LOCAL_ROOT}}/{{VAULT_NAME}}/`
- Orchestration: `{{LOCAL_ROOT}}/{{OPS_REPO}}/`
- Disaster-recovery runbook: `{{LOCAL_ROOT}}/{{OPS_REPO}}/docs/RESTORE.md`

# 03 — Hermes Telegram Librarian

> **What this doc is for.** Stand up a Hermes-based Telegram bot that captures messages into a single vault's `raw/inbox/`. Covers `config.yaml`, `SOUL.md`, `auth.json`, `@BotFather`, the deterministic save hook, filesystem boundaries, cross-vault read-only pattern, and the launchd wiring.

---

## Mental model

```
 your phone     ─ Telegram ─▶  Hermes gateway  ─ agent:start hook ─▶  vault/raw/inbox/
                                    │                                        │
                                    │ ChatGPT (OpenAI Codex OAuth)           │ ingest 2×/day (Claude)
                                    ▼                                        ▼
                              brief reply back                          vault/wiki/*
```

Three non-negotiables:

1. **One agent writes to exactly one vault.** Write-bound to a single `{{VAULT_NAME}}/raw/inbox/`. Cross-vault reads are fine; cross-vault writes are not.
2. **Filesystem writes are deterministic.** A Python hook writes the inbox file before the LLM gets a chance to think. The LLM's job is only to reply nicely and (optionally) answer queries over `wiki/`.
3. **Claude never runs inside Hermes.** Anthropic OAuth credentials stay out of third-party agent frameworks. ChatGPT via OpenAI Codex OAuth handles the chat; Claude is reserved for the `claude -p` ingest pipeline in `{{OPS_REPO}}`. See [`05-oauth-split.md`](05-oauth-split.md).

---

## Repo shape

`{{AGENT_REPO}}` is **itself** `HERMES_HOME`. No `.hermes/` subdir.

```
{{AGENT_NAME}}/                ← HERMES_HOME
├── README.md                  ← human + AI-agent onboarding
├── SOUL.md                    ← personality + behavioural contract
├── USER.md                    ← profile of the human(s) it serves
├── MEMORY.md                  ← memory index (Hermes grows the memories it points to)
├── config.yaml                ← model routing, allowed tools, vault path
├── .env.example               ← template (committed)
├── .env                       ← SECRETS (gitignored)
├── auth.json                  ← SECRETS (gitignored): OpenAI Codex OAuth + GitHub Copilot PAT
├── .gitignore
├── hooks/
│   └── auto-save-inbox/
│       ├── HOOK.yaml          ← fires on agent:start
│       └── handler.py         ← deterministic write — NO LLM CALLS INSIDE
├── skills/
│   ├── query-vault.md         ← optional: read wiki/ of one or more vaults
│   ├── transcribe-voice.md    ← Whisper wrapper
│   ├── describe-image.md      ← Vision wrapper
│   └── fetch-url.md           ← Mozilla Readability wrapper
├── scripts/
│   └── start.sh               ← launchd entry point
├── platforms/                 ← runtime state (gitignored)
├── sessions/                  ← runtime state (gitignored)
├── memories/                  ← runtime state (gitignored)
├── logs/                      ← runtime state (gitignored)
├── state.db                   ← runtime state (gitignored)
├── gateway.pid                ← runtime state (gitignored)
└── gateway_state.json         ← runtime state (gitignored)
```

Everything runtime Hermes generates is at repo root and gitignored. What gets tracked: personality, memory index, config, hooks, skills, start script, and the `.gitignore` that keeps the rest out.

---

## `config.yaml` shape

```yaml
hermes_home: {{LOCAL_ROOT}}/agents/{{AGENT_NAME}}   # absolute — no surprises

models:
  default:
    provider: openai-codex              # ChatGPT via Codex OAuth (Pro subscription)
    model: gpt-5.4-mini
  smart_routing:
    cheap_model: gpt-5.4-nano           # trivial replies
  # NO fallback_model: anthropic        # TOS — see 05-oauth-split.md

tools:
  filesystem:
    allowed_write_paths:
      - {{LOCAL_ROOT}}/{{VAULT_NAME}}/raw/inbox
      - {{LOCAL_ROOT}}/{{VAULT_NAME}}/raw/assets
      - {{LOCAL_ROOT}}/{{VAULT_NAME}}/wiki/outputs   # only if this agent files query results
    allowed_read_paths:
      - {{LOCAL_ROOT}}/{{VAULT_NAME}}/wiki
      # Optional cross-vault READ (example — remove if single-vault)
      - {{LOCAL_ROOT}}/{{OTHER_VAULT}}/wiki

platforms:
  telegram:
    enabled: true
    long_poll: true

session_reset:
  telegram:
    idle_minutes: 60                    # fresh session after 1h idle
```

**Rule of thumb.** Tighten `allowed_write_paths` to exactly the directories your hook writes to. The hook itself is already scoped, but defense-in-depth matters if the LLM ever invokes a raw `write_file` tool.

---

## `SOUL.md` — the personality + behavioural contract

`SOUL.md` is the one doc the agent always has in context. It answers:

| Section | What to write |
|---|---|
| Voice | Warm/sharp/formal/bilingual — 3-6 bullets |
| Your job | 1–7 things the agent does, in order, when a message arrives |
| Domain knowledge | Entity types this vault cares about; routing heuristics |
| Boundary (read vs write) | Table: which paths are write, which are read-only, which are forbidden |
| You DO NOT | Hard negatives: never cross-write, never use `fallback_model: anthropic`, never invoke deprecated skills |
| How saving works | Tell the agent that the deterministic hook already saved the message; its job is just to reply |

A good `SOUL.md` is 100–200 lines. It is the agent's constitution, loaded first every session.

---

## `auth.json` — credentials

```json
{
  "credential_pool": {
    "openai-codex": {
      "access_token": "...",
      "refresh_token": "...",
      "expires_at": "..."
    },
    "github-copilot": {
      "pat": "..."
    }
  }
}
```

- OpenAI Codex OAuth is obtained via `hermes auth add openai-codex --type oauth --no-browser` (device code flow). Covered by the ChatGPT Pro subscription.
- GitHub Copilot PAT is the auto-fallback when Codex tokens expire mid-flight.
- **Never** an `anthropic` block. Never.
- `chmod 600` the file. Store a canonical copy in 1Password (or your secret vault of choice) under `{{PROJECT_NAME}}: {{AGENT_NAME}}/auth.json`.

---

## Telegram `@BotFather` setup

1. Open Telegram, search for `@BotFather`.
2. `/newbot` → name (e.g. "Wiki Librarian") → username (`@{{TELEGRAM_BOT_HANDLE}}`).
3. Copy the token; paste into `.env` as `TELEGRAM_BOT_TOKEN=...`.
4. `/setprivacy` → Disable (lets the bot see group messages if needed; keep Enabled if private-DM-only).
5. `/setcommands` to advertise slash commands (optional).

Get your own Telegram user ID from `@userinfobot`. Put it in `.env` as `TELEGRAM_ALLOWED_USERS=<your_id>`. **The bot rejects every message from any other user.** This is the first of three boundary defenses.

---

## The deterministic save hook

This is the critical piece. Without it, the system degrades to "ask the LLM nicely to save the file" and drops 5–15% of messages.

**Trigger config** (`hooks/auto-save-inbox/HOOK.yaml`):
```yaml
event: agent:start
handler: handler.py
```

**What `handler.py` does** (no LLM calls inside):
1. Reads the **full** message body from `sessions/{session_id}.jsonl`. Do not use the 500-char `ctx` Hermes passes to skills — it is truncated.
2. Builds the inbox filename: `{YYYY-MM-DDThhmmss}-{tg_message_id}.md` or similar.
3. Writes YAML frontmatter + body atomically via `pathlib`.
4. If voice: copies the most recent `~/.hermes/audio_cache/*.ogg` into `{{VAULT_NAME}}/raw/assets/` and links from the inbox file.
5. If image: copies the most recent `~/.hermes/image_cache/*.jpg` similarly.
6. If the message contains a Google Drive folder URL (regex): spawns `{{OPS_REPO}}/drive-ingest.sh {{VAULT_NAME}} <url>` detached via `subprocess.Popen(start_new_session=True)`.
7. Returns control to Hermes. The file is on disk before the LLM is invoked.

Sample file the hook writes:

```markdown
---
source: telegram
tg_message_id: 12345
chat_id: -100xxxxx
sender: {{TELEGRAM_USER_ID}}
date: 2026-04-17T15:30:42+08:00
attachments: []
---

{message body — multiline markdown, URLs, whatever the user typed}
```

**Never** put LLM calls inside `handler.py`. Filesystem + regex + subprocess only. The moment you introduce an LLM, you lose the determinism guarantee.

---

## Filesystem-boundary enforcement — defence in depth

One bot writes to one vault. Enforce this at **three** layers:

| Layer | What it does | Failure behaviour |
|---|---|---|
| `SOUL.md` | Explicit rules: "WRITE only to {{VAULT_NAME}}/raw/inbox; never touch sister vaults" | LLM respects — most of the time |
| `config.yaml` `allowed_write_paths` | Hermes refuses filesystem tools outside the allowed list | Tool call fails, LLM retries elsewhere |
| `handler.py` | Hardcodes the exact inbox path | Even a jailbroken LLM cannot write elsewhere via the hook |

All three must point at the same vault. Reviewing a new agent: grep for the vault name in all three files; count should match.

---

## Cross-vault read-only pattern

Sometimes one agent needs to answer "what do I know about X across all my contexts?" — personal + business + research. Allow cross-vault **reads** without allowing **writes**:

1. `config.yaml` `allowed_read_paths` includes the sister vaults' `wiki/` directories (not `raw/`).
2. `SOUL.md` documents which vaults are READ-ONLY and what to do on a CAPTURE attempt targeting a sister vault:
   > "Sounds operational — message @SisterLibrarianBot" (redirect, do not save).
3. A `query-vault` skill iterates the allowed read paths and cites each fact back to its source vault (so the user knows which vault each answer came from).
4. NDA/cultural-review flags on pages in sister vaults are respected — never quote `cultural_review: pending` content verbatim.

Rule: the hook's hardcoded write path is still the only WRITE path. Reads are wide; writes are narrow.

---

## Gateway + launchd

Launchd keeps the Telegram gateway alive with `KeepAlive=true`. Minimal plist:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>{{LAUNCHD_PREFIX}}.librarian.{{AGENT_NAME}}</string>
  <key>WorkingDirectory</key>
  <string>{{LOCAL_ROOT}}/agents/{{AGENT_NAME}}</string>
  <key>ProgramArguments</key>
  <array>
    <string>{{LOCAL_ROOT}}/agents/{{AGENT_NAME}}/scripts/start.sh</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HERMES_HOME</key>
    <string>{{LOCAL_ROOT}}/agents/{{AGENT_NAME}}</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>{{LOCAL_ROOT}}/_ops/logs/librarian-{{AGENT_NAME}}.out.log</string>
  <key>StandardErrorPath</key>
  <string>{{LOCAL_ROOT}}/_ops/logs/librarian-{{AGENT_NAME}}.err.log</string>
</dict>
</plist>
```

Symlink to `~/Library/LaunchAgents/` and `launchctl load -w`:

```bash
ln -sf {{LOCAL_ROOT}}/_ops/launchd/{{LAUNCHD_PREFIX}}.librarian.{{AGENT_NAME}}.plist \
       ~/Library/LaunchAgents/
launchctl load -w ~/Library/LaunchAgents/{{LAUNCHD_PREFIX}}.librarian.{{AGENT_NAME}}.plist
```

`KeepAlive=true` → launchd auto-restarts the gateway within ~30s of any crash.

---

## Smoke test

1. `launchctl list | grep {{AGENT_NAME}}` → one line, PID > 0.
2. Message the bot "hi" on Telegram → reply within ~30s.
3. Drop a test capture: "Met David Chen today — interested in AI voice agents." Expect:
   - A file at `{{VAULT_NAME}}/raw/inbox/{ts}-{msg_id}.md` within seconds.
   - Reply in Telegram confirming the save.
   - Next scheduled ingest creates `entities/people/david-chen.md` + a decision or atom.
4. `tail {{OPS_REPO}}/logs/librarian-{{AGENT_NAME}}.out.log` — should show the `agent:start` hook firing.

If the inbox file does not appear, your hook is broken. Do not ship without the hook working.

---

## Cost estimate

Per active agent, with Whisper voice + Vision on images:

| Component | Daily cost |
|---|---|
| Hermes GPT-5.4-mini chat (with prompt caching) | \$0.50–2.00 |
| Whisper voice (~\$0.006/min) | \$0.10 |
| Vision (images) | \$0.01–0.03/image |
| Subtotal per agent | **\$1.50–6.00** |

Multiply by number of agents. Downshift to `gpt-5.4-nano` in `smart_routing.cheap_model` to drop cost ~5× with minor quality hit.

---

## Cross-references

- [`01-architecture.md`](01-architecture.md) — where this agent sits in the triangle
- [`02-vault-setup.md`](02-vault-setup.md) — the vault this agent writes into
- [`04-github-backup.md`](04-github-backup.md) — this repo is backed up nightly at 03:33
- [`05-oauth-split.md`](05-oauth-split.md) — why no `fallback_model: anthropic`
- [`06-ai-onboarding-readme.md`](06-ai-onboarding-readme.md) — writing this repo's README

---

## If you're an AI agent reading this

1. **Keep `handler.py` deterministic.** No LLM calls inside. Filesystem, regex, subprocess only. If you need LLM reasoning on a message, do it *after* the save.
2. **Never add `fallback_model: anthropic` to `config.yaml`.** Anthropic OAuth is reserved for the `claude -p` ingest pipeline in `{{OPS_REPO}}` — putting it inside Hermes violates TOS.
3. **One agent = one vault for writes.** Cross-vault reads are fine when explicitly allowed in `config.yaml` + `SOUL.md`; cross-vault writes are never allowed. Redirect the user to the sister bot instead.

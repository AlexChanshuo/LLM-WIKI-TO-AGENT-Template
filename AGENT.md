# AGENT.md — Prime Directive for the Claude Code Instance

> **You are a Claude Code instance.** A human has just opened this template in your session and is asking you to bootstrap a new (Obsidian vault + Hermes Telegram librarian + paranoid backup) stack. This file is your playbook. Read it in full before doing anything else.

---

## Read these first (deep pattern understanding)

For a basic bootstrap, this file plus `CLAUDE.md` is enough — skip ahead to "Your role."

For anything else — if the human is asking you to deviate from the pattern, critique it, extend it, port it elsewhere, or resolve an ambiguity in routing / schema / operations — read the origin documents first, in this order:

- [`docs/research/sources/karpathy-2026-04-03-llm-wiki.md`](./docs/research/sources/karpathy-2026-04-03-llm-wiki.md) — **canonical primary source.** Karpathy's "LLM Wiki" gist. The whole template descends from this one file.
- [`docs/research/sources/hoeem_full_course.txt`](./docs/research/sources/hoeem_full_course.txt) — @hooeem's X course, the operator manual that turned the gist into shippable practice.
- [`docs/research/sources/defileo_claude_obsidian.txt`](./docs/research/sources/defileo_claude_obsidian.txt) — @defileo's X thread, the command cookbook.
- [`docs/research/SYNTHESIS.md`](./docs/research/SYNTHESIS.md) — one-page condensed view with signal ranking.

Karpathy set the pattern; the community threads turned it into practice. If your proposed change contradicts the gist, the burden of proof is on the change.

---

## Your role

You are the implementation agent. The human owns the decisions — what to call things, what domain to cover, what Telegram bot handle to use. You own:

- Asking the right questions to fill in the placeholders.
- Scaffolding the three target repos from `templates/`.
- Wiring up launchd, git, and keychain correctly on the first try.
- Enforcing the hard NEVER rules below, even if the human asks you to cut a corner.

If a decision is reversible and low-cost, just make it and tell the human. If it is irreversible (writing secrets, pushing to GitHub, loading a launchd plist), confirm first.

---

## Your mental model

Three ideas, in order:

### 1. Karpathy's three-layer pattern

```
raw/  -->  LLM reads, never writes.          (articles, voice, clips, PDFs)
wiki/ <--  LLM writes, human reads.          (entities, concepts, syntheses)
CLAUDE.md   The schema. The LLM's job desc.  (routing, frontmatter, lints)
```

Four cycles run across this: **ingest**, **compile**, **query**, **lint**. Every agent slash command and every launchd job maps to one of those four.

### 2. Deterministic vs generative split

The single most important architectural decision: **file writes that MUST happen belong in Python hooks or shell scripts, not in LLM tool calls.** LLMs hallucinate, refuse, and time out. If the act of saving a Telegram message depends on an LLM deciding to call the write tool, you will lose ~5-15% of messages over time.

The pattern:
- **Hermes `agent:start` Python hook** writes the inbox file deterministically before the LLM even sees the message.
- **`run-ingest.sh` shell script** calls `claude -p` for classification — then the shell does the commit and push.
- **`daily-backup.sh` shell script** does the backup; no LLM involved.

The LLM's job is narrow: understand the user, compose a good reply.

### 3. Anthropic TOS split

- Claude runs **only** inside the official `claude -p` CLI, authenticated via `CLAUDE_CODE_OAUTH_TOKEN` pulled from the macOS keychain at runtime.
- Claude **never** runs inside Hermes or any other third-party agent framework. This is a TOS requirement enforced by Anthropic since Apr 2026.
- The Hermes librarian does its chat via **ChatGPT through OpenAI Codex OAuth** (covered by the user's ChatGPT Pro subscription). That is TOS-compliant.
- Net effect: classification is Claude (rigorous, schema-aware); chat is ChatGPT (cheap, friendly, fast); no TOS violations.

Never add `fallback_model: anthropic` to any Hermes `config.yaml`. Never wrap a `claude -p` call inside a Hermes skill.

---

## What the user will ask you

Most common opening messages, roughly in order of likelihood:

1. "Walk me through `AGENT.md` — bootstrap the full stack."
2. "I already have a vault; just add the agent and backup."
3. "Only scaffold the vault; I'll handle Telegram later."
4. "I want two vaults, not one."

For anything except #1, confirm scope with the human, write a short plan to a scratch note, and execute. This document focuses on the full happy path.

---

## The end state you are building towards

```
{{LOCAL_ROOT}}/
├── {{VAULT_NAME}}/                    GitHub: {{GITHUB_USER}}/{{VAULT_REPO}}
│   ├── CLAUDE.md                      (schema — routing, frontmatter, examples)
│   ├── README.md                      (vault README with AI-agent onboarding section)
│   ├── raw/
│   │   ├── inbox/                     (Hermes drops files here)
│   │   ├── articles/                  (Web Clipper drops here)
│   │   ├── transcripts/
│   │   ├── docs/
│   │   └── assets/
│   ├── wiki/
│   │   ├── index.md
│   │   ├── log.md
│   │   ├── entities/{people,companies,tools,books,places}/
│   │   ├── concepts/{projects,areas,resources,atoms,frameworks,archive}/
│   │   ├── sources/
│   │   ├── syntheses/{decisions,meetings,reflections,reading-notes}/
│   │   └── outputs/
│   ├── templates/
│   ├── .claude/commands/              (/wiki-classify, /wiki-ingest, /wiki-query, /wiki-lint)
│   ├── .gitignore
│   └── .obsidian/community-plugins.json (seed list)
│
├── agents/
│   └── {{AGENT_NAME}}/                GitHub: {{GITHUB_USER}}/{{AGENT_REPO}}
│       ├── README.md
│       ├── SOUL.md                    (personality contract)
│       ├── USER.md                    (user profile from agent's POV)
│       ├── MEMORY.md                  (memory index)
│       ├── config.yaml                (Hermes config: model routing, tools)
│       ├── .env.example               (commit this)
│       ├── .env                       (GITIGNORED — real secrets)
│       ├── auth.json                  (GITIGNORED — OpenAI Codex OAuth)
│       ├── .gitignore
│       ├── hooks/
│       │   └── auto-save-inbox/
│       │       ├── HOOK.yaml          (fires on agent:start)
│       │       └── handler.py         (deterministic Python)
│       ├── skills/                    (markdown skill files)
│       └── scripts/start.sh           (launchd entry point)
│
└── _ops/                              GitHub: {{GITHUB_USER}}/{{OPS_REPO}}
    ├── README.md
    ├── run-ingest.sh                  (keychain -> claude -p classify + ingest)
    ├── run-lint.sh                    (weekly claude -p lint)
    ├── scripts/daily-backup.sh        (paranoid backup of all 3 repos)
    ├── launchd/
    │   ├── {{LAUNCHD_PREFIX}}.librarian.{{AGENT_NAME}}.plist   (KeepAlive)
    │   ├── {{LAUNCHD_PREFIX}}.wiki-watcher.{{VAULT_NAME}}.plist (2x/day)
    │   ├── {{LAUNCHD_PREFIX}}.wiki-lint.{{VAULT_NAME}}.plist    (weekly)
    │   └── {{LAUNCHD_PREFIX}}.daily-backup.plist               (daily 03:33)
    ├── docs/
    │   ├── SETUP.md
    │   ├── SETUP-AGENTS.md
    │   └── RESTORE.md
    └── logs/                          (GITIGNORED)
```

Three repos. Four launchd jobs. One nightly push. One capture loop.

---

## Your step-by-step playbook

Execute in order. Stop and confirm before each irreversible step.

### Step 1 — Discover intent

Ask the human, as ONE message:

> Before I scaffold anything I need six things:
> 1. Project name (short, lowercase, hyphenated) — `{{PROJECT_NAME}}`
> 2. Vault name (same style) — `{{VAULT_NAME}}`
> 3. Agent name (same style) — `{{AGENT_NAME}}`
> 4. Your GitHub username — `{{GITHUB_USER}}`
> 5. Telegram bot handle (or "later" if you haven't made one yet) — `{{TELEGRAM_BOT_HANDLE}}`
> 6. A one-sentence description of the knowledge domain — `{{DOMAIN_DESCRIPTION}}`
>
> Also: where should the local root live? Default `~/Documents/{{PROJECT_NAME}}` — confirm or override — `{{LOCAL_ROOT}}`.

Wait for all six. Do not guess.

Then derive:
- `{{VAULT_REPO}}` = `{{VAULT_NAME}}` (or ask if they want a different repo name)
- `{{AGENT_REPO}}` = `{{AGENT_NAME}}`
- `{{OPS_REPO}}` = `{{PROJECT_NAME}}-ops`
- `{{LAUNCHD_PREFIX}}` = `com.{{GITHUB_USER}}.{{PROJECT_NAME}}` (lowercased, dots allowed)
- `{{HOME_USER}}` = output of `whoami` on the macOS box where the template is being run (used in plist `PATH` and shell scripts for `~/.local/bin` resolution).

Echo all resolved values back and ask for one `yes` before proceeding.

### Step 2 — Fill placeholders

Every file under `templates/` contains `{{UPPER_SNAKE}}` tokens. Do a global substitution using a deterministic script (not an LLM tool loop — write a shell one-liner or small Python script). Confirm with `grep -r '{{' {{LOCAL_ROOT}}/` afterwards; any remaining matches are either an unknown token or a literal `{{ }}` in code.

### Step 3 — Scaffold the vault

1. `mkdir -p {{LOCAL_ROOT}}/{{VAULT_NAME}}` and copy `templates/vault/` into it.
2. Fill `CLAUDE.md` with the human's `{{DOMAIN_DESCRIPTION}}` and the starter routing table — show them the routing table and invite edits before writing the final version.
3. `git init -b main`, add remote for `git@github.com:{{GITHUB_USER}}/{{VAULT_REPO}}.git`.
4. Create the GitHub repo (private) with `gh repo create {{GITHUB_USER}}/{{VAULT_REPO}} --private`.
5. Initial commit + push.

### Step 4 — Scaffold the agent

1. `mkdir -p {{LOCAL_ROOT}}/agents/{{AGENT_NAME}}` and copy `templates/agent/` into it.
2. Write `SOUL.md` with the agent's personality — derived from the domain description. Confirm the voice with the human before finalizing.
3. Ensure `.gitignore` covers `.env`, `auth.json`, `sessions/`, `memories/`, `state.db`, `gateway.pid`, `gateway_state.json`, `platforms/`, `logs/`.
4. Write `.env.example` with blank values; tell the human to later populate `.env` from the Telegram BotFather output and their OpenAI key.
5. Write `config.yaml` with:
   - `model.default` = ChatGPT via `openai-codex` provider.
   - No `fallback_model: anthropic`.
   - Allowed tools restricted; filesystem scoped to vault path only.
6. Verify `hooks/auto-save-inbox/handler.py` references the correct vault path.
7. `git init`, create repo, initial commit, push.

### Step 5 — Scaffold ops

1. `mkdir -p {{LOCAL_ROOT}}/_ops` and copy `templates/ops/` into it.
2. `chmod +x` every `.sh` script.
3. Confirm `run-ingest.sh` pulls the OAuth token from keychain with `security find-generic-password -s "Claude Code-credentials" -w`.
4. Confirm `daily-backup.sh` iterates over all three repos, has the lockfile logic, the bulk-delete tripwire (>20 deletions aborts that repo), the `git pull --rebase --autostash` before push, and **never** uses `--force`, `--hard`, or `--amend`.
5. `git init`, create repo, initial commit, push.

### Step 6 — Set up launchd

1. Generate 4 plists from `templates/launchd/*.plist` with `{{LAUNCHD_PREFIX}}` and absolute paths substituted.
2. Pick off-hour times: `03:33` for backup; `08:17` + `20:43` for ingest; `Sunday 09:17` for lint. Never use clean hours.
3. Symlink each into `~/Library/LaunchAgents/`.
4. `launchctl load -w ~/Library/LaunchAgents/{{LAUNCHD_PREFIX}}.*.plist` for each.
5. Verify with `launchctl list | grep {{LAUNCHD_PREFIX}}` — expect 4 entries.

### Step 7 — First backup

Don't wait for 03:33. Manually run the backup once to catch scaffolding errors:

```bash
{{LOCAL_ROOT}}/_ops/scripts/daily-backup.sh
tail -n 50 {{LOCAL_ROOT}}/_ops/logs/daily-backup.log
```

Expect three "push ok" lines. If any repo fails, diagnose and fix before moving on.

### Step 8 — Verify

Smoke test checklist, run with the human:

- [ ] Each of the three GitHub repos shows the initial commit.
- [ ] `launchctl list | grep {{LAUNCHD_PREFIX}}` shows 4 jobs.
- [ ] Message the Telegram bot "hi" — reply arrives within 30 seconds.
- [ ] A test file appears in `{{LOCAL_ROOT}}/{{VAULT_NAME}}/raw/inbox/`.
- [ ] Manually run `{{LOCAL_ROOT}}/_ops/run-ingest.sh {{VAULT_NAME}}` — Claude classification runs, wiki pages created, git commit pushed.
- [ ] `tail -n 20 {{LOCAL_ROOT}}/_ops/logs/daily-backup.log` shows the Step 7 run.

If all six pass, the stack is live. Hand off.

---

## Hard NEVER rules

Compiled from the root instructions. These apply at every step.

1. **NEVER `git push --force`.** Not once. Not for "just this one weird case."
2. **NEVER `git reset --hard`** anywhere in scaffolding or backup scripts.
3. **NEVER `git commit --amend`.** Every backup is a fresh commit with a timestamp.
4. **NEVER remove the bulk-delete tripwire** from `daily-backup.sh`. >20 deletions aborts that repo.
5. **NEVER skip the per-repo lockfile** (atomic `mkdir`). It prevents concurrent runs from colliding.
6. **NEVER put Anthropic OAuth inside Hermes.** No `fallback_model: anthropic`, no `claude -p` shelled out from inside a Hermes skill.
7. **NEVER let the LLM decide whether to save an inbox file.** The Python hook writes it before the LLM sees the message.
8. **NEVER commit secrets.** `.env`, `auth.json`, service-account JSON files are gitignored. Canonical copies live in the user's secret vault (1Password or equivalent).
9. **NEVER schedule on clean-hour times** like 03:00, 08:00, 20:00. Use 03:33, 08:17, 20:43 — dodges API thundering-herd and keychain contention.
10. **NEVER write a README without a numbered "If you're an AI agent reading this" section** with explicit NEVERs.
11. **NEVER proceed past Step 1 without confirmation.** The placeholders are load-bearing; a typo at Step 1 propagates into launchd plist filenames and GitHub repo names.
12. **NEVER use emojis in any committed file.**
13. **NEVER write customer-facing output in a non-English language unless explicitly asked.** Repo docs stay English-only.

---

## Where to look in this repo

| You need… | File |
|---|---|
| The human onboarding doc | `README.md` |
| The human linear setup walkthrough | `SETUP.md` |
| The session-start rules Claude auto-loads | `CLAUDE.md` |
| Your playbook (this file) | `AGENT.md` |
| A worked example | `examples/minimal-walkthrough.md` |
| Vault skeleton to copy | `templates/vault/` |
| Agent skeleton to copy | `templates/agent/` |
| Ops skeleton to copy | `templates/ops/` |
| launchd plist templates | `templates/launchd/` |
| Karpathy pattern explainer | `docs/pattern-overview.md` |
| Backup safety deep-dive | `docs/backup-safety.md` |
| Anthropic TOS explainer | `docs/tos-split.md` |

If a `docs/` file referenced above does not yet exist in your instance, note it and proceed using the content in this file and `CLAUDE.md` as authoritative. Do not block on missing explainers.

---

## Your first message to the user

After reading this file, your opening should be short. Example:

> I've read `AGENT.md`. Before I scaffold anything I need six things from you:
> 1. Project name (short, lowercase, hyphenated)
> 2. Vault name
> 3. Agent name
> 4. Your GitHub username
> 5. Telegram bot handle (or "later")
> 6. One-sentence domain description
>
> Also: where should the local root live? Default `~/Documents/{{PROJECT_NAME}}`.

Then wait.

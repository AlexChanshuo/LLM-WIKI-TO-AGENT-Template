# Worked example — Alice bootstraps `alice-notes` + `shelf-bot`

A concrete run-through. Alice is a product manager. She wants a personal knowledge vault for product-research notes and a Telegram bot that captures quick thoughts throughout the day. This document walks through exactly what she does, what placeholders she picks, what directory tree she ends up with, and the 5 commands she runs.

---

## Her inputs

When Claude Code prompts her at Step 1 of `AGENT.md`, she answers:

| Token | Value |
|---|---|
| `{{PROJECT_NAME}}` | `alice-brain` |
| `{{GITHUB_USER}}` | `alice-chen` |
| `{{VAULT_NAME}}` | `alice-notes` |
| `{{VAULT_REPO}}` | `alice-notes` |
| `{{AGENT_NAME}}` | `shelf-bot` |
| `{{AGENT_REPO}}` | `shelf-bot` |
| `{{OPS_REPO}}` | `alice-brain-ops` |
| `{{TELEGRAM_BOT_HANDLE}}` | `@shelfbot_alice` |
| `{{DOMAIN_DESCRIPTION}}` | `Alice's product-research, customer-interview, and founder-reading notes` |
| `{{LAUNCHD_PREFIX}}` | `com.alice-chen.alice-brain` |
| `{{LOCAL_ROOT}}` | `/Users/alice/Documents/alice-brain` |

---

## Substitution

Claude Code runs a single substitution pass across `templates/`. A snippet of before/after:

**Before (in `templates/ops/launchd/daily-backup.plist`):**

```xml
<key>Label</key>
<string>{{LAUNCHD_PREFIX}}.daily-backup</string>
<key>ProgramArguments</key>
<array>
  <string>{{LOCAL_ROOT}}/_ops/scripts/daily-backup.sh</string>
</array>
```

**After:**

```xml
<key>Label</key>
<string>com.alice-chen.alice-brain.daily-backup</string>
<key>ProgramArguments</key>
<array>
  <string>/Users/alice/Documents/alice-brain/_ops/scripts/daily-backup.sh</string>
</array>
```

After the pass, `grep -r '{{' /Users/alice/Documents/alice-brain/` returns zero matches. All placeholders resolved.

---

## Resulting directory tree

```
/Users/alice/Documents/alice-brain/
├── alice-notes/                            (GitHub: alice-chen/alice-notes, private)
│   ├── CLAUDE.md
│   ├── README.md
│   ├── raw/
│   │   ├── inbox/
│   │   ├── articles/
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
│   ├── .claude/commands/
│   │   ├── wiki-classify.md
│   │   ├── wiki-ingest.md
│   │   ├── wiki-query.md
│   │   └── wiki-lint.md
│   └── .gitignore
│
├── agents/
│   └── shelf-bot/                          (GitHub: alice-chen/shelf-bot, private)
│       ├── README.md
│       ├── SOUL.md
│       ├── USER.md
│       ├── MEMORY.md
│       ├── config.yaml
│       ├── .env.example
│       ├── .env                            (gitignored; mode 600)
│       ├── auth.json                       (gitignored; mode 600)
│       ├── .gitignore
│       ├── hooks/
│       │   └── auto-save-inbox/
│       │       ├── HOOK.yaml
│       │       └── handler.py
│       ├── skills/
│       └── scripts/
│           └── start.sh
│
└── _ops/                                   (GitHub: alice-chen/alice-brain-ops, private)
    ├── README.md
    ├── run-ingest.sh
    ├── run-lint.sh
    ├── scripts/
    │   └── daily-backup.sh
    ├── launchd/
    │   ├── com.alice-chen.alice-brain.librarian.shelf-bot.plist
    │   ├── com.alice-chen.alice-brain.wiki-watcher.alice-notes.plist
    │   ├── com.alice-chen.alice-brain.wiki-lint.alice-notes.plist
    │   └── com.alice-chen.alice-brain.daily-backup.plist
    ├── docs/
    │   ├── SETUP.md
    │   ├── SETUP-AGENTS.md
    │   └── RESTORE.md
    └── logs/                               (gitignored)
```

Three repos. Four launchd jobs. Everything at absolute paths under `/Users/alice/Documents/alice-brain/`.

---

## Alice's 5 commands

Everything else Claude Code does for her. These five are the ones she types herself.

### 1. Clone the template

```bash
cd ~/Documents
git clone https://github.com/<template-location>.git alice-brain/LLM-WIKI-TO-AGENT-Template
cd alice-brain/LLM-WIKI-TO-AGENT-Template
```

### 2. Open Claude Code and kick off the playbook

```bash
claude
```

Then in the Claude Code prompt:

```
walk me through AGENT.md — bootstrap the full stack
```

She answers the six questions from the table above. Claude does the rest: substitution, scaffold, `gh repo create`, initial commits, initial push, plist generation. She sits through a few `yes` confirmations.

### 3. Populate `.env` with her Telegram credentials

She creates the Telegram bot via `@BotFather`, gets her user ID via `@userinfobot`, then:

```bash
cd ~/Documents/alice-brain/agents/shelf-bot
cp .env.example .env
$EDITOR .env        # fills in TELEGRAM_BOT_TOKEN, TELEGRAM_ALLOWED_USERS, OPENAI_API_KEY
chmod 600 .env
```

### 4. Authorize OpenAI Codex OAuth for the librarian

```bash
HERMES_HOME=$(pwd) hermes auth add openai-codex --type oauth --no-browser
chmod 600 auth.json
```

Follows the device-code flow, signs in with her ChatGPT Pro account.

### 5. Trigger the first manual backup to verify everything is wired up

```bash
~/Documents/alice-brain/_ops/scripts/daily-backup.sh
tail -n 50 ~/Documents/alice-brain/_ops/logs/daily-backup.log
```

Expects three `push ok` lines. Then she messages `@shelfbot_alice` with "hi" on Telegram, gets a reply, sends a test note, and watches it flow through `raw/inbox/` into `wiki/entities/` at the next `run-ingest.sh` invocation.

---

## The launchd schedule Alice ends up with

Claude picked off-hour times automatically. None of these are at clean hours.

| Job | Schedule | What it does |
|---|---|---|
| `com.alice-chen.alice-brain.librarian.shelf-bot` | always-on (KeepAlive) | Hermes gateway for `@shelfbot_alice` |
| `com.alice-chen.alice-brain.wiki-watcher.alice-notes` | 08:17 and 20:43 daily | `run-ingest.sh alice-notes` — Claude classifies + ingests |
| `com.alice-chen.alice-brain.wiki-lint.alice-notes` | Sunday 09:17 | `run-lint.sh alice-notes` — weekly health check |
| `com.alice-chen.alice-brain.daily-backup` | 03:33 daily | `daily-backup.sh` — paranoid backup of all 3 repos |

---

## What she hasn't done yet (and that's fine)

- No Obsidian Web Clipper template yet — she'll set that up when she starts clipping articles.
- No Google Drive ingestion — not in the template's minimum scope; she can add later.
- No SOUL.md customization — she'll tune the bot's voice after living with the default for a week.
- No 1Password copies of `.env` / `auth.json` — **she does this today.** That's not optional; RESTORE.md depends on it.

---

## What her first Telegram exchange looks like

```
Alice → @shelfbot_alice:
  Interviewed Jordan at Spectra today. He hates their current analytics tool —
  too many steps to pull a cohort. Said he'd switch in a heartbeat if something
  fixed that one workflow.

@shelfbot_alice → Alice:
  Saved. I'll have Claude pick it up at tonight's ingest (20:43). If you want
  it processed now, run `run-ingest.sh alice-notes` from ops.
```

By 20:43, the launchd job fires. By 20:44, `alice-notes/wiki/entities/people/jordan.md` exists with a dated note section, `alice-notes/wiki/entities/companies/spectra.md` has been created or updated, and a source summary lands in `alice-notes/wiki/sources/inbox-summaries/{date}-interview-jordan-spectra.md`. A git commit is pushed to `alice-chen/alice-notes`.

By 03:33 the next morning, the daily-backup.sh run commits any hand-edits Alice made in Obsidian and pushes those too.

The loop is closed.

---

## Where to go from here

- Read `AGENT.md` for the exact step-by-step Claude follows.
- Read `SETUP.md` if you want to do any step manually.
- Edit `{{VAULT_NAME}}/CLAUDE.md` after the first 30 messages — that's when your routing table needs its first tuning pass.

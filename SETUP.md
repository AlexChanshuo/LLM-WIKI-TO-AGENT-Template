# SETUP.md — Human walkthrough

> "I just cloned this template. Talk me through it." A linear, numbered setup guide. Assumes macOS + Obsidian + Claude Code + a Telegram account + `gh` CLI. Total time: 45-90 minutes depending on how much you delegate to Claude Code.

If you prefer to let the agent drive, skip to step 3 — open the folder in Claude Code and say "walk me through AGENT.md". Otherwise, follow along below.

---

## 0. Prerequisites check (5 min)

Run each of these. Any failure → install the tool before proceeding.

```bash
sw_vers                                   # macOS version (Sonoma+ recommended)
git --version                             # git 2.40+
gh --version && gh auth status            # gh CLI, authenticated
which claude                              # Claude Code CLI on PATH
claude --version
uv --version                              # brew install uv
which hermes || echo "install Hermes"     # from hermes-agent.nousresearch.com
ls /Applications/Obsidian.app             # Obsidian installed
```

Also confirm:

- Claude Code subscription is active (Pro or higher) — open the Claude Code app once so the macOS keychain entry `Claude Code-credentials` is created.
- You can reach https://t.me/BotFather in Telegram.
- A secret vault to keep secrets out of git (1Password or equivalent). **Do not skip this.** Every credential this template produces goes into it.

---

## 1. Clone this template (1 min)

Pick where the project will live. The rest of this guide uses `{{LOCAL_ROOT}}`. A sensible default:

```bash
export LOCAL_ROOT="$HOME/Documents/{{PROJECT_NAME}}"
mkdir -p "$LOCAL_ROOT"
cd "$LOCAL_ROOT"

git clone https://github.com/<wherever-this-template-lives>.git LLM-WIKI-TO-AGENT-Template
cd LLM-WIKI-TO-AGENT-Template
```

You are now inside the template. Nothing you do here is pushed anywhere — all `git` commands later target the three NEW repos you are about to create.

---

## 2. Choose your placeholder values (5 min)

Write these down before you start Claude Code — it will ask for all of them.

| Token | What you need to decide | Rule of thumb |
|---|---|---|
| `{{PROJECT_NAME}}` | Short lowercase hyphenated project slug | `alice-brain`, `mybrain`, `research-vault` |
| `{{GITHUB_USER}}` | Your GitHub username or org | `alice-chen` |
| `{{VAULT_NAME}}` | Vault directory name | often same as project, e.g. `alice-notes` |
| `{{VAULT_REPO}}` | Vault repo name on GitHub | usually matches `{{VAULT_NAME}}` |
| `{{AGENT_NAME}}` | Librarian agent name | picks its Telegram personality, e.g. `shelf-bot` |
| `{{AGENT_REPO}}` | Agent repo name | usually matches `{{AGENT_NAME}}` |
| `{{OPS_REPO}}` | Ops backbone repo | `{{PROJECT_NAME}}-ops` |
| `{{TELEGRAM_BOT_HANDLE}}` | `@handle` from BotFather | you'll create this in step 5 |
| `{{DOMAIN_DESCRIPTION}}` | One sentence on the vault's purpose | "Alice's product-research and interview notes" |
| `{{LAUNCHD_PREFIX}}` | launchd dot-prefix | `com.<your-username>.{{PROJECT_NAME}}` |
| `{{HOME_USER}}` | macOS short username (derived from `whoami`; not asked) | `alice` |

Keep this table open. You will reference it repeatedly.

---

## 3. Open in Claude Code and run the agent playbook (20-60 min)

```bash
cd "$LOCAL_ROOT/LLM-WIKI-TO-AGENT-Template"
claude
```

Then type:

```
walk me through AGENT.md — bootstrap the full stack
```

Claude Code will:

1. Ask for the six placeholders from the table above.
2. Derive the rest (`{{OPS_REPO}}`, `{{LAUNCHD_PREFIX}}`, etc.) and echo them back for confirmation.
3. Substitute placeholders across `templates/`.
4. Scaffold the vault, the agent, and the ops backbone into `{{LOCAL_ROOT}}/`.
5. Create three private GitHub repos via `gh` and push initial commits.
6. Generate the four launchd plists with off-hour schedule times.
7. Pause before loading the launchd jobs — you get one last confirmation.
8. Run a first manual backup to catch scaffolding errors early.
9. Hand off with a smoke-test checklist.

If you prefer to do any step manually, tell Claude. The playbook in `AGENT.md` lists each step atomically.

---

## 4. Populate secrets (10 min)

Claude cannot write secrets for you safely. Do this yourself once scaffolding finishes.

### 4a. Create the Telegram bot

1. Open Telegram → search `@BotFather`.
2. `/newbot` → answer the prompts. Pick a display name and a handle like `{{AGENT_NAME}}_bot`. Record the handle as `{{TELEGRAM_BOT_HANDLE}}`.
3. BotFather returns a token like `1234567890:ABC...`. Copy it.

### 4b. Get your Telegram user ID

1. In Telegram, search `@userinfobot` → press Start.
2. It replies with your numeric user ID. Copy.

### 4c. Populate `.env`

```bash
cd "$LOCAL_ROOT/agents/{{AGENT_NAME}}"
cp .env.example .env
```

Edit `.env`:

```
TELEGRAM_BOT_TOKEN=<the token from 4a>
TELEGRAM_ALLOWED_USERS=<the user ID from 4b>
OPENAI_API_KEY=<optional, for Whisper voice transcription>
OBSIDIAN_VAULT_PATH={{LOCAL_ROOT}}/{{VAULT_NAME}}
```

```bash
chmod 600 .env
```

### 4d. Authorize OpenAI Codex OAuth (for Hermes chat)

```bash
cd "$LOCAL_ROOT/agents/{{AGENT_NAME}}"
HERMES_HOME=$(pwd) hermes auth add openai-codex --type oauth --no-browser
```

Follow the URL + device code. This produces `auth.json`.

```bash
chmod 600 auth.json
```

### 4e. Save copies in your secret vault

Create these items in 1Password (or equivalent):

- `{{PROJECT_NAME}}: {{AGENT_NAME}}/.env` (paste contents of `.env`)
- `{{PROJECT_NAME}}: {{AGENT_NAME}}/auth.json` (paste contents of `auth.json`)

These copies are what rebuild the system on a fresh Mac. `_ops/docs/RESTORE.md` will reference them.

---

## 5. First manual runs (5 min)

### 5a. Start the librarian and smoke test

```bash
launchctl list | grep {{LAUNCHD_PREFIX}}
```

Expect four lines. If the librarian line shows `-` for PID, load it manually:

```bash
launchctl load -w ~/Library/LaunchAgents/{{LAUNCHD_PREFIX}}.librarian.{{AGENT_NAME}}.plist
```

Message the bot "hi" on Telegram. Expect a reply within 30 seconds. If not, tail logs:

```bash
tail -f "$LOCAL_ROOT/_ops/logs/librarian-{{AGENT_NAME}}.out.log"
tail -f "$LOCAL_ROOT/_ops/logs/librarian-{{AGENT_NAME}}.err.log"
```

### 5b. First wiki ingest

Send the bot a test message like:

> Met with Bob today from Acme. He's interested in our widget pilot. Decided to follow up Monday with a demo.

Check that a file landed in `{{LOCAL_ROOT}}/{{VAULT_NAME}}/raw/inbox/`. Then manually trigger the ingest without waiting for the 2x-daily launchd schedule:

```bash
"$LOCAL_ROOT/_ops/run-ingest.sh" {{VAULT_NAME}}
```

Expect Pass 1 (Haiku classify) and Pass 2 (Sonnet ingest) to run, new wiki pages to appear under `{{VAULT_NAME}}/wiki/entities/people/bob.md`, `wiki/entities/companies/acme.md`, and `wiki/syntheses/decisions/{YYYY-MM-DD}-followup-acme-demo.md`. A commit and push follow.

### 5c. First manual backup

```bash
"$LOCAL_ROOT/_ops/scripts/daily-backup.sh"
tail -n 50 "$LOCAL_ROOT/_ops/logs/daily-backup.log"
```

Expect three "push ok" lines (vault, agent, ops). If any repo shows the bulk-delete tripwire, stop — investigate before letting the 03:33 schedule touch it again.

---

## 6. Obsidian setup (10 min)

> For a fresh Mac that does not yet have Obsidian installed at all, follow [`docs/00-obsidian-new-mac-setup.md`](docs/00-obsidian-new-mac-setup.md) end-to-end — it is the authoritative install + configure walkthrough (Homebrew vs DMG, Gatekeeper, iCloud pitfalls, Web Clipper, round-trip verification). The summary below assumes Obsidian is already installed and you just need the plugin checklist for an existing vault.

1. Open Obsidian → vault switcher (bottom-left) → "Open folder as vault" → select `{{LOCAL_ROOT}}/{{VAULT_NAME}}`.
2. Settings → Community plugins → turn off Restricted Mode.
3. Install these plugins (Community Plugins → Browse):
   - Dataview
   - Templater
   - Obsidian Git
   - Local Images Plus
   - Linter
   - Homepage
4. Settings → Templater → Template folder = `templates`.
5. Settings → Homepage → Homepage = `wiki/index.md`.
6. Settings → Files & Links → Default location for new attachments = `In subfolder under current folder`, subfolder `assets`.
7. Obsidian Git settings: auto-pull on startup ON, auto-commit interval 0 (disabled — `_ops` handles pushes).

---

## 7. Confirm launchd schedule (2 min)

```bash
launchctl list | grep {{LAUNCHD_PREFIX}}
```

Expect four jobs. Preview a plist:

```bash
plutil -p ~/Library/LaunchAgents/{{LAUNCHD_PREFIX}}.daily-backup.plist | head -n 30
```

Confirm the `StartCalendarInterval` minute is 33 (not 0). If you see clean-hour times anywhere, stop and edit the plist — clean hours cause API thundering-herd issues.

---

## 8. Document your deployment (5 min)

Edit `_ops/docs/RESTORE.md` and replace the template boilerplate with your actual:

- Three repo names.
- Local paths.
- 1Password item names for each secret.
- Any optional pipelines you skipped (e.g. Whisper if no OpenAI key).

This is the file that rebuilds everything when the Mac dies. Keep it honest.

---

## 9. Hand-off checklist

Before you walk away, confirm:

- [ ] `launchctl list | grep {{LAUNCHD_PREFIX}}` shows 4 jobs.
- [ ] Telegram bot replies to "hi" within 30 seconds.
- [ ] A test message produced files in `raw/inbox/`, then in `wiki/`, then committed to GitHub.
- [ ] Manual backup pushed all three repos.
- [ ] `.env` and `auth.json` are both mode 600 and both saved in 1Password.
- [ ] `_ops/docs/RESTORE.md` is updated for your deployment.
- [ ] You have tested one disaster-recovery step (e.g. `rm -rf /tmp/test-clone && gh repo clone {{GITHUB_USER}}/{{VAULT_REPO}} /tmp/test-clone`).

At this point the system runs itself. Telegram messages flow in; classified wiki pages accumulate; 03:33 nightly backups fire; weekly lint surfaces overdue follow-ups.

---

## 10. What to do next (ongoing)

- Watch `wiki/outputs/triage-queue.md` for the first 30 messages — it tells you where your CLAUDE.md routing needs few-shot examples.
- Add Obsidian Web Clipper templates pointing at `raw/articles/` so browsed articles land in the vault.
- If you add Google Drive ingestion or calendar sync later, read the corresponding sections in `docs/pattern-overview.md` (if present) and extend `_ops/` — do not violate the backup paranoia rules.
- Quarterly: re-run one step of `_ops/docs/RESTORE.md` from a `/tmp/` directory to prove the recovery chain still works.

---

## Related reading

- `README.md` — top-level project pitch.
- `AGENT.md` — playbook the Claude Code instance is executing on your behalf.
- `CLAUDE.md` — hard rules and placeholder reference.
- `examples/minimal-walkthrough.md` — a full worked example you can read end to end.
- `templates/` — the skeletons the agent copies from.
- `docs/` — deep dives on individual components when present.

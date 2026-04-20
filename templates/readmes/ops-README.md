# {{OPS_REPO}} -- {{PROJECT_NAME}} Orchestration Layer

> **Repo on GitHub:** `{{GITHUB_USER}}/{{OPS_REPO}}` (private)
> **Mounted at:** `{{LOCAL_ROOT}}/{{OPS_REPO}}/`
> **Role:** Holds everything that is NOT a vault and NOT a librarian -- launchd plists, scripts, Drive client, daily backup, RESTORE runbook.
> **Self-backup:** This repo is also covered by its own `daily-backup.sh`.

---

## TL;DR (read this first)

`{{OPS_REPO}}` is the **orchestration backbone** of the {{PROJECT_NAME}} ecosystem. The Obsidian vaults store knowledge; the Hermes librarians capture it; **`{{OPS_REPO}}` is the glue that makes everything actually run on a Mac**:

- macOS launchd jobs (one per librarian for `KeepAlive`; one wiki-watcher per vault for classify + ingest; one wiki-lint per vault for weekly lint; one daily-backup; plus any project-specific syncs)
- The Claude wiki-ingest pipeline scripts (`run-ingest.sh`, `run-lint.sh`)
- Optional Google Drive folder ingestion client (`drive-fetch.py`, `drive-ingest.sh`)
- The safe daily-backup script (`scripts/daily-backup.sh`) that pushes ALL repos to GitHub
- The disaster-recovery runbook ([`docs/RESTORE.md`](./docs/RESTORE.md))
- Setup docs, research articles, plans

**One sentence:** *If a script, plist, log, or runbook is not an Obsidian vault and is not a Hermes agent, it lives here.*

---

## Where this repo sits in the ecosystem

```
                         +---- <vault-1> <---- <librarian-1>
  {{PROJECT_NAME}} -----+---- <vault-2> <---- <librarian-2>
                         +---- <vault-N> <---- <librarian-N>
                         +---- {{OPS_REPO}} (orchestration)   <- YOU ARE HERE
                                  ^
                                  | controls / serves all repos above
```

| Other repo | What `{{OPS_REPO}}` does for it |
|---|---|
| `<vault-1>` | Runs `wiki-ingest` 2x daily, `wiki-lint` weekly, includes in daily backup |
| `<vault-2>` | Same |
| `<vault-N>` | Same |
| `<librarian-1>` | Owns the launchd plist that keeps it alive; includes in daily backup |
| `<librarian-2>` | Same |
| `<librarian-N>` | Same |

This repo is the orchestration hub because the vaults and librarians cannot run themselves -- something has to schedule, supervise, fetch, classify, and back everything up.

---

## Why this repo exists

Three concrete problems it solves:

1. **The "things only run if you remember to run them" problem.** Without launchd plists, the wiki ingest pipeline would only fire when the user remembers to type `/wiki-ingest`. Without the daily-backup, repos drift uncommitted for weeks. The whole point of this repo: **automation, not vigilance.**
2. **The "fresh Mac, where do I start?" problem.** A Mac dies, gets stolen, or gets replaced. Without a single canonical RESTORE.md walkthrough, rebuilding the system is hours of guesswork. With it: clone, restore secrets, install Hermes, register launchd, re-pair Telegram, smoke-test. Total: under 2 hours.
3. **The "every repo references absolute paths" problem.** Librarian hooks call `{{OPS_REPO}}/drive-ingest.sh`. Launchd plists invoke `{{OPS_REPO}}/run-ingest.sh`. Vaults expect `{{OPS_REPO}}/docs/SETUP.md` to exist. Centralizing everything here makes the cross-repo dependency graph readable.

---

## Folder map

```
{{OPS_REPO}}/
|-- README.md                          <- you are here
|-- run-ingest.sh                      <- per-vault Claude classify + ingest (called by launchd 2x/day)
|-- run-lint.sh                        <- per-vault Claude lint (called by launchd weekly)
|-- drive-fetch.py                     <- Google Drive API client (optional)
|-- drive-ingest.sh                    <- orchestrator: drive-fetch -> claude wiki-ingest -> summary
|-- scripts/
|   +-- daily-backup.sh                <- safe nightly backup of ALL repos
|-- launchd/
|   |-- com.alexmind.librarian.<name>.plist     <- one per librarian (KeepAlive)
|   |-- com.alexmind.wiki-watcher.<vault>.plist <- one per vault (2x/day)
|   |-- com.alexmind.wiki-lint.<vault>.plist    <- one per vault (weekly)
|   +-- com.alexmind.daily-backup.plist         <- nightly backup
|-- docs/
|   |-- SETUP.md                       <- initial vault setup
|   |-- SETUP-AGENTS.md                <- initial Hermes librarian setup
|   +-- RESTORE.md                     <- DISASTER RECOVERY RUNBOOK (most critical doc)
|-- research/                          <- source articles informing architecture
|-- logs/                              <- gitignored -- all runtime logs
|-- drive-venv/                        <- gitignored -- Python venv for Drive client
+-- drive-creds/                       <- gitignored, chmod 700
    +-- service-account.json           <- Google Drive service account (canonical in 1Password)
```

---

## The launchd jobs

All registered as symlinks under `~/Library/LaunchAgents/com.alexmind.*.plist`. Verify with `launchctl list | grep alexmind`.

| Job | Schedule | What it does | Source |
|---|---|---|---|
| `com.alexmind.librarian.<name>` | Always-on (KeepAlive) | Runs a librarian Hermes gateway | `agents/<name>/scripts/start.sh` |
| `com.alexmind.wiki-watcher.<vault>` | 2x/day (off-hour, staggered) | Claude classify + ingest for a vault | `{{OPS_REPO}}/run-ingest.sh <vault>` |
| `com.alexmind.wiki-lint.<vault>` | Weekly (Sunday off-hour) | Claude lint pass on a vault | `{{OPS_REPO}}/run-lint.sh <vault>` |
| `com.alexmind.daily-backup` | Daily at an off-hour minute (e.g. 03:33) | Safe commit + push of ALL repos | `{{OPS_REPO}}/scripts/daily-backup.sh` |

Stagger times are intentionally off-hour (e.g. 08:17, 20:43, 03:33) to avoid integer-hour API thundering-herd patterns, keychain contention, and quota collisions. Never schedule on `HH:00`.

---

## The scripts

### `run-ingest.sh {vault}`

Triggered by the wiki-watcher launchd jobs 2x daily per vault. Steps:

1. Read Claude Code OAuth token from macOS keychain via `security find-generic-password -s "Claude Code-credentials"`.
2. Export `CLAUDE_CODE_OAUTH_TOKEN`.
3. Call `claude -p /wiki-classify` (Pass 1 -- Haiku classifies new inbox files).
4. Call `claude -p /wiki-ingest` (Pass 2 -- Sonnet writes structured wiki updates).
5. `git add -A && git commit -m "wiki ingest {date}" && git push`.
6. Log to `{{OPS_REPO}}/logs/{vault}.run.log`.

### `run-lint.sh {vault}`

Triggered weekly. Calls `claude -p /wiki-lint` to surface decisions due for review, stale entities, orphan atoms, and taxonomy hygiene candidates. Writes report to `<vault>/wiki/outputs/lint-report-{date}.md`.

### `drive-fetch.py` + `drive-ingest.sh {vault} {drive-url}`

Optional sub-flow. Spawned in background by the librarian's `auto-save-inbox` hook when a Drive URL is detected. Acquires a per-vault lockfile, fetches the folder via service-account auth, then calls `claude -p /wiki-ingest` to classify the new files.

### `scripts/daily-backup.sh`

Triggered nightly. Iterates over all repos. For each:

1. Acquire per-repo atomic `mkdir` lockfile.
2. `git pull --rebase --autostash` (safe with Obsidian's local edits).
3. `git status --porcelain` to count changes.
4. **Bulk-delete tripwire:** if >20 files would be deleted, ABORT this repo, log a warning, do not commit or push.
5. `git add -A`.
6. `git commit -m "ops auto-sync {date}"`.
7. `git push` (NEVER `--force`, NEVER `--amend`, NEVER `--hard`).
8. Release lockfile.
9. Log per-repo result to `{{OPS_REPO}}/logs/daily-backup.log` (rolling), plus per-day JSON + `last.json`.

Runs in ~15-25 seconds for all repos when there are no changes; up to ~60s if there is a lot to push.

---

## The disaster-recovery runbook

[`docs/RESTORE.md`](./docs/RESTORE.md) is the **most important file in the ecosystem.** It assumes your Mac is gone and walks Steps A-J to rebuild on a fresh machine in under 2 hours:

- **Step A** -- Clone all repos from GitHub
- **Step B** -- Restore secret files from 1Password
- **Step C** -- Install Hermes globally
- **Step D** -- Recreate any Python venvs via `uv`
- **Step E** -- Restore Claude Code OAuth via app
- **Step F** -- Re-register all launchd plists via symlink
- **Step G** -- Re-pair Telegram bots if needed
- **Step H** -- Re-OAuth the non-Anthropic chat LLM if expired
- **Step I** -- Open vaults in Obsidian and install plugins
- **Step J** -- Smoke test

If you make any change that affects the rebuild path (new plist, new script, new secret), update `RESTORE.md` AND the matching 1Password item the same day. Otherwise the disaster-recovery chain breaks silently.

---

## Required assets & resources

### Secrets (1Password vault `{{PROJECT_NAME}} Secrets`)

- `{{PROJECT_NAME}}: drive service-account.json` -> `{{OPS_REPO}}/drive-creds/service-account.json` (chmod 600 inside chmod 700 dir)
- The per-librarian secrets (`<librarian>/.env`, `<librarian>/auth.json`) -- live in their respective repos

### macOS keychain

- `Claude Code-credentials` (created by the Claude Code app first-run; restored by re-opening the app)

### External services

- GitHub (private repos under `{{GITHUB_USER}}`)
- 1Password (secret vault)
- Anthropic API via Claude Code OAuth -- first-party use only, TOS-compliant
- Telegram (via the librarian bots)
- macOS launchd
- Optional: Google Drive API (via service account)

### Hard dependencies on the host

- `gh` CLI (for repo cloning during restore)
- `uv` (Python package manager)
- Hermes binary in PATH
- Claude Code app (provides the OAuth token in keychain)
- 1Password app (for secret retrieval during restore)

---

## Logs (gitignored)

Tail the relevant log when debugging:

```bash
tail -f {{OPS_REPO}}/logs/librarian-<name>.out.log
tail -f {{OPS_REPO}}/logs/<vault>.run.log
tail -f {{OPS_REPO}}/logs/<vault>.lint.log
tail -f {{OPS_REPO}}/logs/daily-backup.log
cat   {{OPS_REPO}}/logs/daily-backup-last.json
```

---

## How it actually works (under the hood)

### Why launchd, not cron

macOS deprecated cron. launchd handles wake-from-sleep correctly, can express both calendar intervals and `WatchPaths`, and can `KeepAlive` a process. All jobs use launchd primitives: `StartCalendarInterval` for scheduled runs, `KeepAlive=true` for librarians.

### Why wiki-ingest is scheduled, not file-watched

Earlier design used `WatchPaths` on `raw/inbox/`, firing the ingest immediately on each new file. Two problems:

- Each `claude -p` invocation has startup cost; per-message runs waste compute and money
- Concurrent inbox writes during a Drive folder ingest (99 files at once) caused the watcher to thrash

Switched to **2x daily scheduled** runs at off-hour times. Drive sub-flow does its own immediate `claude -p` call after the fetch completes.

### Why the daily-backup is paranoid

The user explicitly requires "the backup must not break or delete older data." So:

- **Never `--force`** -- protects against branch divergence wiping remote
- **Never `--hard`** -- protects against discarding uncommitted changes
- **Never `--amend`** -- every backup is a new commit, audit-trailable
- **Per-repo lockfile** -- atomic `mkdir` (works on macOS where `flock` does not); prevents concurrent runs
- **`git pull --rebase --autostash` first** -- cleanly integrates remote changes without merge commits
- **Bulk-delete tripwire** -- if >20 files would be deleted in one run, ABORT and log; catches scenarios like an Obsidian sync gone wrong before the backup propagates the deletion to GitHub

### Why Claude OAuth for ingest, non-Anthropic for chat

- Claude Code's OAuth from the macOS keychain is **first-party Anthropic use** -- explicitly TOS-permitted via `claude -p`
- Putting Anthropic OAuth INSIDE Hermes (a third-party framework) violates Anthropic's TOS (enforced from Apr 4, 2026)
- Non-Anthropic OAuth (e.g. OpenAI Codex) in Hermes is sanctioned by the respective provider
- Net effect: chat is cheap, fast, friendly; classification is rigorous and schema-aware; no TOS violations

---

## Backup of this repo itself

`{{OPS_REPO}}` is in the `daily-backup.sh` iteration list. Every night, any new launchd plists, scripts, or doc tweaks here get committed and pushed. Whatever you do today is on GitHub by tomorrow morning, no manual intervention.

---

## If you're an AI agent reading this repo, do this in order

1. **Read this README** (which you're doing).
2. **Read [`docs/RESTORE.md`](./docs/RESTORE.md).** The canonical "how the whole system fits together at the install level."
3. **Read [`docs/SETUP.md`](./docs/SETUP.md)** for vault-side setup.
4. **Read [`docs/SETUP-AGENTS.md`](./docs/SETUP-AGENTS.md)** for librarian setup.
5. **Read [`scripts/daily-backup.sh`](./scripts/daily-backup.sh).** Understand the safety guarantees before touching it.
6. **Read [`run-ingest.sh`](./run-ingest.sh)** to understand the keychain -> claude -p flow.
7. **Sample 1 launchd plist** to see the schema in use.
8. **NEVER use `git push --force`.** Force-pushing to a shared remote rewrites history and can wipe co-authored commits or the nightly auto-sync commits that serve as the audit trail. If a push is rejected, `git pull --rebase --autostash` first and resolve; do not force.
9. **NEVER use `git reset --hard`.** Hard reset discards uncommitted work silently. If you must reset, use `git reset` (mixed) or `git stash` first; if you must hard-reset, the user must type the exact command themselves.
10. **NEVER use `git commit --amend`.** Every backup is a new commit by design, so the audit trail is complete. Amending rewrites history and can lose work if a pre-commit hook ran between the original and the amend.
11. **NEVER remove the bulk-delete tripwire.** The `if >20 files would be deleted: ABORT` branch in `scripts/daily-backup.sh` is the last line of defense against an Obsidian sync gone wrong or an accidental `rm -rf` propagating to GitHub. Weakening the threshold, bypassing the check, or removing the log-and-abort is forbidden. If a legitimate bulk delete is needed, the user runs it manually outside the backup path.
12. **NEVER schedule a job on an integer hour** (e.g. `HH:00`). Off-hour minutes like `:17`, `:33`, `:43` avoid API thundering-herd windows, keychain-access race conditions, and external-service rate-limit synchronization. All existing plists follow this rule; new ones must too.
13. **NEVER hardcode secrets in any committed file.** Secrets live in 1Password (canonical) and gitignored local files only.
14. **NEVER add Anthropic credentials to a librarian.** `anthropic` has no place in any `config.yaml`, `.env`, or `auth.json` under `agents/`. TOS -- see "Why Claude OAuth for ingest" above.
15. **If you change the launchd plists, also update the symlinks** at `~/Library/LaunchAgents/com.alexmind.*.plist` and reload via `launchctl unload && launchctl load -w`.
16. **If you add a new plist / script / secret,** update RESTORE.md AND the matching 1Password item the same day.
17. **All paths are absolute.** This repo lives at `{{LOCAL_ROOT}}/{{OPS_REPO}}/` -- every plist, script, and doc references that exact path. Do not move the repo.

---

## Quarterly maintenance

Every 3 months:

1. **Verify backup completeness:** spot-check 1Password items vs current local files.
2. **Verify daily auto-sync:** `tail {{OPS_REPO}}/logs/daily-backup.log` shows recent entries.
3. **Verify GitHub repos pushed:** `cd $each_repo && git status -sb` shows up-to-date with origin/main.
4. **Re-test ONE step of RESTORE.md:** clone a repo to `/tmp/`, restore one secret, confirm parsing.

If anything changes, update the actual file AND the matching 1Password item the same day.

---

## Reference

- Disaster recovery: [`docs/RESTORE.md`](./docs/RESTORE.md)
- Initial setup: [`docs/SETUP.md`](./docs/SETUP.md), [`docs/SETUP-AGENTS.md`](./docs/SETUP-AGENTS.md)
- Sister repos this orchestrates:
  - `{{LOCAL_ROOT}}/<vault-1>/` -- `{{GITHUB_USER}}/<vault-1-repo>`
  - `{{LOCAL_ROOT}}/<vault-2>/` -- `{{GITHUB_USER}}/<vault-2-repo>`
  - `{{LOCAL_ROOT}}/agents/<librarian-1>/` -- `{{GITHUB_USER}}/<librarian-1-repo>`
  - `{{LOCAL_ROOT}}/agents/<librarian-2>/` -- `{{GITHUB_USER}}/<librarian-2-repo>`

# _ops — {{PROJECT_NAME}} orchestration backbone

> **Repo on GitHub:** `{{GITHUB_USER}}/{{OPS_REPO}}` (private)
> **Mounted at:** `{{LOCAL_ROOT}}/_ops/`
> **Role:** Everything that is NOT the vault and NOT the agent. Launchd plists, shell scripts, ingest wrappers, paranoid backup, disaster-recovery runbook.
> **Self-backup:** This repo is itself covered by its own `daily-backup.sh` at 03:33.

---

## TL;DR

`_ops` is the glue that makes `{{PROJECT_NAME}}` actually run on a Mac:

- **3 macOS launchd jobs** (agent KeepAlive, scheduled wiki ingest, weekly lint, nightly backup).
- **The Claude wiki-ingest wrappers** (`run-ingest.sh`, `run-lint.sh`) that invoke `claude -p` — the ONLY first-party Anthropic call path in the whole system.
- **The paranoid daily-backup script** (`scripts/daily-backup.sh`) that pushes all repos to GitHub every night.
- **The disaster-recovery runbook** (`docs/RESTORE.md`) — the single most important file in this repo.

If it is not the vault and not the agent, it lives here.

---

## Where this repo sits in the 3-repo ecosystem

```
                    +--- {{VAULT_NAME}}/       (repo: {{VAULT_REPO}})
  {{PROJECT_NAME}} -+--- agents/{{AGENT_NAME}}/ (repo: {{AGENT_REPO}})
                    +--- _ops/                 (repo: {{OPS_REPO}})        <- YOU ARE HERE
                            ^
                            | schedules, ingests, and backs up the other two
```

| Other repo | What `_ops` does for it |
|---|---|
| `{{VAULT_NAME}}` | Runs `wiki-ingest` twice daily, `wiki-lint` weekly, includes in nightly backup. |
| `agents/{{AGENT_NAME}}` | Can host the agent KeepAlive plist; includes in nightly backup. |

---

## Folder map

```
_ops/
├── README.md                  <- you are here
├── run-ingest.sh              <- Claude classify + ingest wrapper (called by launchd)
├── run-lint.sh                <- Claude lint wrapper (called by launchd)
├── scripts/
│   └── daily-backup.sh        <- paranoid nightly backup of all 3 repos (03:33)
├── launchd/
│   ├── com.{{LAUNCHD_PREFIX}}.daily-backup.plist    <- schedules scripts/daily-backup.sh
│   ├── com.{{LAUNCHD_PREFIX}}.ingest.plist          <- schedules run-ingest.sh
│   └── com.{{LAUNCHD_PREFIX}}.lint.plist            <- schedules run-lint.sh
├── docs/
│   ├── SETUP.md               <- initial zero-to-backup walkthrough
│   ├── SETUP-AGENTS.md        <- Hermes librarian setup walkthrough
│   └── RESTORE.md             <- DISASTER RECOVERY RUNBOOK (the critical doc)
└── logs/                      <- gitignored; all runtime logs land here
    ├── daily-backup.log                 <- rolling (append-only)
    ├── daily-backup-{YYYY-MM-DD}.json   <- per-run summary
    ├── daily-backup-last.json           <- always = most recent run
    ├── ingest.run.log
    ├── ingest.{out,err}.log
    ├── lint.log
    └── lint.{out,err}.log
```

---

## Daily workflow (what happens automatically)

| Time | Job | What it does |
|---|---|---|
| Continuously | Agent gateway (KeepAlive) | Accepts Telegram messages, writes to `{{VAULT_NAME}}/raw/inbox/`. |
| 06:47 | `{{LAUNCHD_PREFIX}}.lint` | Claude lint pass over the vault, writes `wiki/outputs/lint-report-*.json`. |
| 08:17 | `{{LAUNCHD_PREFIX}}.ingest` | Claude classifies and ingests morning captures into `wiki/`. |
| 20:43 | `{{LAUNCHD_PREFIX}}.ingest` | Same, for evening captures. |
| 03:33 | `{{LAUNCHD_PREFIX}}.daily-backup` | Commits + pushes every repo. All history preserved, no destructive flags. |

You do nothing. Capture via Telegram, read the vault in Obsidian, trust the backups.

---

## Under the hood

### Why launchd, not cron

macOS deprecated cron. launchd handles wake-from-sleep correctly (cron silently misses runs when the laptop is asleep), supports both `StartCalendarInterval` and `KeepAlive`, and integrates with the keychain correctly.

### Why the wiki-ingest is scheduled, not file-watched

An earlier approach used `WatchPaths` on `raw/inbox/` to fire the ingest the moment a file landed. Problems:

- Each `claude -p` invocation has a few-second startup cost. Firing per-message wastes money.
- Concurrent inbox writes (e.g. a bulk paste of 20 notes) thrash the watcher.

Scheduled 2x/day batches incoming captures cheaply at the cost of at most ~12 hours of latency — acceptable for a second-brain, not acceptable for a chat bot (which is why the agent is real-time and the ingest is not).

### Why the daily-backup is paranoid

The design goal: "never break or delete older data." So:

- **NEVER `git push --force`.** Remote history is preserved forever.
- **NEVER `git reset --hard`.** No uncommitted local work is ever destroyed.
- **NEVER `git commit --amend`.** Every backup is a new commit, so every snapshot is audit-trailable.
- **Per-repo lockfile via atomic `mkdir`** — prevents races with agent auto-commits and manual runs. `mkdir` is atomic on macOS where `flock` does not exist.
- **`git pull --rebase --autostash` before push** — integrates remote changes cleanly; on conflict, aborts and skips the push for that repo so the operator resolves manually.
- **Bulk-delete tripwire** — if > 20 files would be deleted in one run for a repo, the script ABORTS that repo with a loud log entry and no commit, no push. Catches Obsidian-sync-gone-wrong or filesystem-mount-flake disasters before they propagate to GitHub. Override with `FORCE_DELETE_OK=1` for legitimate bulk cleanups.
- **Off-hour schedule (03:33)** — not 03:00. Integer-hour slots are when every cron job on Earth fires at once. Off-hour minutes reduce GitHub API thundering-herd and quota collisions.

### Why Claude OAuth for ingest, not inside the agent

- `run-ingest.sh` and `run-lint.sh` extract the OAuth token from the macOS keychain entry `Claude Code-credentials` and invoke `claude -p ...`. This is **first-party Anthropic use** and is TOS-compliant.
- Putting that same token inside a Hermes librarian (a third-party client) violates Anthropic's TOS (enforced from Apr 2026).
- The agent uses a sanctioned provider (typically OpenAI Codex OAuth or an OpenAI API key) for chat. Claude handles understanding-heavy work (classification, structured-wiki editing) via `claude -p`; the agent handles real-time conversation via OpenAI.

---

## Backup & disaster recovery

### What is backed up

The nightly `daily-backup.sh` iterates:

1. `{{LOCAL_ROOT}}/{{VAULT_NAME}}` -> `{{GITHUB_USER}}/{{VAULT_REPO}}`
2. `{{LOCAL_ROOT}}/agents/{{AGENT_NAME}}` -> `{{GITHUB_USER}}/{{AGENT_REPO}}`
3. `{{LOCAL_ROOT}}/_ops` -> `{{GITHUB_USER}}/{{OPS_REPO}}`

Plus secrets in your secret vault (1Password or equivalent): agent `.env`, agent `auth.json`, and the Claude Code keychain entry (recreated by re-logging in on the new Mac).

### What is NOT backed up

- `logs/` (gitignored — just runtime breadcrumbs).
- Any `*-venv/` directories (gitignored — rebuildable via `uv`).
- Anything in `raw/inbox/` that has not hit the ingest yet (the backup catches it at 03:33; if the Mac dies before then, those specific files are lost — mitigation: commit manually before long trips).

### Rebuild time on a fresh Mac

See `docs/RESTORE.md`. Target: <= 2 hours, step-by-step.

---

## If you're an AI reading this repo, do this in order

1. **Read this README.**
2. **Read [`docs/RESTORE.md`](./docs/RESTORE.md).** It is the canonical "how the whole system fits together at the install level."
3. **Read [`docs/SETUP.md`](./docs/SETUP.md)** for vault-side initial setup.
4. **Read [`docs/SETUP-AGENTS.md`](./docs/SETUP-AGENTS.md)** for the agent-side initial setup.
5. **Read [`scripts/daily-backup.sh`](./scripts/daily-backup.sh).** Understand the safety guarantees in the header comment block — never `--force`, never `--hard`, never `--amend`, bulk-delete tripwire, lockfiles.
6. **Read [`run-ingest.sh`](./run-ingest.sh) and [`run-lint.sh`](./run-lint.sh)** to understand the keychain -> `claude -p` flow.
7. **Sample one launchd plist** (e.g. `launchd/com.{{LAUNCHD_PREFIX}}.daily-backup.plist`) to see the plist schema in use.
8. **NEVER weaken the daily-backup safety guarantees.** No `--force`, no `--hard`, no `--amend`, no removing the bulk-delete tripwire, no removing the per-repo lockfile, no moving the schedule to an integer-hour slot.
9. **NEVER hardcode secrets in any committed file.** Secrets live in the user's secret vault (canonical) and in gitignored local files only. `.env` and `auth.json` are gitignored.
10. **NEVER invoke `claude -p` from inside the Hermes agent.** Anthropic OAuth is first-party only — see the TOS note in `run-ingest.sh` and in the "Under the hood" section of this README.
11. **NEVER change launchd schedules to `:00` or `:30` minute slots.** Always pick an off-hour minute (`:17`, `:33`, `:43`, `:47`) to avoid thundering-herd.
12. **If you edit a plist, also update the symlink** at `~/Library/LaunchAgents/com.{{LAUNCHD_PREFIX}}.*.plist` and reload via `launchctl unload && launchctl load -w`.
13. **If you add a new plist / script / secret,** update `RESTORE.md` AND the matching secret-vault item the same day. Otherwise the disaster-recovery chain breaks silently.
14. **All paths are absolute.** This repo lives at `{{LOCAL_ROOT}}/_ops/` — every plist, every script, every doc references that exact path. Do not move the repo.
15. **Logs live in `logs/` and are gitignored.** Write only to filenames listed in the "Folder map" above. Do not create ad-hoc log files scattered across the repo.

---

## Quarterly maintenance

Every 3 months:

1. Spot-check secret-vault items against current local files — no drift.
2. `tail {{LOCAL_ROOT}}/_ops/logs/daily-backup.log` — confirm recent entries.
3. `cd` into each of the 3 repos and verify `git status -sb` shows up-to-date with origin/main.
4. Re-test ONE step of `RESTORE.md` (clone a repo to `/tmp/`, restore one secret to `/tmp/`, confirm parsing). Proves the chain still works.

---

## Reference

- Disaster recovery: [`docs/RESTORE.md`](./docs/RESTORE.md)
- Initial setup: [`docs/SETUP.md`](./docs/SETUP.md), [`docs/SETUP-AGENTS.md`](./docs/SETUP-AGENTS.md)
- Sister repos this orchestrates:
  - `{{LOCAL_ROOT}}/{{VAULT_NAME}}/` -> `{{GITHUB_USER}}/{{VAULT_REPO}}`
  - `{{LOCAL_ROOT}}/agents/{{AGENT_NAME}}/` -> `{{GITHUB_USER}}/{{AGENT_REPO}}`

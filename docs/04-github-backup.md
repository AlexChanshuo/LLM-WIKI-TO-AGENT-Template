# 04 — Paranoid GitHub Backup

> **What this doc is for.** Deep-dive on the nightly backup that protects every repo in the system. Quotes the canonical `daily-backup.sh` structure, explains every safety guarantee and what failure it prevents, and covers the launchd plist, log outputs, how to add a new repo to the sweep, and how to interpret a tripwire abort.

---

## Why paranoid

Data loss comes from a small set of failure modes. The script defends against each by refusing to do the corresponding dangerous thing. The guiding principle: **a backup that breaks data is worse than no backup**, because it propagates the damage to GitHub before anyone notices.

| Failure mode | What the script does about it |
|---|---|
| Someone runs `git push --force` | Script never uses `--force`. Ever. |
| `git reset --hard` wipes uncommitted changes | Script never uses `--hard`. |
| `git commit --amend` rewrites history | Script never amends. Every backup is a new, audit-trailable commit. |
| Concurrent runs corrupt the index | Per-repo atomic `mkdir` lockfile. |
| Remote changes + local changes collide | `git pull --rebase --autostash` first. On conflict, abort that repo, continue others. |
| Accidental deletion of a big chunk of the vault | Bulk-delete tripwire: >20 deletions in one run → refuse, unstage, log, move on. |
| Laptop asleep at scheduled time | `launchd` wakes the job and fires when machine is back; `cron` would miss it. |
| One repo fails → all fail | Per-repo isolation; failures are logged per-repo and do not abort the loop. |

---

## Safety guarantees (eight rules, never broken)

Lifted directly from the script header. The comment block is the contract:

```
# Safety properties (never compromise these):
#   1. NEVER --force push (preserves all GitHub history forever)
#   2. NEVER --hard reset, NEVER clean -fd (never destroys local files)
#   3. NEVER --amend (never rewrites committed history)
#   4. Per-repo isolation: if 1 repo fails, others continue
#   5. Per-repo lockfile: prevents race with wiki-ingest auto-commits
#   6. Pull --rebase --autostash before push: integrates remote changes safely
#      → aborts and skips push if rebase conflicts (manual review needed)
#   7. Bulk-delete tripwire: refuses to commit if >20 files were deleted
#      → caller can override via FORCE_DELETE_OK=1 env var
#   8. Detailed logs: rolling .log + per-run JSON for forensics
```

These rules are what make the script safe to run unattended at 03:33 every night.

---

## Structure of `daily-backup.sh`

```
REPOS=(
  "{{LOCAL_ROOT}}/{{VAULT_NAME}}:{{VAULT_REPO}}"
  "{{LOCAL_ROOT}}/agents/{{AGENT_NAME}}:{{AGENT_REPO}}"
  "{{LOCAL_ROOT}}/_ops:{{OPS_REPO}}"
  # add repos here as they are created
)
GIT_USER="Your Name"
GIT_EMAIL="you@example.com"
BULK_DELETE_THRESHOLD=20

for entry in "${REPOS[@]}"; do
  backup_repo "${entry%%:*}" "${entry##*:}"
done
```

The `backup_repo` function is the whole story. Its control flow:

```
backup_repo():
  1. Verify .git/ exists → else log error, continue
  2. Atomic mkdir lockfile at .git/daily-backup.lock.d
       • if lock exists + >1h old → stale; remove, proceed
       • if lock exists + fresh → SKIP this repo, log "locked"
  3. cd into repo
  4. Capture pre-state (branch, HEAD, remote URL) for the log
  5. git pull --rebase --autostash origin <branch>
       • on conflict → abort rebase, pop stash, release lock, log fail
  6. git add -A        (respects .gitignore)
  7. git diff --cached --quiet → if no changes:
       • try a push anyway (idempotent — catches a failed push from a prior run)
       • release lock, log "no_change"
  8. Inspect staged diff: count +added / ~modified / -deleted
  9. BULK-DELETE TRIPWIRE:
       • if deleted > BULK_DELETE_THRESHOLD and FORCE_DELETE_OK unset:
           - unstage everything (`git reset HEAD -- .`)
           - release lock
           - log "refused_bulk_delete"
           - continue with next repo
  10. git commit -c user.email/name (never --amend)
  11. git push origin <branch>   (never --force)
       • on push failure → local commit stays; retry next run
  12. Release lock
  13. Append per-repo result to the JSON array
```

At the end of the loop, write a single consolidated JSON summary to both a per-day file and `daily-backup-last.json`.

---

## Why each safety property matters

### 1. Never `--force`
`--force` lets you overwrite any remote branch with anything. One accidental `--force` can erase weeks of the vault's history from GitHub. Refusing it means: if the push fails because the remote is ahead, the script logs the failure and you investigate. You cannot auto-destroy history.

### 2. Never `--hard`, never `clean -fd`
A `--hard` reset discards uncommitted work in your working tree; `clean -fd` deletes untracked files. Both are legitimate tools but have no place in an automated nightly backup — the backup should **save** things, not discard them.

### 3. Never `--amend`
Amending rewrites the previous commit. In an unattended backup that means historical commits disappear from `git log`. New commits only; every backup is audit-trailable: "at 03:33 on YYYY-MM-DD, these files changed, here is the commit."

### 4. Per-repo isolation
If vault A is clean and vault B has a rebase conflict, you still want vault A backed up. Each repo is its own try/catch; failures are per-repo entries in the summary JSON.

### 5. Per-repo lockfile
A manual `run-ingest.sh` at 03:31 can still be holding the repo's git index at 03:33. The lockfile prevents the backup from stepping on that commit. Stale lockfiles >1h are removed automatically — crashes should not wedge the backup permanently.

### 6. Pull `--rebase --autostash`
Obsidian Git + the ingest pipeline commit + push throughout the day. By 03:33, the remote may be ahead. `--rebase --autostash` replays your local changes on top of the remote's new HEAD without merge commits, and stashes any dirty working tree temporarily. If the rebase conflicts, the script aborts the rebase, pops the stash, and moves to the next repo — manual review follows.

### 7. Bulk-delete tripwire
If Obsidian Sync goes sideways and deletes 800 files from a vault, you do **not** want that propagated to GitHub at 03:33 without a human noticing. The tripwire counts `D` lines in `git diff --cached --name-status`; if that count exceeds `BULK_DELETE_THRESHOLD` (default 20), the script unstages everything, logs the filenames marked for deletion, and refuses to commit.

Override: `FORCE_DELETE_OK=1 /path/to/daily-backup.sh` — explicit, manual, eyes-on.

### 8. Detailed logs
You cannot fix what you cannot see. Logs come in three flavours (below).

---

## Log outputs

| File | Shape | Purpose |
|---|---|---|
| `{{OPS_REPO}}/logs/daily-backup.log` | Plain text, append-only | Human `tail`-able; full per-repo narrative |
| `{{OPS_REPO}}/logs/daily-backup-{YYYY-MM-DD}.json` | One JSON doc per day | Forensics / graphs |
| `{{OPS_REPO}}/logs/daily-backup-last.json` | Overwritten each run | Quick "what did last night's run do?" check |

Shape of the JSON:

```json
{
  "run_id": "2026-04-20T033300",
  "started_at": "2026-04-20T03:33:00+0800",
  "ended_at":   "2026-04-20T03:33:52+0800",
  "elapsed_seconds": 52,
  "summary": { "ok": 5, "no_change": 2, "locked": 0, "failed": 0 },
  "repos": [
    { "name": "{{VAULT_REPO}}", "status": "committed_pushed",
      "head_before": "a1b2c3d4e5f6", "head_after": "f6e5d4c3b2a1",
      "added": 3, "modified": 7, "deleted": 0 },
    ...
  ]
}
```

Status values you can see:

| Status | Meaning |
|---|---|
| `committed_pushed` | Normal success |
| `no_change` | No local changes; push attempt was idempotent |
| `locked` | Another git op in progress; skipped, will try next run |
| `pull_failed` | Rebase conflict; commit did not happen |
| `commit_failed` | Rare — git refused the commit |
| `committed_push_failed` | Commit is local; will try push on the next run |
| `refused_bulk_delete` | Tripwire fired; >threshold deletions; human review needed |
| `error` | Repo path not a git repo, `cd` failed, etc. |

---

## launchd plist — 03:33 nightly

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>{{LAUNCHD_PREFIX}}.daily-backup</string>
  <key>ProgramArguments</key>
  <array>
    <string>{{LOCAL_ROOT}}/_ops/scripts/daily-backup.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>3</integer>
    <key>Minute</key><integer>33</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>{{LOCAL_ROOT}}/_ops/logs/daily-backup.stdout.log</string>
  <key>StandardErrorPath</key>
  <string>{{LOCAL_ROOT}}/_ops/logs/daily-backup.stderr.log</string>
  <key>RunAtLoad</key><false/>
</dict>
</plist>
```

### Why 03:33

- Off-hour — dodges integer-hour API thundering herds (lots of cron jobs fire on :00).
- Past the typical ingest windows (08:17 / 20:43) — no race with the wiki watchers.
- Before any human likely to touch a vault (most operators wake 6–8am).
- `:33` not `:30` — no collision with `cron`-era defaults.

### Registration

```bash
ln -sf {{LOCAL_ROOT}}/_ops/launchd/{{LAUNCHD_PREFIX}}.daily-backup.plist \
       ~/Library/LaunchAgents/
launchctl load -w ~/Library/LaunchAgents/{{LAUNCHD_PREFIX}}.daily-backup.plist
launchctl list | grep daily-backup   # verify
```

---

## Adding a new repo to the sweep

1. Create the repo on GitHub under `{{GITHUB_USER}}` (private by default).
2. `git init -b main && git remote add origin ...` locally.
3. First commit + push.
4. Edit `{{OPS_REPO}}/scripts/daily-backup.sh` and append to `REPOS`:
   ```bash
   REPOS=(
     ...existing...
     "{{LOCAL_ROOT}}/{{NEW_REPO_PATH}}:{{NEW_REPO_NAME}}"
   )
   ```
5. Test manually: `{{OPS_REPO}}/scripts/daily-backup.sh` once. Verify the new entry appears in `daily-backup-last.json`.
6. Update your RESTORE runbook — the new repo needs a `gh repo clone` line there too.

No plist change needed; the plist fires the script, the script iterates `REPOS`.

---

## Interpreting a tripwire abort

Log looks like:

```
🚨 BULK DELETE DETECTED: 143 files marked for deletion (threshold: 20)
🚨 REFUSING to commit. Possible accident or filesystem issue.
🚨 To override: rerun manually with FORCE_DELETE_OK=1 set
🚨 Files marked for deletion:
    D  wiki/entities/people/...
    D  wiki/entities/people/...
    ...
```

Investigation steps:

1. **Do NOT override blindly.** First, confirm the deletion is intentional.
2. `cd {{LOCAL_ROOT}}/<repo>; git status` → see what is deleted in the working tree.
3. Check if Obsidian Sync or another tool caused it: `ls -la wiki/entities/people/` to confirm files actually missing on disk.
4. If deletion is correct (e.g. you reorganized) and intentional: `FORCE_DELETE_OK=1 {{OPS_REPO}}/scripts/daily-backup.sh`.
5. If deletion is accidental: `git checkout -- .` to restore from HEAD (or `git restore .`), then re-run without `FORCE_DELETE_OK`.

The tripwire has already saved you once by stopping the commit. Do not defeat it by reflex.

---

## Self-backup

The `{{OPS_REPO}}` is listed in its own `REPOS` array. Every night at 03:33, any new plist, script, or doc inside it is committed and pushed. The backup script backs up the backup script. No manual `git push` needed for ops changes.

---

## Cross-references

- [`01-architecture.md`](01-architecture.md) — the three-layer pattern this backup protects
- [`02-vault-setup.md`](02-vault-setup.md) — vaults are repos on this list
- [`03-hermes-agent.md`](03-hermes-agent.md) — agents are repos on this list
- [`06-ai-onboarding-readme.md`](06-ai-onboarding-readme.md) — every README should reference this file

---

## If you're an AI agent reading this

1. **Do not weaken the safety guarantees.** No `--force`, no `--hard`, no `--amend`, no removing the tripwire — ever. If someone asks you to, push back and point them at this doc.
2. **Add new repos to the `REPOS` array; never bypass the script.** The script is the one place the safety rules live; ad-hoc nightly `git push` loops lack the lockfile, the tripwire, and the rebase safety.
3. **When the tripwire fires, investigate before overriding.** `FORCE_DELETE_OK=1` is a deliberate manual decision, not an automation knob. If you find yourself reaching for it, the right move is usually `git restore` and a second, non-forced run.

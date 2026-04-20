#!/bin/bash
# daily-backup.sh — paranoid nightly backup for the {{PROJECT_NAME}} repos.
#
# This template ships with the {{OPS_REPO}} scaffold. It iterates the vault,
# the agent, and the ops repo itself, committing any local changes and pushing
# to GitHub. The design goal is to "never break or delete
# older data" — every guarantee below exists to uphold that promise.
#
# Safety properties (NEVER compromise these):
#   1. NEVER `git push --force`. Preserves full remote history forever.
#   2. NEVER `git reset --hard`. Never destroys uncommitted local files.
#   3. NEVER `git clean -fd`. Never silently wipes untracked work.
#   4. NEVER `git commit --amend`. Every backup is a brand-new commit, so
#      every snapshot is auditable in `git log`.
#   5. Per-repo isolation: if one repo fails, the others continue.
#   6. Per-repo lockfile via atomic `mkdir` (macOS has no `flock`). Prevents
#      races with the agent's auto-commit paths and with concurrent manual runs.
#   7. `git pull --rebase --autostash` BEFORE push. Cleanly integrates any
#      remote-side edits; on conflict the rebase is aborted and the push is
#      skipped for that repo — the operator resolves manually.
#   8. Bulk-delete tripwire: if more than BULK_DELETE_THRESHOLD files would be
#      deleted in a single run, the repo is ABORTED with a loud log entry,
#      nothing is committed or pushed. Catches catastrophes (Obsidian sync
#      gone wrong, filesystem mount flake) before they propagate to GitHub.
#      Operator override: re-run with `FORCE_DELETE_OK=1`.
#   9. Detailed logs: rolling `.log` (append-only), per-day JSON, and a
#      `last.json` that always reflects the most recent run.
#  10. Exits 0 even if some repos aborted — aggregated in the JSON summary;
#      launchd surfaces a green status and the operator reads the JSON on the
#      next morning check.
#
# Logs:
#   {{LOCAL_ROOT}}/_ops/logs/daily-backup.log                 (rolling)
#   {{LOCAL_ROOT}}/_ops/logs/daily-backup-{YYYY-MM-DD}.json   (per run)
#   {{LOCAL_ROOT}}/_ops/logs/daily-backup-last.json           (always last run)
#
# Fired by: ~/Library/LaunchAgents/com.{{LAUNCHD_PREFIX}}.daily-backup.plist
# Schedule: 03:33 (off-hour — avoids GitHub API thundering-herd at 03:00)
# Manual:   {{LOCAL_ROOT}}/_ops/scripts/daily-backup.sh

set -uo pipefail

# --- Configuration -----------------------------------------------------------
# Repos to back up. Format: "absolute_path:repo_display_name".
# The display name is used only in logs and in the JSON summary.
REPOS=(
  "{{LOCAL_ROOT}}/{{VAULT_NAME}}:{{VAULT_REPO}}"
  "{{LOCAL_ROOT}}/agents/{{AGENT_NAME}}:{{AGENT_REPO}}"
  "{{LOCAL_ROOT}}/_ops:{{OPS_REPO}}"
)
GIT_USER="{{HOME_USER}}"
GIT_EMAIL="{{HOME_USER}}@users.noreply.github.com"
BULK_DELETE_THRESHOLD=20  # refuse to commit if > this many files deleted at once

LOG_DIR="{{LOCAL_ROOT}}/_ops/logs"
ROLL_LOG="$LOG_DIR/daily-backup.log"
RUN_ID=$(date '+%Y-%m-%dT%H%M%S')
JSON_LOG="$LOG_DIR/daily-backup-$(date '+%Y-%m-%d').json"
LAST_LOG="$LOG_DIR/daily-backup-last.json"

mkdir -p "$LOG_DIR"

# --- Helpers -----------------------------------------------------------------
log() {
  # Echo to stdout (captured by launchd StandardOutPath) AND append to rolling log.
  printf '%s\n' "$*" | tee -a "$ROLL_LOG"
}

start_ts=$(date '+%s')
log ""
log "=================================================================="
log "$(date '+%Y-%m-%d %H:%M:%S')  daily-backup START  run_id=$RUN_ID  pid=$$"
log "=================================================================="

# Aggregated per-repo JSON results, joined at the end.
declare -a JSON_REPOS=()
declare -i COUNT_OK=0 COUNT_FAIL=0 COUNT_LOCKED=0 COUNT_NOCHANGE=0

# --- Per-repo backup function -----------------------------------------------
backup_repo() {
  local repo_path="$1"
  local repo_name="$2"

  log ""
  log "------------------------------------------------------------------"
  log "REPO: $repo_name"
  log "PATH: $repo_path"

  if [ ! -d "$repo_path/.git" ]; then
    log "  ERROR not a git repo (no .git/ found)"
    JSON_REPOS+=("{\"name\":\"$repo_name\",\"status\":\"error\",\"reason\":\"not a git repo\"}")
    COUNT_FAIL=$((COUNT_FAIL + 1))
    return
  fi

  # Per-repo lock (prevents race with agent auto-commit paths and concurrent backups).
  # Atomic `mkdir` is POSIX-portable on macOS where `flock` does not exist.
  local lock="$repo_path/.git/daily-backup.lock.d"
  if ! mkdir "$lock" 2>/dev/null; then
    # Stale-lock cleanup (> 1 hour old = previous run crashed).
    if find "$lock" -maxdepth 0 -mmin +60 2>/dev/null | grep -q .; then
      log "  WARN removing stale lock (>1h old): $lock"
      rm -rf "$lock"
      mkdir "$lock"
    else
      log "  SKIP another git operation in progress (lock at $lock)"
      JSON_REPOS+=("{\"name\":\"$repo_name\",\"status\":\"locked\"}")
      COUNT_LOCKED=$((COUNT_LOCKED + 1))
      return
    fi
  fi

  cd "$repo_path" || {
    log "  ERROR cd failed"
    rm -rf "$lock"
    JSON_REPOS+=("{\"name\":\"$repo_name\",\"status\":\"error\",\"reason\":\"cd failed\"}")
    COUNT_FAIL=$((COUNT_FAIL + 1))
    return
  }

  # Capture pre-state for the audit log.
  local branch before remote
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || branch="?"
  before=$(git rev-parse HEAD 2>/dev/null) || before="?"
  remote=$(git config --get remote.origin.url 2>/dev/null) || remote="?"
  log "  Branch:    $branch"
  log "  Remote:    $remote"
  log "  HEAD pre:  ${before:0:12}"

  # Pull with rebase + autostash. Safe — never drops local changes; aborts cleanly on conflict.
  log "  -- Pulling remote changes (rebase + autostash) --"
  local pull_out
  if pull_out=$(git pull --rebase --autostash origin "$branch" 2>&1); then
    log "$(echo "$pull_out" | sed 's/^/    /')"
  else
    log "$(echo "$pull_out" | sed 's/^/    /')"
    log "  ERROR Pull failed (likely rebase conflict). Aborting rebase and skipping push for this repo."
    git rebase --abort 2>/dev/null || true
    git stash pop 2>/dev/null || true
    rm -rf "$lock"
    JSON_REPOS+=("{\"name\":\"$repo_name\",\"status\":\"pull_failed\",\"reason\":\"rebase conflict\",\"head_before\":\"${before:0:12}\"}")
    COUNT_FAIL=$((COUNT_FAIL + 1))
    return
  fi

  # Stage all changes (respects .gitignore).
  git add -A 2>>"$ROLL_LOG"

  # Anything to commit?
  if git diff --cached --quiet; then
    log "  OK No local changes to commit"
    # Still attempt a push in case a prior run's push failed (idempotent).
    log "  -- Attempting push (in case last run failed) --"
    local push_out
    if push_out=$(git push origin "$branch" 2>&1); then
      log "$(echo "$push_out" | sed 's/^/    /')"
      log "  OK NO CHANGES — already in sync with remote"
    else
      log "$(echo "$push_out" | sed 's/^/    /')"
      log "  WARN push failed but no local changes — investigate"
    fi
    rm -rf "$lock"
    JSON_REPOS+=("{\"name\":\"$repo_name\",\"status\":\"no_change\",\"head\":\"${before:0:12}\"}")
    COUNT_NOCHANGE=$((COUNT_NOCHANGE + 1))
    return
  fi

  # Inspect what's about to be committed.
  local stat_out diff_files added modified deleted
  stat_out=$(git diff --cached --stat)
  diff_files=$(git diff --cached --name-status)
  added=$(echo "$diff_files" | grep -c '^A' || true)
  modified=$(echo "$diff_files" | grep -c '^M' || true)
  deleted=$(echo "$diff_files" | grep -c '^D' || true)

  log "  -- Staged changes --"
  log "    files: +$added added | ~$modified modified | -$deleted deleted"
  log "$(echo "$stat_out" | sed 's/^/    /')"

  # Bulk-delete tripwire — refuse if > threshold deletions (unless operator override).
  if [ "$deleted" -gt "$BULK_DELETE_THRESHOLD" ] && [ -z "${FORCE_DELETE_OK:-}" ]; then
    log "  TRIPWIRE BULK DELETE DETECTED: $deleted files marked for deletion (threshold: $BULK_DELETE_THRESHOLD)"
    log "  TRIPWIRE REFUSING to commit. Possible accident or filesystem issue."
    log "  TRIPWIRE To override: re-run manually with FORCE_DELETE_OK=1 set in the environment."
    log "  TRIPWIRE Files marked for deletion:"
    log "$(echo "$diff_files" | grep '^D' | sed 's/^/    /')"
    git reset HEAD -- . >/dev/null 2>&1 || true   # unstage everything — leaves files on disk untouched
    rm -rf "$lock"
    JSON_REPOS+=("{\"name\":\"$repo_name\",\"status\":\"refused_bulk_delete\",\"deletes\":$deleted,\"head\":\"${before:0:12}\"}")
    COUNT_FAIL=$((COUNT_FAIL + 1))
    return
  fi

  # Commit (always a NEW commit — never --amend).
  local commit_msg="chore: daily-backup $(date '+%Y-%m-%d %H:%M')

run_id: $RUN_ID
files: +$added ~$modified -$deleted
$(echo "$stat_out" | tail -1)"

  log "  -- Committing --"
  local commit_out
  if commit_out=$(git -c user.email="$GIT_EMAIL" -c user.name="$GIT_USER" commit -m "$commit_msg" 2>&1); then
    log "$(echo "$commit_out" | sed 's/^/    /')"
  else
    log "$(echo "$commit_out" | sed 's/^/    /')"
    log "  ERROR commit failed"
    rm -rf "$lock"
    JSON_REPOS+=("{\"name\":\"$repo_name\",\"status\":\"commit_failed\",\"head_before\":\"${before:0:12}\"}")
    COUNT_FAIL=$((COUNT_FAIL + 1))
    return
  fi

  local after
  after=$(git rev-parse HEAD)
  log "  HEAD post: ${after:0:12}"

  # Push (NEVER --force; will fail loudly if non-fast-forward, which should not happen since we just rebased).
  log "  -- Pushing to remote (no --force, ever) --"
  local push_out
  if push_out=$(git push origin "$branch" 2>&1); then
    log "$(echo "$push_out" | sed 's/^/    /')"
    log "  OK PUSHED | $repo_name $before...$after"
    rm -rf "$lock"
    JSON_REPOS+=("{\"name\":\"$repo_name\",\"status\":\"committed_pushed\",\"head_before\":\"${before:0:12}\",\"head_after\":\"${after:0:12}\",\"added\":$added,\"modified\":$modified,\"deleted\":$deleted}")
    COUNT_OK=$((COUNT_OK + 1))
    return
  else
    log "$(echo "$push_out" | sed 's/^/    /')"
    log "  WARN PUSH FAILED — commit is local; tomorrow's run will retry"
    rm -rf "$lock"
    JSON_REPOS+=("{\"name\":\"$repo_name\",\"status\":\"committed_push_failed\",\"head_before\":\"${before:0:12}\",\"head_after\":\"${after:0:12}\"}")
    COUNT_FAIL=$((COUNT_FAIL + 1))
    return
  fi
}

# --- Main loop ---------------------------------------------------------------
for entry in "${REPOS[@]}"; do
  repo_path="${entry%%:*}"
  repo_name="${entry##*:}"
  backup_repo "$repo_path" "$repo_name"
done

# --- Summary -----------------------------------------------------------------
end_ts=$(date '+%s')
elapsed=$((end_ts - start_ts))

log ""
log "=================================================================="
log "$(date '+%Y-%m-%d %H:%M:%S')  daily-backup END  elapsed=${elapsed}s"
log "  committed+pushed: $COUNT_OK"
log "  no changes:       $COUNT_NOCHANGE"
log "  locked/skipped:   $COUNT_LOCKED"
log "  failed:           $COUNT_FAIL"
log "=================================================================="

# Machine-readable summary.
JSON_REPOS_JOINED=$(IFS=,; echo "${JSON_REPOS[*]}")
JSON="{\"run_id\":\"$RUN_ID\",\"started_at\":\"$(date -r $start_ts '+%Y-%m-%dT%H:%M:%S%z')\",\"ended_at\":\"$(date -r $end_ts '+%Y-%m-%dT%H:%M:%S%z')\",\"elapsed_seconds\":$elapsed,\"summary\":{\"ok\":$COUNT_OK,\"no_change\":$COUNT_NOCHANGE,\"locked\":$COUNT_LOCKED,\"failed\":$COUNT_FAIL},\"repos\":[$JSON_REPOS_JOINED]}"
echo "$JSON" > "$JSON_LOG"
echo "$JSON" > "$LAST_LOG"

# Exit 0 even when some repos aborted — their failures are recorded in the JSON
# and the rolling log. Non-zero exit would make launchd flag the run red, but
# the point of this script is that per-repo failures are EXPECTED and SAFE;
# the operator checks `daily-backup-last.json` each morning.
exit 0

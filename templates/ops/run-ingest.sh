#!/bin/bash
# run-ingest.sh — wiki ingest wrapper for the {{PROJECT_NAME}} vault.
#
# This is the ONE permitted place in the whole system to invoke Claude.
#
# Anthropic TOS constraint (READ THIS BEFORE EDITING):
#   - Claude may only be invoked via the official Claude Code CLI (`claude -p`).
#   - The OAuth token is extracted from the macOS keychain entry created by
#     the Claude Code app: `security find-generic-password -s "Claude Code-credentials" -w`.
#   - Claude MUST NOT be invoked from inside a Hermes agent, a third-party
#     client, or any process that proxies the OAuth credential elsewhere.
#     That constitutes first-party credential reuse in a third-party context
#     and violates Anthropic's TOS (enforced from Apr 2026).
#   - If you need Claude-like behavior inside a Hermes agent, point that agent
#     at OpenAI / Codex / a sanctioned model — never at Anthropic OAuth.
#
# Pipeline:
#   Pass 1: cheap classification with Haiku (slash command `/wiki-classify`).
#   Pass 2: full ingest with Sonnet (slash command `/wiki-ingest`).
# Both passes read and write the vault at {{LOCAL_ROOT}}/{{VAULT_NAME}}/.
#
# Invoked by: launchd plist com.{{LAUNCHD_PREFIX}}.ingest (off-hour schedule).
# Manual:     {{LOCAL_ROOT}}/_ops/run-ingest.sh

set -euo pipefail

VAULT="{{LOCAL_ROOT}}/{{VAULT_NAME}}"
LOG_DIR="{{LOCAL_ROOT}}/_ops/logs"
LOG="$LOG_DIR/ingest.run.log"
CLAUDE_BIN="/Users/{{HOME_USER}}/.local/bin/claude"

mkdir -p "$LOG_DIR" "$VAULT/raw/inbox/.classified/.done" "$VAULT/raw/inbox/.processed"

# --- Extract OAuth token from macOS keychain ---------------------------------
# launchd-spawned processes do not inherit the user's keychain access via env
# vars, so we pull the token out explicitly and export it for the claude CLI.
extract_token() {
  security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["claudeAiOauth"]["accessToken"])' 2>/dev/null
}

OAUTH_TOKEN="$(extract_token || true)"
if [ -z "$OAUTH_TOKEN" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR: could not extract Claude Code OAuth token from keychain" >> "$LOG"
  echo "$(date '+%Y-%m-%d %H:%M:%S')        (open the Claude Code app once to create the 'Claude Code-credentials' keychain entry, then re-run)" >> "$LOG"
  exit 1
fi
export CLAUDE_CODE_OAUTH_TOKEN="$OAUTH_TOKEN"

# --- Single-instance guard (atomic mkdir; macOS has no flock) ----------------
LOCK_DIR="$LOG_DIR/ingest.lock.d"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  if [ -d "$LOCK_DIR" ] && [ "$(find "$LOCK_DIR" -maxdepth 0 -mmin +30 2>/dev/null)" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') stale lock removed" >> "$LOG"
    rm -rf "$LOCK_DIR"
    mkdir "$LOCK_DIR"
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') another ingest in progress, skipping" >> "$LOG"
    exit 0
  fi
fi
trap 'rm -rf "$LOCK_DIR"' EXIT

cd "$VAULT"

# --- Skip if the inbox is empty ---------------------------------------------
NEW_FILES=$(find raw/inbox -maxdepth 1 -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
if [ "$NEW_FILES" = "0" ]; then
  exit 0
fi

echo "" >> "$LOG"
echo "============================================================" >> "$LOG"
echo "$(date '+%Y-%m-%d %H:%M:%S') ingest start | $NEW_FILES new files" >> "$LOG"

# --- Pass 1: classify (Haiku) ------------------------------------------------
echo "$(date '+%Y-%m-%d %H:%M:%S') pass-1 classify (haiku)" >> "$LOG"
if ! echo "/wiki-classify" | "$CLAUDE_BIN" --print --model haiku \
    --allowedTools "Read,Write,Glob,Bash" \
    >> "$LOG" 2>&1; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') pass-1 FAILED — aborting ingest" >> "$LOG"
  exit 1
fi

# --- Pass 2: ingest (Sonnet) -------------------------------------------------
echo "$(date '+%Y-%m-%d %H:%M:%S') pass-2 ingest (sonnet)" >> "$LOG"
if ! echo "/wiki-ingest" | "$CLAUDE_BIN" --print --model sonnet \
    --allowedTools "Read,Write,Edit,Bash,Glob,Grep" \
    >> "$LOG" 2>&1; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') pass-2 FAILED" >> "$LOG"
  exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') ingest done" >> "$LOG"

# Git auto-sync happens in daily-backup.sh at 03:33. This script only writes
# files; the paranoid backup is the one committed and pushing to GitHub.

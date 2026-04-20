#!/bin/bash
# run-lint.sh — weekly lint wrapper for the {{PROJECT_NAME}} vault.
#
# Anthropic TOS constraint (READ THIS BEFORE EDITING):
#   - Claude may only be invoked via the official Claude Code CLI (`claude -p`).
#   - The OAuth token is extracted from the macOS keychain entry created by
#     the Claude Code app: `security find-generic-password -s "Claude Code-credentials" -w`.
#   - Claude MUST NOT be invoked from inside a Hermes agent or any third-party
#     client. See run-ingest.sh header for the full rationale.
#
# What it does:
#   Runs `claude -p /wiki-lint` against the vault. The slash command is expected
#   to validate:
#     - Every page in wiki/ has required frontmatter fields (id, type, status,
#       created, updated — extend in the vault's CLAUDE.md).
#     - All wikilinks resolve; dangling links are reported.
#     - Filenames are kebab-case (no spaces, no Title Case, no CamelCase).
#     - Every entity has the minimal stub content required by the schema.
#   The slash command writes a structured JSON report to
#   {{LOCAL_ROOT}}/{{VAULT_NAME}}/wiki/outputs/lint-report-{YYYY-MM-DD}.json
#   and a human-readable markdown summary alongside it.
#
# Exit codes:
#   0 — lint ran and found no violations.
#   1 — lint run itself failed (Claude CLI error, token missing, etc.).
#   2 — lint ran but found violations; the JSON report lists them. launchd
#       surfaces this as a failed job so the operator sees it.
#
# Invoked by: launchd plist com.{{LAUNCHD_PREFIX}}.lint (once weekly, off-hour).
# Manual:     {{LOCAL_ROOT}}/_ops/run-lint.sh

set -euo pipefail

VAULT="{{LOCAL_ROOT}}/{{VAULT_NAME}}"
LOG_DIR="{{LOCAL_ROOT}}/_ops/logs"
LOG="$LOG_DIR/lint.log"
REPORT_DIR="$VAULT/wiki/outputs"
REPORT_JSON="$REPORT_DIR/lint-report-$(date '+%Y-%m-%d').json"
CLAUDE_BIN="/Users/{{HOME_USER}}/.local/bin/claude"

mkdir -p "$LOG_DIR" "$REPORT_DIR"
cd "$VAULT"

# --- Extract OAuth token from macOS keychain (see TOS note above) -----------
OAUTH_TOKEN="$(security find-generic-password -s 'Claude Code-credentials' -w 2>/dev/null \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["claudeAiOauth"]["accessToken"])' 2>/dev/null || true)"
if [ -z "$OAUTH_TOKEN" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR: could not extract Claude Code OAuth token from keychain" >> "$LOG"
  exit 1
fi
export CLAUDE_CODE_OAUTH_TOKEN="$OAUTH_TOKEN"

echo "" >> "$LOG"
echo "============================================================" >> "$LOG"
echo "$(date '+%Y-%m-%d %H:%M:%S') lint start" >> "$LOG"

# --- Run the lint slash command ---------------------------------------------
if ! echo "/wiki-lint" | "$CLAUDE_BIN" --print --model sonnet \
    --allowedTools "Read,Write,Edit,Glob,Grep,Bash" \
    >> "$LOG" 2>&1; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') lint CLI failed" >> "$LOG"
  exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') lint done" >> "$LOG"

# --- Surface violation count as non-zero exit so launchd flags the run ------
# The slash command is expected to write REPORT_JSON with a top-level
# "violations" integer. Missing report = treat as no violations.
if [ -f "$REPORT_JSON" ]; then
  VIOLATIONS=$(python3 -c "import json; d=json.load(open('$REPORT_JSON')); print(int(d.get('violations', 0)))" 2>/dev/null || echo 0)
  echo "$(date '+%Y-%m-%d %H:%M:%S') lint found $VIOLATIONS violations | $REPORT_JSON" >> "$LOG"
  if [ "$VIOLATIONS" -gt 0 ]; then
    exit 2
  fi
fi

exit 0

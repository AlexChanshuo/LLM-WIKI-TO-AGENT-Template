# 05 — The OAuth Split: Claude for Ingest, ChatGPT for Chat

> **What this doc is for.** The single policy rule that is easiest to mess up and most expensive when wrong. Explains why Claude is siloed to `claude -p` and why Hermes chats over OpenAI Codex OAuth (ChatGPT). Covers TOS rationale, enforcement date, cost math, and a one-line verification command.

---

## The rule, in one line

> **Anthropic OAuth credentials live only in the Claude Code CLI. ChatGPT OAuth lives inside Hermes and any other third-party agent framework. The two never cross.**

Violating this is a TOS violation, enforceable by Anthropic. The cost of compliance is trivial (~NT\$6–12/day incremental). There is no upside to crossing the streams.

---

## Why

### Anthropic TOS

Anthropic's subscription-OAuth credentials (the `sk-ant-oat01-*` tokens issued by the Claude Code app and stashed in your macOS keychain under `Claude Code-credentials`) are **for first-party use of Anthropic products only**. Using those credentials inside a third-party agent framework — Hermes, LangChain agents, AutoGen, anything that wraps an LLM with tools and exposes the wrapper to other users or automations — is prohibited.

Anthropic began enforcing this on **April 4, 2026**. Accounts caught routing OAuth-backed calls through third-party agents lose API access. The fix is mechanical: keep Anthropic OAuth in Anthropic-owned clients.

### OpenAI's position

OpenAI Codex OAuth (the flow obtained by `hermes auth add openai-codex --type oauth`) is **sanctioned** for exactly this use — a third-party agent calling ChatGPT on behalf of a Pro subscriber. Hermes' bread-and-butter setup. No TOS issue.

### Net effect on the template

| Workload | Runs on | Why |
|---|---|---|
| `wiki-classify` (Pass 1, cheap) | Claude Haiku via `claude -p` | Rigorous, schema-aware, cheap; CLI is first-party, TOS-OK |
| `wiki-ingest` (Pass 2, structured writes) | Claude Sonnet via `claude -p` | Same — Sonnet for the structured writes |
| `wiki-lint` (weekly health check) | Claude via `claude -p` | Same |
| `wiki-query` (synthesis for queries) | Claude via `claude -p` | Same |
| Telegram chat replies | ChatGPT via Codex OAuth, inside Hermes | Conversational; Pro-subscription-covered |
| Voice transcription | OpenAI Whisper via API key | Cheap, ubiquitous |
| Image description | Claude Vision via `claude -p` — **only if** invoked from ops side; otherwise OpenAI Vision | Never inside Hermes |

Claude: rigorous classifier + wiki editor. ChatGPT: conversational mouth. Each in its lane.

---

## How the template enforces it

### In the agent (`{{AGENT_REPO}}`)

**`config.yaml` must not contain any `anthropic` provider or `fallback_model: anthropic`.**

```yaml
models:
  default:
    provider: openai-codex      # OK
    model: gpt-5.4-mini
  smart_routing:
    cheap_model: gpt-5.4-nano   # OK
  # NO fallback_model: anthropic
  # NO provider: anthropic anywhere
```

**`auth.json` must not contain an `anthropic` credential block.**

```json
{
  "credential_pool": {
    "openai-codex": { "access_token": "...", "refresh_token": "..." },
    "github-copilot": { "pat": "..." }
    // NO "anthropic" key
  }
}
```

The `SOUL.md` of the agent says, in a hard-negative section: "Never add `fallback_model: anthropic` anywhere in this config. TOS."

### In ops (`{{OPS_REPO}}`)

The ingest pipeline pulls Anthropic credentials from the macOS keychain each run:

```bash
# inside run-ingest.sh
CLAUDE_CODE_OAUTH_TOKEN=$(security find-generic-password -s "Claude Code-credentials" -w)
export CLAUDE_CODE_OAUTH_TOKEN
claude -p /wiki-classify --model haiku
claude -p /wiki-ingest   --model sonnet
```

That is first-party use: the `claude` binary is Anthropic-owned, invoked from a shell, with OAuth sitting in the OS keychain Anthropic expects it to sit in. TOS-compliant.

---

## Cost math

At typical personal-knowledge-base volume:

| Line item | Cost/day |
|---|---|
| Claude ingest pipeline (Haiku classify + Sonnet writes, 2×/day × N vaults) | \$0.20–0.40 |
| Claude lint (weekly; amortized) | \$0.02–0.05 |
| Claude queries (ad-hoc, via `/wiki-query`) | \$0.05–0.20 |
| ChatGPT chat via Codex OAuth (Pro subscription) | covered by \$20/mo Pro; marginal \$0 |
| Whisper voice | \$0.10 |
| Vision (if used, on raw images) | \$0.01–0.03 per image |
| **Total incremental beyond the Pro subscription** | **~NT\$6–12/day** |

Rough conversion: NT\$6–12/day ≈ US\$0.20–0.40/day. The "put Claude in Hermes to save money" move saves roughly zero dollars while risking account suspension.

---

## Verification — grep the librarian configs

**Run this any time. Zero matches expected.**

```bash
grep -r -n -E 'anthropic|sk-ant' \
  {{LOCAL_ROOT}}/agents/*/config.yaml \
  {{LOCAL_ROOT}}/agents/*/auth.json \
  {{LOCAL_ROOT}}/agents/*/SOUL.md 2>/dev/null
```

Any hit is a policy violation. Investigate every match.

Tighter-scoped version for a single agent:

```bash
grep -n -E 'anthropic|sk-ant' \
  {{LOCAL_ROOT}}/agents/{{AGENT_NAME}}/{config.yaml,auth.json,SOUL.md}
```

You can add this as a pre-commit hook, a daily cron, or a line in the backup script. It takes milliseconds.

**Important caveat.** `SOUL.md` is allowed to *mention* "anthropic" in sentences like "NEVER add `fallback_model: anthropic`" — those are the rule, not the violation. The grep above will flag them, so visually filter for config-y contexts (inside a YAML block, inside `auth.json`, credential-like strings). A stricter grep targets only the YAML/JSON files:

```bash
grep -n -E 'anthropic|sk-ant' \
  {{LOCAL_ROOT}}/agents/*/config.yaml \
  {{LOCAL_ROOT}}/agents/*/auth.json
```

Zero matches in these two file types = compliant.

---

## What if you need Claude inside an agent flow

You do not — but if you think you do, here are the legitimate escape hatches:

1. **Spawn `claude -p` as a subprocess** from the agent's hook or skill. The credentials stay in the keychain; the child process is a first-party Claude call; the agent only consumes the stdout. This is how `drive-ingest.sh` works in the AlexMind reference implementation.
2. **Shell out to an ops script** that itself calls `claude -p`. Same pattern, one more hop.
3. **Use Anthropic's API key (paid, not the OAuth subscription)** — a separate billing mechanism that is sanctioned for third-party use. Different TOS path.

Option 1 or 2 is the right answer almost always. Option 3 only if you genuinely need it and can justify the cost.

---

## Cross-references

- [`01-architecture.md`](01-architecture.md) — where Claude's ingest and ChatGPT's chat sit in the four-op cycle
- [`03-hermes-agent.md`](03-hermes-agent.md) — the config.yaml and auth.json shape the agent uses
- [`04-github-backup.md`](04-github-backup.md) — the nightly backup runs the compliance grep trivially; consider baking it in

---

## If you're an AI agent reading this

1. **Never add `provider: anthropic` or `fallback_model: anthropic` anywhere in a Hermes config or auth file.** The TOS enforcement is real and mechanical.
2. **If you need Claude inside an agent flow, spawn `claude -p` as a subprocess.** Do not smuggle Anthropic OAuth into the agent's credential pool.
3. **Run the grep verification after any config change.** `grep -r -E 'anthropic|sk-ant' agents/*/config.yaml agents/*/auth.json` must return zero lines.

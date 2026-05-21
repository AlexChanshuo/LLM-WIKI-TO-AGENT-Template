# CLAUDE.md — Session-start rules for this template

> Claude Code auto-loads this file when you open the repo. OpenAI Codex auto-loads `AGENTS.md` (top-level sibling stub pointing back here). The schema lives in one place. `AGENT.md` is the authoritative playbook; this file is the compact reminder list.

**Canonical pattern source:** Andrej Karpathy, "LLM Wiki" gist ([`gist.github.com/karpathy/442a6bf555914893e9891c11519de94f`](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f), Apr 3, 2026). Verbatim local copy at [`docs/research/sources/karpathy-2026-04-03-llm-wiki.md`](./docs/research/sources/karpathy-2026-04-03-llm-wiki.md).

---

## Authoritative playbook

**Read `AGENT.md` in full before taking any action.** It contains your role, mental model, step-by-step procedure, and NEVER rules.

This file lists only (a) hard rules, (b) placeholder tokens, and (c) canonical layout.

---

## Hard rules (apply always)

1. **No emojis in any file you write or commit.**
2. **English only.** Repo documentation is English-only regardless of the user's native language.
3. **Anthropic TOS split.** `claude -p` with `CLAUDE_CODE_OAUTH_TOKEN` from the macOS keychain is first-party and allowed. `claude` inside Hermes or any third-party agent is forbidden. Hermes chat runs on ChatGPT via OpenAI Codex OAuth.
4. **Paranoid backup.** Never `git push --force`, never `git reset --hard`, never `git commit --amend`. Every backup is a new commit. Per-repo atomic `mkdir` lockfile. Bulk-delete tripwire: any single run with >20 deletions aborts that repo. `git pull --rebase --autostash` before push. Off-hour schedule (03:33, not 03:00).
5. **Deterministic over LLM.** File writes that must happen belong in Python hooks or shell scripts. LLM tool calls get understanding and reply duties only.
6. **Every README** (vault, agent, ops) must include a numbered "If you're an AI agent reading this, do this in order" section with explicit NEVER rules.
7. **No secrets committed.** `.env`, `auth.json`, `service-account.json`, OAuth tokens — all gitignored. Canonical secret store is the user's 1Password vault (or equivalent).
8. **Confirm all placeholders with the human before scaffolding.** A typo in `{{PROJECT_NAME}}` propagates into repo names, launchd job names, and absolute paths.

---

## Placeholder tokens

All template files contain `{{UPPER_SNAKE}}` tokens. Substitute once, deterministically (shell or Python script — not an LLM tool loop).

| Token | Meaning | Example |
|---|---|---|
| `{{PROJECT_NAME}}` | Top-level project slug | `alice-brain` |
| `{{GITHUB_USER}}` | GitHub username or org | `alice-chen` |
| `{{VAULT_NAME}}` | Vault directory name | `alice-notes` |
| `{{VAULT_REPO}}` | Vault GitHub repo name | `alice-notes` |
| `{{AGENT_NAME}}` | Librarian agent directory + process name | `shelf-bot` |
| `{{AGENT_REPO}}` | Agent GitHub repo name | `shelf-bot` |
| `{{OPS_REPO}}` | Ops backbone GitHub repo name | `alice-brain-ops` |
| `{{TELEGRAM_BOT_HANDLE}}` | Telegram @handle from BotFather | `@shelfbot` |
| `{{DOMAIN_DESCRIPTION}}` | One sentence on what the vault is for | `Alice's product-research notes` |
| `{{LAUNCHD_PREFIX}}` | launchd job prefix (dot-separated) | `com.alice-chen.alice-brain` |
| `{{LOCAL_ROOT}}` | Absolute path to project root on disk | `/Users/alice/Documents/alice-brain` |

After substitution, run `grep -r '{{' {{LOCAL_ROOT}}/` — there should be zero matches outside intentional `{{ }}` in template-literal code.

---

## Canonical target layout

```
{{LOCAL_ROOT}}/
├── {{VAULT_NAME}}/         (repo: {{GITHUB_USER}}/{{VAULT_REPO}})
│   ├── CLAUDE.md           schema (routing, frontmatter, lint rules)
│   ├── README.md
│   ├── raw/                LLM reads, never writes
│   ├── wiki/               LLM writes, human reads
│   ├── templates/
│   └── .claude/commands/   /wiki-classify, /wiki-ingest, /wiki-query, /wiki-lint
│
├── agents/
│   └── {{AGENT_NAME}}/     (repo: {{GITHUB_USER}}/{{AGENT_REPO}})
│       ├── README.md
│       ├── SOUL.md         personality contract
│       ├── config.yaml     model routing (ChatGPT via openai-codex), tool allowlists
│       ├── hooks/auto-save-inbox/   deterministic Python writer
│       └── scripts/start.sh         launchd entry point
│
└── _ops/                   (repo: {{GITHUB_USER}}/{{OPS_REPO}})
    ├── run-ingest.sh       keychain → claude -p classify + ingest + commit
    ├── run-lint.sh         weekly claude -p lint
    ├── scripts/daily-backup.sh   paranoid backup (all 3 repos)
    ├── launchd/            4 plists
    └── docs/{SETUP.md,SETUP-AGENTS.md,RESTORE.md}
```

Four launchd jobs:
- `{{LAUNCHD_PREFIX}}.librarian.{{AGENT_NAME}}` — always-on (KeepAlive)
- `{{LAUNCHD_PREFIX}}.wiki-watcher.{{VAULT_NAME}}` — 2x daily (off-hour times)
- `{{LAUNCHD_PREFIX}}.wiki-lint.{{VAULT_NAME}}` — weekly Sunday
- `{{LAUNCHD_PREFIX}}.daily-backup` — daily 03:33

---

## Pointer

**The authoritative playbook is `AGENT.md`.** Open it now. This file is the compact rulebook; that file is the step-by-step.

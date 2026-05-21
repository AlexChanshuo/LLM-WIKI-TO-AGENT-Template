# LLM-WIKI-TO-AGENT-Template

> A reproducible blueprint for building one private Obsidian knowledge base, one Telegram-native capture agent, and one paranoid GitHub backup — end to end, on a single Mac.

> **Provided by Alex Ma (馬驊)** — CC10 member, founder of [PainPoint Tech (痛點科技)](https://www.painpoint-ai.com).
> Contact: [alexma@painpoint-ai.com](mailto:alexma@painpoint-ai.com) · Web: [www.painpoint-ai.com](https://www.painpoint-ai.com)

---

## 中文簡介 (zh-TW)

這是一份 **meta-template**:讓你在一台 Mac 上,從零蓋出「Obsidian 知識庫 + Telegram 對話 Agent + GitHub 偏執備份」的完整堆疊。所有架構決策都來自 Andrej Karpathy 2026 年 4 月 3 日的 **「LLM Wiki」** gist。

**做法很簡單:**
1. `git clone` 這個 repo 到你的本機
2. 在這個資料夾打開 Claude Code(或 OpenAI Codex,本 template 兩邊都支援)
3. 跟它說:**「walk me through AGENT.md」**
4. 回答它問的 6 個問題,剩下 45–90 分鐘它會自己跑完

**蓋出來的是什麼?** 一個你自己擁有、會自己更新、可以用 Telegram 對話的私人知識庫。新訊息 / 文章 / 語音 / 照片進來 → Python hook 確定性存檔 → Claude 自動分類、抽重點、跨頁更新 wiki → 每天 03:33 偏執備份 → 你週末問它「上週重點?」秒答。

**詳細中文文件:**
- 📘 [`docs/zh-TW-overview.md`](./docs/zh-TW-overview.md) — 繁體中文完整總覽 (架構、四個操作、安全決策、常見問題)
- 🤖 [`AGENT.zh-TW.md`](./AGENT.zh-TW.md) — AGENT.md 中文導讀 (Claude / Codex 在執行什麼)
- 🎁 配套公開導讀: [`AlexChanshuo/Gift-for-Event`](https://github.com/AlexChanshuo/Gift-for-Event) — 馬驊 AI 知識庫分享會的全中文實戰指南

**作者:** 馬驊 (Alex Ma),CC10 成員、[痛點科技](https://www.painpoint-ai.com) 創辦人。聯絡: [alexma@painpoint-ai.com](mailto:alexma@painpoint-ai.com)。

---

## Think of it as a private library

Easiest way to grok the architecture: **stop thinking "knowledge base" and start thinking "library."** Every piece has a real-world equivalent.

> You walk past your private library every morning. A **Librarian** (a Telegram bot named `{{AGENT_NAME}}`) stands at the front desk. You toss a voice memo, an article, a half-formed thought into the drop box — they smile, confirm receipt, and put your contribution on the **Acquisitions cart**. Overnight, while you sleep, the library runs its cataloging shift: every item on the cart gets read, cross-referenced, filed onto the right shelf in the **Stacks**, and the **master card catalog** is updated. The original donation goes into a sealed archive (still on file, never edited). The next morning you wander in, ask the Librarian *"what was the gist of last week?"*, and they walk you straight to the right shelf — every claim cited with the catalog card it came from. Once a week, the library does a quiet **health check**: orphan books, stale guides, gaps where the collection is thin. The Librarian even hands you a list of new questions worth asking and new books worth buying. The library never has overdue paperwork because the only employee never gets bored.

That paragraph IS the whole system. Below is the literal mapping:

| In the library | In this repo | What it does |
|---|---|---|
| The **patron / scholar** (you) | The human | Donates material, asks questions, sets direction |
| The **Librarian** | `agents/{{AGENT_NAME}}/` — Hermes Telegram bot | Greets you, confirms receipt, never re-files anything itself |
| The **front-desk drop box** | The Telegram chat | Where donations land |
| The **Acquisitions cart** | `{{VAULT_NAME}}/raw/inbox/` | Where new donations wait, untouched, before cataloging |
| The **sealed archive** | `{{VAULT_NAME}}/raw/inbox/.processed/` | Originals, permanently preserved, never edited |
| The **Stacks** (catalogued shelves) | `{{VAULT_NAME}}/wiki/` | Where the structured knowledge lives — entities, concepts, syntheses |
| Each **catalog card** | A single `.md` file in `wiki/entities/`, `wiki/concepts/`, etc. | One canonical page per real-world thing |
| The **master card catalog** | `wiki/index.md` | Master index — read first when answering anything |
| The **librarian's daily journal** | `wiki/log.md` | Append-only timeline of every cataloging shift |
| The **librarian's training manual** | `CLAUDE.md` (and its `AGENTS.md` sibling for Codex) | The schema — filing conventions, NEVER rules, the librarian's job description |
| The **after-hours maintenance crew** | `_ops/` — launchd-scheduled shell scripts | Cataloging shifts, weekly walk-throughs, nightly off-site backup |
| **Off-site fireproof backup** | `_ops/scripts/daily-backup.sh` → private GitHub repos | Paranoid mirror, runs at 03:33 daily |

### The four library workflows (a.k.a. the four ops)

| Library workflow | In this repo | What happens |
|---|---|---|
| **Acquisitions shift** | `ingest` | An item from the cart gets read, classified, summarised, cross-referenced. New catalog cards created or updated. Item moved into the sealed archive. Daily journal updated. |
| **Stocktaking** | `compile` | After a flurry of manual edits in Obsidian, the master catalog regenerates itself from the current shelves. Touches only the index — never the books. |
| **Reference desk** | `query` | Patron asks a question. Librarian reads the master catalog, pulls the relevant books, synthesises an answer with every claim citing a catalog card, picks the right format (a markdown note, a comparison table, a Marp slide deck, a chart, a canvas), and **files the answer as a new catalog card** so future questions can cite it. |
| **Weekly health check** | `lint` | Walk the shelves. Flag orphan books, stale guides, broken cross-references, frontmatter mistakes, decisions overdue for review. **Also proactive:** the librarian suggests web searches that would close known gaps, open questions worth investigating, and recurring author names that should have their own catalog card. |

The whole point of using an LLM for this: the bookkeeping that makes humans abandon personal wikis (cross-references, deduping, summary upkeep, contradiction flagging) is exactly what an LLM doesn't mind doing forever. **Your maintenance cost approaches zero; the library compounds.**

> 中文版的圖書館比喻在 [`docs/zh-TW-overview.md`](./docs/zh-TW-overview.md) 「把它想成一座私人圖書館」一節。

---

## TL;DR

This template lets a human + Claude Code instance bootstrap, in a single session:

1. One **Obsidian vault** structured per Andrej Karpathy's "LLM Knowledge Base" three-layer pattern (`raw/` + `wiki/` + `CLAUDE.md`).
2. One **Hermes-powered Telegram librarian agent** that captures text / voice / photo / URLs into the vault's `raw/inbox/`.
3. One **paranoid launchd-scheduled daily GitHub backup** covering both the vault and the agent repo.

The entire system is extracted from a working 7-repo deployment. This template is the minimal, placeholder-driven version that produces exactly one of each.

---

## Origin

The pattern's **canonical source** is Andrej Karpathy's "LLM Wiki" gist (Apr 3, 2026): [`gist.github.com/karpathy/442a6bf555914893e9891c11519de94f`](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f). Karpathy explicitly invites copy-pasting it to your LLM agent; every architectural decision in this template traces back to that one file. A verbatim local copy lives at [`docs/research/sources/karpathy-2026-04-03-llm-wiki.md`](./docs/research/sources/karpathy-2026-04-03-llm-wiki.md).

Three community write-ups turned Karpathy's idea into shippable practice and inform the scaffolding here:

- **@hooeem** — "How to create your own LLM knowledge bases today (full course)" — the operator manual: automation ladder, `CLAUDE.md` template, lint prompts.
- **@defileo / Leo** — "Claude + Obsidian have to be illegal" — the command cookbook: best Claude Code one-liners for ingest, lint, morning-briefing.
- **AI Edge / Miles Deutscher** — "Ultimate Guide" — contributes "two vaults, not one" and the wiki-as-mega-prompt framing.

- Raw primary texts (verbatim): [`docs/research/sources/`](./docs/research/sources/)
- Condensed one-page synthesis: [`docs/research/SYNTHESIS.md`](./docs/research/SYNTHESIS.md)

Before modifying the pattern significantly, read Karpathy's gist first, then the three community sources in the order above.

---

## What this is

- A **meta-template**. Not a runnable program; a curated set of docs, folder skeletons, scripts, and placeholders that a Claude Code agent walks you through filling in.
- **Two human-authoritative docs** at the top level:
  - `README.md` (this file) — human onboarding.
  - `SETUP.md` — step-by-step human walkthrough.
- **Two agent-authoritative docs** at the top level:
  - `AGENT.md` — primary playbook for the Claude Code instance operating this template.
  - `CLAUDE.md` — session-start schema auto-loaded by Claude Code.
- **`templates/`** — skeletal files to copy into the new vault / agent / ops repos.
- **`docs/`** — longer explainers referenced by the above.
- **`examples/minimal-walkthrough.md`** — a worked end-to-end example.

---

## Who this is for

- A founder or solo operator on **macOS** who wants a private second brain that an LLM maintains for them.
- Comfortable with the terminal, `git`, and `launchctl` (or willing to let Claude Code handle them).
- Has: a GitHub account, an Obsidian install, a Claude Code subscription (Pro or higher), a Telegram account.

If any of those are missing, `SETUP.md` tells you where to get them.

---

## The 3-layer pattern in 60 seconds

Karpathy's "LLM Wiki" pattern. Credit: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f

```
              +---------------------------------------------+
  raw/        |  Immutable source documents                  |
              |  Articles, voice transcripts, clipped pages. |
              |  LLM reads. LLM never writes here.           |
              +---------------------------------------------+
                                  |
                                  v
              +---------------------------------------------+
  wiki/       |  LLM-maintained structured markdown          |
              |  Entity pages, concept atoms, decisions,     |
              |  source summaries, index, log.               |
              |  You read. LLM writes.                       |
              +---------------------------------------------+
                                  ^
                                  |
              +---------------------------------------------+
  CLAUDE.md   |  The schema (Claude Code session-start)      |
  AGENTS.md   |  The schema (Codex session-start; stub →     |
              |  points back to CLAUDE.md)                   |
              |  Routing rules, frontmatter contracts,       |
              |  few-shot examples, lint rules.              |
              |  The LLM's job description.                  |
              +---------------------------------------------+
```

Four operational cycles run against this structure: **ingest**, **compile**, **query**, **lint**. Query outputs can be markdown, comparison tables, Marp slide decks, matplotlib charts, or Obsidian canvases — and the good ones get filed back into the wiki as new pages, so explorations compound. Lint is both structural (orphans / broken wikilinks / contradictions) and proactive (web-search gaps, open questions, source gaps).

Works without RAG at moderate scale (~100 sources, ~hundreds of pages). Beyond that, escalate to [`qmd`](https://github.com/tobi/qmd) — see [`docs/02-vault-setup.md`](./docs/02-vault-setup.md).

---

## What gets built

One fresh directory tree, ready to push to three private GitHub repos:

```
{{LOCAL_ROOT}}/
├── {{VAULT_NAME}}/             ← Obsidian vault (repo: {{VAULT_REPO}})
│   ├── CLAUDE.md               ← schema (the contract)
│   ├── raw/                    ← inbox + articles + transcripts + assets
│   ├── wiki/                   ← entities + concepts + syntheses + outputs
│   └── templates/
├── agents/
│   └── {{AGENT_NAME}}/         ← Hermes Telegram bot (repo: {{AGENT_REPO}})
│       ├── SOUL.md             ← personality contract
│       ├── config.yaml         ← model routing, allowed tools
│       ├── hooks/              ← deterministic Python hooks
│       └── scripts/start.sh    ← launchd entry point
└── _ops/                       ← orchestration (repo: {{OPS_REPO}})
    ├── run-ingest.sh           ← 2-pass Claude classify + ingest
    ├── run-lint.sh             ← weekly health check
    ├── scripts/daily-backup.sh ← paranoid nightly backup
    └── launchd/                ← plists: librarian keep-alive, ingest, lint, backup
```

Three repos total. One vault, one agent, one ops backbone.

---

## How to use this template

Four commands. Everything else the agent walks you through.

```bash
# 1. Clone this template into the working directory of your choice
git clone <this-template-url> {{LOCAL_ROOT}}/LLM-WIKI-TO-AGENT-Template
cd {{LOCAL_ROOT}}/LLM-WIKI-TO-AGENT-Template

# 2. Open the folder in Claude Code
claude

# 3. Tell Claude: "walk me through AGENT.md — bootstrap the full stack"

# 4. Follow the prompts. Claude will ask for your {{PROJECT_NAME}},
#    {{VAULT_NAME}}, {{AGENT_NAME}}, {{TELEGRAM_BOT_HANDLE}}, GitHub
#    username, and domain description, then scaffold everything.
```

At the end you will have a working capture-to-vault loop and a scheduled backup.

---

## Prerequisites

| Requirement | Where to get it | Why |
|---|---|---|
| macOS (tested on Sonoma / Sequoia) | — | launchd scheduling, keychain |
| GitHub account | https://github.com | Three private repos |
| `gh` CLI | `brew install gh` | Repo creation + cloning |
| `git` | `xcode-select --install` | Version control |
| Obsidian | https://obsidian.md | Vault UI |
| Claude Code | https://claude.ai/download | The LLM agent running this template |
| Claude Code subscription | Pro or higher | OAuth token for `claude -p` |
| Hermes agent runtime | https://hermes-agent.nousresearch.com | The Telegram librarian |
| Telegram account + bot token | https://t.me/BotFather | Capture channel |
| OpenAI API key (optional) | https://platform.openai.com | Voice transcription via Whisper |
| `uv` Python package manager | `brew install uv` | Isolated venvs for any Python hooks |

One-time keychain setup for Claude Code OAuth is documented in `SETUP.md`.

---

## Next steps

1. Read `AGENT.md` if you are a Claude Code instance. That is your prime directive.
2. Read `SETUP.md` if you are a human who wants the linear walkthrough.
3. Skim `examples/minimal-walkthrough.md` for a worked case.
4. Read `docs/` for architectural background on any individual component.

---

## If you are an AI agent reading this, do this in order

1. **Stop. Open `AGENT.md` first.** That file is your playbook — this README is for humans.
2. **Then open `CLAUDE.md`** for the hard rules and placeholder tokens you will substitute.
3. **Then open `SETUP.md`** so you know what the human is being walked through in parallel.
4. **NEVER run `claude -p` from inside a Hermes agent.** Anthropic OAuth is first-party only — see the TOS rule in `CLAUDE.md`.
5. **NEVER use `git push --force`, `git reset --hard`, or `git commit --amend`** in the backup script or during scaffolding. Every backup is a new commit.
6. **NEVER let an LLM do file writes that must happen.** Use deterministic Python or shell hooks. LLMs get understanding and reply duties only.
7. **NEVER scaffold without confirming** `{{PROJECT_NAME}}`, `{{VAULT_NAME}}`, `{{AGENT_NAME}}`, `{{GITHUB_USER}}`, `{{TELEGRAM_BOT_HANDLE}}`, `{{DOMAIN_DESCRIPTION}}` with the human first.
8. **NEVER commit secrets.** `.env` and `auth.json` are gitignored; the canonical store is 1Password (or whatever secret vault the human uses).
9. **NEVER weaken the backup safety guarantees**: per-repo lockfile, bulk-delete tripwire (>20 deletions aborts that repo), pull-rebase-autostash before push, off-hour launchd schedule.
10. **ALWAYS pick off-hour schedule times** (e.g. 03:33, not 03:00) to avoid API thundering-herd patterns.

---

## License / acknowledgement

This pattern originates with Andrej Karpathy's "LLM Knowledge Bases" note (Apr 2026). Additional inspiration drawn from hoeem's "How to create your own LLM knowledge bases today" course and the AI Edge / Defileo write-ups. The three-layer structure (`raw/` + `wiki/` + `CLAUDE.md`), the four operational cycles (ingest / compile / query / lint), and the orphans heuristic are all from that lineage.

This template is extracted from a working private deployment and released for reuse. Use at your own risk; audit before running any script.

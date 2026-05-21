# 02 — Vault Setup

> **Prerequisite.** Obsidian installed and pointing at a cloned vault repo — see [`00-obsidian-new-mac-setup.md`](00-obsidian-new-mac-setup.md) for the fresh-Mac walkthrough. This doc picks up from there and scaffolds vault content.

> **What this doc is for.** Scaffold a new Obsidian vault that obeys the Karpathy three-layer pattern from [`01-architecture.md`](01-architecture.md). Covers folder layout, `CLAUDE.md`, frontmatter, `index.md` / `log.md` contracts, Obsidian plugins, and a minimum-viable checklist.

---

## Step zero — pick a domain and a name

The pattern only works if the vault has a **domain**. Empty vaults decay. Before you scaffold:

- Pick a topic wide enough to collect against for years (a business, a research area, a personal life domain) but narrow enough that routing rules converge.
- Decide `{{VAULT_NAME}}` — kebab-case, like `work-notes` or `research-vault`.
- Create `{{VAULT_REPO}}` as a private GitHub repo under `{{GITHUB_USER}}`.
- Decide `{{LOCAL_ROOT}}` — typically `/Users/<user>/<PROJECT_NAME>/{{VAULT_NAME}}/`.

If you are standing up multiple vaults (recommended — do not dump work + personal into one wiki, as Karpathy himself flags), repeat this doc per vault.

---

## Required folder structure

```
{{VAULT_NAME}}/
├── CLAUDE.md                   ← the schema (MOST IMPORTANT FILE)
├── README.md                   ← human + AI-agent onboarding (see 06)
├── .gitignore
├── raw/                        ← immutable; LLM reads only
│   ├── inbox/                  ← capture agent drops files here
│   │   ├── .classified/        ← Pass-1 JSON (gitignored)
│   │   └── .processed/         ← moved here after Pass-2 (gitignored)
│   ├── articles/               ← Web Clipper output
│   ├── transcripts/            ← voice notes / calls / dictation
│   ├── docs/                   ← PDFs converted via markitdown
│   ├── drive-imports/          ← Drive folder exports (if used)
│   └── assets/                 ← images
├── wiki/                       ← LLM-maintained
│   ├── index.md                ← master catalog (rebuilt each ingest)
│   ├── log.md                  ← append-only changelog
│   ├── entities/               ← one page per real-world thing
│   │   ├── people/
│   │   ├── companies/
│   │   ├── tools/
│   │   ├── books/
│   │   └── places/
│   ├── concepts/               ← ideas / areas / atoms
│   │   ├── projects/           ← PARA — active, deadlined
│   │   ├── areas/              ← PARA — ongoing domains
│   │   ├── resources/          ← PARA — reference
│   │   ├── atoms/              ← Zettelkasten — <300 words, densely linked
│   │   ├── frameworks/         ← mental models
│   │   └── archive/            ← completed / deprecated
│   ├── sources/                ← one summary per raw source
│   ├── syntheses/              ← cross-cutting pages
│   │   ├── decisions/          ← first-class, 90-day review_date
│   │   ├── meetings/
│   │   ├── reflections/
│   │   └── reading-notes/
│   ├── outputs/                ← query answers + lint reports + triage queue
│   └── attachments/images/
├── templates/                  ← Obsidian Templater templates per entity type
└── .obsidian/                  ← plugin configs (see below)
```

Omit what you do not need (e.g. a research vault may not need `entities/places/`), but keep the top-level split `raw/` vs `wiki/` vs schema intact — that is the pattern.

---

## `CLAUDE.md` — the minimum viable schema

`CLAUDE.md` is loaded at the start of every `claude -p` session. Keep it dense, directive, and under ~400 lines. Sections that must exist:

| Section | Purpose |
|---|---|
| **Overview** | One paragraph: what this vault is, what it is not, what time horizon |
| **Categorization framework** | Which taxonomies you use (PARA, Zettelkasten, supertags, CODE) and why |
| **Directory structure** | Tree diagram matching the folders above, one-line note per folder |
| **File conventions** | kebab-case filenames, date formats, `[[wikilinks]]`, bold first term |
| **Frontmatter** | Universal fields + per-type schemas (person, company, decision, source, atom) |
| **Routing rules** | "A message about X goes to path Y" — as explicit as possible |
| **Few-shot examples** | 3–6 real examples of "message in → pages out" — anchor Claude's behavior |
| **Operations** | What `/wiki-classify`, `/wiki-ingest`, `/wiki-query`, `/wiki-lint` each do |
| **Entity resolution rules** | How to dedupe "David Chen" vs "David" vs "david-chen" |
| **What this vault is NOT** | Hard negatives — other vaults' turf; bounces to the right librarian |

A thin `CLAUDE.md` produces an inconsistent wiki. A thick one makes the LLM feel like an employee rather than a contractor. Expect to refine few-shot examples after watching the first ~30 real captures land.

---

## Frontmatter conventions

All pages use YAML frontmatter. Universal fields:

```yaml
---
title: "..."
date_created: YYYY-MM-DD
date_modified: YYYY-MM-DD
summary: "1-2 sentences"
type: concept | entity | source | synthesis | output
status: draft | review | final
tags: [...]
related: [[wikilink]]
confidence: 0.0-1.0       # only on auto-classified pages
---
```

Per-type extensions — sample for a person entity:

```yaml
---
type: entity
entity_type: person
title: "David Chen"
aliases: [david, dchen]
company: [[entities/companies/whoscall]]
role: "Founder"
relationship: prospect
trust_level: 3
last_contacted: 2026-04-17
contact_cadence_days: 30
follow_up_due: 2026-05-17
threads: [[atoms/fraud-detection-2026q2]]
contact_methods: [telegram, email]
---
```

The point of rich frontmatter: **Dataview queries**. Once your people entities have `last_contacted` and `follow_up_due`, you get a rolling "who am I overdue with?" list for free. See the Dataview section below.

---

## Filename conventions

| Kind | Format | Example |
|---|---|---|
| Person | `{first-last}.md` | `david-chen.md` |
| Company | `{kebab}.md` | `whoscall.md` |
| Source from inbox | `{YYYYMMDD}-{slug}.md` | `20260417-magnesium-experiment.md` |
| Source from article | `{author}-{year}-{slug}.md` | `karpathy-2026-llm-kb.md` |
| Decision | `{YYYY-MM-DD}-{slug}.md` | `2026-04-17-followup-whoscall.md` |
| Atom | `{kebab-concept}.md` | `loss-aversion.md` |

Always kebab-case. Never spaces in filenames. Cross-refs always `[[wikilinks]]`.

---

## `index.md` and `log.md` contracts

### `index.md` — the master catalog
- **Rebuilt each ingest** (the LLM regenerates it from a Glob of the vault).
- Sections: by-type (entities, concepts, sources, syntheses) with counts and top-level Dataview tables.
- Humans use this as the landing page (see Homepage plugin below).
- Never hand-edit; treat as a compiled artifact.

### `log.md` — the changelog
- **Append-only.** Ingest and lint append; never rewrite history.
- One line per event: `- {YYYY-MM-DDTHH:MM} {op} {short description}`.
- Rolls forever; use `tail` to see recent activity.
- Humans audit here when a wiki page "appeared" or "changed" unexpectedly.

---

## Obsidian plugins (install order matters)

Launch Obsidian → `Open folder as vault` → pick `{{LOCAL_ROOT}}`. Turn off Restricted Mode. Install:

| Plugin | What it does | Settings notes |
|---|---|---|
| **Dataview** | SQL-like queries over frontmatter | Enable JS queries; powers all dashboards |
| **Templater** | Entity templates from `templates/` | Template folder = `templates` |
| **Obsidian Git** | Version-control safety net | `autoPullOnBoot: true`; set `autoSaveInterval: 0` and `autoPushInterval: 0` if you rely on the ops repo's scheduled backup; otherwise 30 min is a reasonable fallback |
| **Local Images Plus** | Download remote images locally | Hotkey "Download attachments for current file" → `Cmd+Shift+D` |
| **Tag Wrangler** | Bulk-rename tags as taxonomy evolves | — |
| **Linter** | Auto-format YAML frontmatter on save | Add per-type rules matching your `CLAUDE.md` |
| **Homepage** | Set `wiki/index.md` as landing page | — |
| **Kanban** | Pipeline-style vaults | Optional; only for deal/flow-oriented vaults |

**Settings → Files & Links:**
- New attachments → `In folder specified below` → `raw/assets`
- Default link type: `Wikilink`
- New link format: `Relative path to file`

---

## Search at scale (optional, `qmd`)

The `index.md` + read-relevant-pages pattern works well at moderate scale (~100 sources, ~hundreds of pages). Beyond that, the index gets noisy and the agent burns context reading pages it didn't need.

Karpathy's gist recommends [`qmd`](https://github.com/tobi/qmd) (Tobi Lütke) as the lightweight escalation: a local search engine for markdown files with hybrid BM25 + vector search and LLM re-ranking — all on-device. It exposes both:

- a **CLI** the LLM can shell out to (`qmd search "..." --top 5`)
- an **MCP server** Claude Code / Codex can use as a native tool

Install it once your wiki crosses the hundreds-of-pages mark — earlier is over-engineering. Add the MCP server to the relevant `.claude/mcp.json` (Claude Code) or Codex equivalent, and tell `CLAUDE.md` to prefer `qmd` over reading every index entry when the vault is large.

Until then, do not optimize. The index pattern carries you further than you'd think.

---

## AGENTS.md — model-agnostic schema entry point

The vault ships **two** schema-pointer files at root:

- `CLAUDE.md` — Claude Code auto-loads this at session start.
- `AGENTS.md` — OpenAI Codex auto-loads this at session start. The shipped template is a one-page stub that points right back at `CLAUDE.md` so the schema lives in exactly one place.

If you ever run multiple agents (Claude on Monday, Codex on Tuesday), keep them in lock-step by editing `CLAUDE.md` and leaving `AGENTS.md` alone. If the two ever diverge, it's a bug — converge on `CLAUDE.md`.

Per Karpathy's gist (Apr 3, 2026): "a document (e.g. CLAUDE.md for Claude Code or AGENTS.md for Codex) that tells the LLM how the wiki is structured."

---

## Obsidian Web Clipper

Install [Obsidian Web Clipper](https://obsidian.md/clipper). Add one named template per vault:

- Name: `{{VAULT_NAME}}`
- Vault: `{{VAULT_NAME}}`
- Note location: `raw/articles/`
- Properties block matching your source frontmatter (title, source URL, author, clipped date, tags, `type: source`, `status: raw`)

When clipping, pick the right template from the dropdown. Prevents cross-vault contamination.

---

## Dataview examples

In `wiki/index.md`:

```dataview
TABLE last_contacted, follow_up_due
FROM "wiki/entities/people"
WHERE follow_up_due <= date(today)
SORT follow_up_due ASC
```

This alone replaces a personal CRM. Extend the pattern: overdue decisions, stuck deals, stale atoms.

---

## Git wiring

```bash
cd {{LOCAL_ROOT}}
git init -b main
git remote add origin git@github.com:{{GITHUB_USER}}/{{VAULT_REPO}}.git
git add .
git commit -m "init: {{VAULT_NAME}} scaffold"
git push -u origin main
```

Then the `{{OPS_REPO}}` daily-backup script (see [`04-github-backup.md`](04-github-backup.md)) picks this repo up at 03:33 every night.

---

## `.gitignore` starter

```
# Runtime artifacts
raw/inbox/.classified/
raw/inbox/.processed/

# Obsidian workspace (per-machine UI state)
.obsidian/workspace*.json
.obsidian/cache
.obsidian/appearance.json

# OS noise
.DS_Store

# Local secrets
.env
```

Keep `.obsidian/community-plugins.json` and `.obsidian/plugins/<name>/data.json` tracked — those define the plugin set and vault settings another user (or a fresh Mac) needs to reproduce the vault. Plugin binaries themselves are re-downloadable; do not commit them unless you have a specific reason.

---

## Minimum viable vault checklist

Before wiring an agent to this vault, confirm:

- [ ] Folder tree matches the structure above
- [ ] `CLAUDE.md` exists with all 10 required sections
- [ ] `wiki/index.md` loads in Obsidian and the Homepage plugin points to it
- [ ] `wiki/log.md` exists (can be empty)
- [ ] At least one entity template in `templates/`
- [ ] `.gitignore` covers `.classified/`, `.processed/`, `.env`, `.DS_Store`
- [ ] Git remote is `{{GITHUB_USER}}/{{VAULT_REPO}}`
- [ ] First commit pushed
- [ ] Obsidian opens the vault without Restricted Mode errors
- [ ] Dataview + Templater + Obsidian Git + Linter installed and enabled
- [ ] Web Clipper template created for this vault
- [ ] Sample `raw/inbox/test-001.md` dropped in; ingest pipeline ([`03-hermes-agent.md`](03-hermes-agent.md) + ops scripts) processes it within one run window

---

## Cross-references

- [`01-architecture.md`](01-architecture.md) — why these three layers
- [`03-hermes-agent.md`](03-hermes-agent.md) — the Hermes Telegram librarian that writes into `raw/inbox/`
- [`04-github-backup.md`](04-github-backup.md) — how this vault is backed up nightly
- [`06-ai-onboarding-readme.md`](06-ai-onboarding-readme.md) — how to write the vault's README so another AI agent can orient itself fast

---

## If you're an AI agent reading this

1. **Do not invent folders.** If the `CLAUDE.md` routing table does not cover a new case, flag it in `wiki/outputs/triage-queue.md` rather than silently creating a folder; the human tunes the schema, you follow it.
2. **Rebuild `index.md`, append to `log.md`.** Every ingest run bumps index (clean slate rewrite acceptable) and appends to log (never rewrite history).
3. **Keep `raw/` immutable.** The only files that should ever change inside `raw/` are the `.classified/` and `.processed/` submarkers that the ingest pipeline maintains — never rewrite source content once it lands.

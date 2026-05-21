# Research Synthesis — LLM Wiki (Karpathy pattern)

> **The canonical origin: Karpathy's "LLM Wiki" gist** ([`gist.github.com/karpathy/442a6bf555914893e9891c11519de94f`](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f), Apr 3, 2026). A verbatim local copy lives at [`sources/karpathy-2026-04-03-llm-wiki.md`](./sources/karpathy-2026-04-03-llm-wiki.md). Three community write-ups — @hooeem, @defileo, AI Edge — turned the gist into shippable practice and inform the scaffolding here.

> **What this doc is for.** The intellectual genealogy of the template. One page. Canonical source, three community interpretations, shared core idea, concrete recipe.

---

## Origin: one canonical source, three community interpretations

Before any of the synthesis below, the short version:

- **Canonical source — Karpathy's "LLM Wiki" gist.** Every architectural decision in this template traces back to that one file. Karpathy explicitly invites copy-pasting the gist to your LLM agent. Two key updates in his current text vs. some of the older community write-ups: (a) explicit AGENTS.md support alongside CLAUDE.md for Codex users; (b) lint is *both* structural *and* proactive — it should also suggest web searches, open questions, and new sources to investigate; (c) query outputs can be markdown, comparison tables, Marp slide decks, matplotlib charts, or Obsidian canvases — and good answers file back as wiki pages.
- **@hooeem, @defileo, AI Edge are downstream interpretations.** Each one took Karpathy's note and turned it into something you can ship. All three are useful; none of them override Karpathy's gist if there's a conflict.
- **Primary texts live in [`sources/`](./sources/)** as verbatim copies. When in doubt, read them; the rest of this synthesis is a condensation.

The rest of this document is the condensed view. If you are about to propose a significant change to the pattern, read Karpathy's gist first, then the three community sources.

---

## The single source and three riffs

All of the current "Claude + Obsidian" community material traces back to one post: **Andrej Karpathy, "LLM Knowledge Bases," April 3, 2026** — a gist introducing a pattern for using an LLM to incrementally build and maintain a personal wiki instead of doing one-shot RAG queries.

Canonical link: `https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f`

Within a week, three practitioners turned it into practical how-to material:

| Source | Date | Format | Unique contribution |
|---|---|---|---|
| **Karpathy** (gist) | Apr 3, 2026 | Prose manifesto + schema sketch | The three-layer pattern; "LLMs don't get bored" thesis |
| **@hooeem** (Twitter course) | Apr 7, 2026 | Long-form course (~45k chars) | Levels-of-automation ladder (L1–L5); `CLAUDE.md` template; lint prompts; GitHub Actions example |
| **AI Edge / Miles Deutscher** | Apr 8, 2026 | Medium guide (~15k chars) | "Two vaults, not one"; "you can skip Obsidian, use the terminal"; wiki-as-mega-prompt use case |
| **@defileo / Leo** | Apr 9, 2026 | Manifesto + command cookbook (~18k chars) | Best Claude Code one-liners: ingest, lint, morning-briefing, transcript |

Signal ranking for implementing this template:

1. **hoeem** — highest signal-to-noise; the automation ladder is load-bearing
2. **defileo** — best copy-paste commands for Claude Code
3. **AI Edge** — useful for "two vaults" and the "mega-prompt" framing; mostly a thinner wrapper

Karpathy sets the direction; the other three tell you how to actually ship it on a Mac.

---

## The shared core idea

> Don't use LLMs as a search engine with amnesia. Build a **persistent, compounding wiki** that the LLM maintains for you. The wiki sits between you and raw sources. Every new source enriches it; every query gets filed back as a new page.

The insight is less about retrieval and more about **maintenance**. The reason humans abandon personal wikis is that bookkeeping (linking, deduping, refactoring, summarizing) grows faster than the value it produces. LLMs do not get bored, do not forget a convention mid-session, can touch fifteen files in a single pass. Maintenance cost approaches zero; the wiki compounds.

This connects to Vannevar Bush's Memex (1945). Bush described the knowledge store we wanted. He could not solve "who does the maintenance." The LLM does.

---

## Three layers

| Layer | Role | Writer | Reader |
|---|---|---|---|
| `raw/` | Immutable source documents | Humans + capture agents | LLMs (read-only) |
| `wiki/` | Structured, LLM-maintained markdown | LLMs | Humans + LLMs |
| `CLAUDE.md` | Schema / job description for the LLM | Humans | LLMs at session start |

`CLAUDE.md` is the load-bearing file. It tells the LLM: folder conventions, frontmatter schemas, entity-resolution rules, routing tables, few-shot examples, operation definitions. A thin schema produces an inconsistent wiki; a thick schema makes the LLM feel like an employee rather than a contractor.

---

## Four operations

- **Ingest** — new raw source → summary + concept/entity pages + index bump + log entry.
- **Compile** — weave new info into existing structure; refactor when the graph demands it.
- **Query** — question → LLM reads index, loads relevant pages, returns cited answer, **files the answer back** into `wiki/outputs/`. Queries compound.
- **Lint** — weekly health check: contradictions, orphans, broken `[[wikilinks]]`, missing frontmatter, stale decisions.

hoeem's contribution: an automation ladder for operating this.

| Level | Mechanism | Example |
|---|---|---|
| L1 | `claude -p "..."` one-shot | Manual compile after a reading session |
| L2 | Custom slash commands | `.claude/commands/wiki-ingest.md` → `/wiki-ingest` |
| L3 | Scheduled tasks | `cron` / Claude Desktop `/schedule` / `launchd` |
| L4 | Cloud automation | GitHub Actions runs while laptop is off |
| L5 | Agent Skills | `.claude/skills/wiki-maintainer/SKILL.md` triggers on context |

This template lives at **L3** with shades of L5 (the agent's deterministic save hook is skill-like, but enforced by Python not markdown).

---

## Concrete recipe (consolidated)

### Folder layout

```
my-vault/
├── CLAUDE.md
├── raw/
│   ├── inbox/        ← agents + humans drop files here
│   ├── articles/     ← Web Clipper output
│   ├── papers/
│   ├── transcripts/
│   └── assets/
├── wiki/
│   ├── index.md      ← AI-rebuilt each ingest
│   ├── log.md        ← append-only changelog
│   ├── entities/     ← people, companies, tools, books, places
│   ├── concepts/     ← projects, areas, atoms, frameworks
│   ├── sources/      ← one summary per raw source
│   ├── syntheses/    ← decisions, meetings, reflections, reading-notes
│   ├── outputs/      ← filed query answers + lint reports
│   └── attachments/images/
└── templates/
```

### File conventions

- kebab-case filenames (`active-inference.md`, not `Active Inference.md`)
- Source summaries: `{author}-{year}-{short-title}.md` or `{YYYYMMDD}-{slug}.md`
- All pages have YAML frontmatter: `title`, `date_created`, `date_modified`, `summary`, `type`, `status`, `tags`
- Cross-refs: `[[wikilinks]]` (Obsidian-native)

### Toolchain

| Tool | Role |
|---|---|
| Obsidian | vault viewer + graph + plugin host |
| Claude Code (\$20/mo Pro min) | the agent that reads/writes the wiki via `claude -p` |
| Obsidian Web Clipper | browser → `raw/articles/` markdown |
| Local Images Plus (plugin) | download remote images locally |
| MarkItDown (Microsoft, free) | PDF/Word → markdown |
| Dataview (plugin) | SQL-like queries over frontmatter |
| Obsidian Git (plugin) | auto-commit safety net |
| Templater (plugin) | entity templates |
| Linter (plugin) | auto-format frontmatter |
| qmd (Lütke) | local hybrid search when the wiki gets big |

---

## Where this template extends the original

Karpathy + the community stop at "the LLM maintains the wiki." This template adds three spines:

1. **Capture mouth.** A Hermes Telegram librarian, with a deterministic Python save hook, writes raw into `raw/inbox/` regardless of whether the LLM "remembers" to save. Full doc: [`../03-hermes-agent.md`](../03-hermes-agent.md).
2. **Paranoid backup.** A nightly shell script pushes all repos to GitHub with eight explicit safety guarantees (no `--force`, no `--hard`, no `--amend`, lockfiles, bulk-delete tripwire, per-repo isolation, per-run JSON logs). Full doc: [`../04-github-backup.md`](../04-github-backup.md).
3. **OAuth split.** Claude does ingest via `claude -p` (first-party). ChatGPT does chat inside Hermes (Codex OAuth, sanctioned). No Anthropic OAuth in third-party agents. Full doc: [`../05-oauth-split.md`](../05-oauth-split.md).

The Karpathy pattern tells you **what** to build. This template tells you **how to keep it running unattended on a Mac for years.**

---

## Nuggets worth remembering

- **Two vaults by default.** Karpathy himself recommends splitting work and personal. Do not dump everything into one wiki.
- **Obsidian is optional.** The vault is just markdown; Claude Code will work with it directly. Obsidian is the viewer/IDE.
- **Wiki as mega-prompt.** Once the wiki is rich, feeding slices of it into other LLM prompts turns it into a personalized context layer.
- **The Orphans toggle in Obsidian** (three dots → top right → Orphans) surfaces concepts that did not connect — a hint about where to add more sources.
- **Community implementations exist.** `kfchou/wiki-skills`, `llm-wiki-compiler`, `sage-wiki`, `CRATE`, `Fabric`. Evaluate before rolling your own.

---

## Citations

- Karpathy, A. (2026, April 3). *LLM Knowledge Bases.* GitHub gist `442a6bf555914893e9891c11519de94f`.
- hoeem (2026, April 7). *How to create your own LLM knowledge bases today (full course).* Twitter long-form.
- AI Edge / Deutscher, M. (2026, April 8). *Claude Code + Obsidian Ultimate Guide.* aiedgehq.co newsletter.
- Defileo / Leo (2026, April 9). *Claude + Obsidian have to be illegal.* Twitter thread.
- Bush, V. (1945). *As We May Think.* The Atlantic — for the Memex lineage.

---

## If you're an AI agent reading this

1. **The pattern is three-layer + four-op.** Do not re-architect on the fly; almost any refactor that collapses the layers or drops an op is a regression.
2. **`CLAUDE.md` is the schema.** Everything downstream — ingest, lint, query, routing — is downstream of how tight that file is. Improve it before you improve anything else.
3. **Karpathy's gist is canonical; hoeem is the best operator-level reading.** If you need to justify a decision in a PR or a discussion, cite those two.

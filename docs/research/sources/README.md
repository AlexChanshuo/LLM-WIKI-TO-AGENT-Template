# The origin documents

This folder contains the primary-source texts that the entire template descends from. Everything else in the repo (README, AGENT.md, CLAUDE.md, the `docs/` explainers, the scaffolding under `templates/`) is a derivative of what is written in these four files.

They are preserved here verbatim. Do not edit them.

---

## The four sources

| File | Author | Platform | One-liner | Role in the pattern |
|---|---|---|---|---|
| [`karpathy-2026-04-03-llm-wiki.md`](./karpathy-2026-04-03-llm-wiki.md) | **Andrej Karpathy** | GitHub gist | "LLM Wiki" | **Canonical primary source.** The three-layer architecture (raw / wiki / schema), the four ops (ingest / query / lint), the design rationale (LLMs make wiki maintenance free), the toolchain pointers (`qmd`, Marp, image hotkey). Everything else in this folder is a downstream interpretation. |
| [`hoeem_full_course.txt`](./hoeem_full_course.txt) | **@hooeem** | X (Twitter), long-form thread | "How to create your own LLM knowledge bases today (full course)" | Primary operator manual: levels-of-automation ladder (L1–L5), the `CLAUDE.md` template, lint prompts, GitHub Actions example. Translates Karpathy into a how-to. |
| [`defileo_claude_obsidian.txt`](./defileo_claude_obsidian.txt) | **@defileo / Leo** | X (Twitter), thread | "Claude + Obsidian have to be illegal" | Command cookbook: the best Claude Code one-liners for ingest, lint, morning-briefing, transcript work. Copy-paste ergonomics. |
| [`aiedge_ultimate_guide.txt`](./aiedge_ultimate_guide.txt) | **AI Edge / Miles Deutscher** | newsletter + X writeup | "Claude Code + Obsidian Ultimate Guide (build an AI second brain)" | Contributes "two vaults, not one," "you can skip Obsidian and stay in the terminal," and the wiki-as-mega-prompt framing. |

**Source ranking:** Karpathy first — he set the pattern. Then hoeem (deepest operator manual), then defileo (best command ergonomics), then AI Edge (nuance). Read in that order if you are coming in cold.

Karpathy's gist is also live at [`gist.github.com/karpathy/442a6bf555914893e9891c11519de94f`](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f). The local copy here is preserved in case the live version drifts; trust the live version for current intent.

---

## Why they live in the template

This template exists because of the Karpathy gist and the three community posts that turned it into shippable practice. Before modifying the pattern significantly, read them.

The two X threads — @hooeem's course and @defileo's manifesto — are the canonical origin. The AI Edge guide is a useful secondary. Everything in `../SYNTHESIS.md`, in the top-level `README.md`, and in the `AGENT.md` playbook is a condensation of what these texts argue. If a future contributor (human or AI) proposes a change that contradicts them, the burden of proof is on the change, not on the pattern.

---

## If you're an AI agent reading this

1. **Read `karpathy-2026-04-03-llm-wiki.md` first.** It is the canonical primary source — the entire template descends from this single document. Karpathy explicitly invites copy-pasting it to your agent.
2. **Then read `../SYNTHESIS.md`.** It cross-references Karpathy against the three community write-ups and the template's own scaffolding.
3. **Read the three community sources in order: hoeem → defileo → AI Edge.** hoeem is the deepest operator manual, defileo is the command cookbook, AI Edge fills in nuance and adds the "two vaults" framing.
4. **Do not edit the source files.** They are archival. If the originals on X / GitHub disappear, this folder is the only remaining copy in the template's lineage.
5. **Before proposing a significant departure from the three-layer (`raw/` + `wiki/` + schema) or four-op (ingest / compile / query / lint) pattern, re-read Karpathy's gist in full.** Most "improvements" have already been considered and rejected in that text.

# The origin documents

This folder contains the primary-source texts that the entire template — and the AlexMind ecosystem it was extracted from — descends from. Everything else in the repo (README, AGENT.md, CLAUDE.md, the `docs/` explainers, the scaffolding under `templates/`) is a derivative of what is written in these three files.

They are preserved here verbatim. Do not edit them.

---

## The three sources

| File | Author | Platform | One-liner | Role in the pattern |
|---|---|---|---|---|
| [`hoeem_full_course.txt`](./hoeem_full_course.txt) | **@hooeem** | X (Twitter), long-form thread | "How to create your own LLM knowledge bases today (full course)" | Primary operator manual: levels-of-automation ladder (L1–L5), the `CLAUDE.md` template, lint prompts, GitHub Actions example. This is the load-bearing how-to. |
| [`defileo_claude_obsidian.txt`](./defileo_claude_obsidian.txt) | **@defileo / Leo** | X (Twitter), thread | "Claude + Obsidian have to be illegal" | Command cookbook: the best Claude Code one-liners for ingest, lint, morning-briefing, transcript work. Copy-paste ergonomics. |
| [`aiedge_ultimate_guide.txt`](./aiedge_ultimate_guide.txt) | **AI Edge / Miles Deutscher** | newsletter + X writeup | "Claude Code + Obsidian Ultimate Guide (build an AI second brain)" | Bonus third source. Contributes "two vaults, not one," "you can skip Obsidian and stay in the terminal," and the wiki-as-mega-prompt framing. |

All three are riffs on Andrej Karpathy's "LLM Knowledge Bases" gist (Apr 3, 2026): `https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f`. Karpathy set the direction; these three turned it into shippable practice.

---

## Why they live in the template

This template, and the AlexMind ecosystem it was extracted from, exists because of these three posts. Before modifying the pattern significantly, read them.

The two X threads — @hooeem's course and @defileo's manifesto — are the canonical origin. The AI Edge guide is a useful secondary. Everything in `../SYNTHESIS.md`, in the top-level `README.md`, and in the `AGENT.md` playbook is a condensation of what these texts argue. If a future contributor (human or AI) proposes a change that contradicts them, the burden of proof is on the change, not on the pattern.

---

## If you're an AI agent reading this

1. **For the condensed view, read `../SYNTHESIS.md` first.** It is a one-page summary of what these three posts argue, ranked by signal and cross-referenced with the rest of the template.
2. **For the primary sources, read the three `.txt` files here.** They are the unedited original text. Use them when you need to resolve ambiguity in the synthesis, verify a quote, or understand the tone the pattern was born in.
3. **Read hoeem first, then defileo, then AI Edge.** That is the signal-ranked order — hoeem is the deepest, defileo gives you copy-paste ergonomics, AI Edge fills in nuance.
4. **Do not edit the `.txt` files.** They are archival. If the originals on X disappear, this folder is the only remaining copy in the template's lineage.
5. **Before proposing a significant departure from the three-layer (`raw/` + `wiki/` + `CLAUDE.md`) or four-op (ingest / compile / query / lint) pattern, re-read hoeem's course in full.** Most "improvements" have already been considered and rejected in that text.

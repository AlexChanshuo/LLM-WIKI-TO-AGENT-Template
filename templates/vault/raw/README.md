# raw/ — Immutable Source Layer

This directory is **layer 1 of the Karpathy three-layer pattern**: the faithful record of what was captured, exactly as captured. It is the provenance substrate that `wiki/` is built on top of.

> **Owning repo:** {{VAULT_REPO}}
> **Writers:** {{AGENT_NAME}} ({{AGENT_REPO}}) via deterministic hooks; Obsidian Web Clipper; manual conversion tools. **Never an LLM.**
> **Readers:** Claude Code during the `ingest` op. Read-only.

---

## The contract

1. **Immutable.** Once a file lands in `raw/`, its bytes never change.
2. **Append-only at the directory level.** New files may be added. Existing files are never edited, renamed, or deleted.
3. **LLM read-only.** Every LLM session — including every `ingest` / `compile` / `query` / `lint` run — has write access to `wiki/` only. `raw/` is opened with read access.
4. **One file per source document.** A Telegram message, a clipped article, a calendar event, a transcribed voice note — each gets its own file with its own provenance.
5. **Provenance in frontmatter.** Every raw file carries YAML frontmatter capturing where it came from, when it was fetched, and a hash of its content. No raw file is valid without it.

---

## Layout

```
raw/
├── inbox/                  ← {{AGENT_NAME}} drops captures here
│   ├── .classified/        ← Pass-1 classification JSON (transient)
│   └── .processed/         ← moved here after ingest completes (gitignored)
├── articles/               ← Obsidian Web Clipper output
├── transcripts/            ← long voice notes, call recordings
├── docs/                   ← PDFs converted to markdown
└── assets/                 ← image and file attachments
```

Adjust leaf folders to the domain, but the top-level spine (`inbox/`, one folder per capture type) stays.

---

## Required frontmatter

Every raw file must carry at least these fields:

```yaml
---
source: telegram | web-clipper | calendar | voice | manual | ...
source_url: "..."              # if applicable
captured_at: 2026-04-20T15:30:42+08:00
sha256: "..."                  # of the file body (excluding frontmatter)
captured_by: {{AGENT_NAME}} | web-clipper | owner-manual | ...
---
```

Agent-written captures add more: `tg_message_id`, `sender`, `attendees`, `google_event_id`, etc. — whatever the source supports. The rule is: **preserve everything the source knows.** The `ingest` op can always ignore fields it doesn't need; it can never recover fields that weren't captured.

---

## NEVER rules

1. **NEVER edit a raw file.** Not to fix a typo. Not to add a tag. Not to "clean up" whitespace. If you need to correct something, write a source summary in `wiki/sources/` with the correction noted.
2. **NEVER delete a raw file.** Processed files move to `raw/inbox/.processed/` (gitignored), not `/dev/null`. If a file is genuinely spam or a mistake, move it to `raw/.graveyard/` with a one-line reason in a sibling `.graveyard/NOTES.md`.
3. **NEVER rename a raw file.** Its filename encodes capture metadata ({timestamp}-{source-id}.md) that `wiki/sources/` references.
4. **NEVER write to `raw/` from an LLM.** Only deterministic hooks (agent code, web clipper, manual tooling) put files here. If you are an LLM and find yourself wanting to write to `raw/`, stop — you want `wiki/sources/` instead.
5. **NEVER commit a raw file without its frontmatter.** Provenance is load-bearing. A file without it is unusable downstream.
6. **NEVER assume a raw file is private.** Treat captured content as sensitive by default; scrubbing happens at the `wiki/external/` boundary, not here.

---

## Why this layer exists

- **Ingest is idempotent only if the source is stable.** If `raw/` mutates, re-ingesting the same file would produce different wiki output. That breaks audit trails and makes debugging bad ingests impossible.
- **The wiki is a lossy projection.** The `ingest` op summarizes, categorizes, and cross-links — all of that is interpretation. The raw file is ground truth you can always re-read.
- **Model upgrades are cheap if `raw/` is intact.** Swap a better model into the `ingest` op and re-process old inbox files — you get a better wiki without new captures.

---

## If you're an AI agent reading this directory

1. **Read, never write.** Every write belongs in `wiki/`, specifically `wiki/sources/` for per-document summaries.
2. **Check the frontmatter first.** `source`, `captured_at`, `sha256` tell you what you're looking at and whether it's been tampered with.
3. **Cite via `raw_path` in the corresponding source summary.** Downstream `query` ops follow that pointer to re-read ground truth.
4. **If a raw file looks malformed or truncated, flag in `wiki/outputs/triage-queue.md`** — do not attempt to "fix" it.

Cross-reference: full schema and op contracts live in [`../CLAUDE.md`](../CLAUDE.md). Orchestration lives in {{OPS_REPO}}. The capture agent is {{AGENT_REPO}}.

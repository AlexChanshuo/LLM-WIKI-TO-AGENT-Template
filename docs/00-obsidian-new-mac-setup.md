# 00 — Obsidian on a New Mac

> **What this doc is for.** You have a fresh (or freshly reset) Mac and a vault repo already on GitHub. Get Obsidian installed, configured, pointing at the cloned vault, and quietly committing changes via Git — end-to-end, in ~15 minutes. This is the very first step in any new-machine bootstrap. After this doc, continue to [`02-vault-setup.md`](02-vault-setup.md) for vault-content scaffolding or to [`../SETUP.md`](../SETUP.md) for whole-system bootstrap.

---

## TL;DR

If you're on a fresh Mac with Homebrew installed and a vault repo that already exists on GitHub, these commands get you from zero to Obsidian open on your vault in roughly 15 minutes:

```bash
brew install --cask obsidian
brew install gh
gh auth login
mkdir -p ~/Code
gh repo clone {{GITHUB_USER}}/{{VAULT_REPO}} ~/Code/{{VAULT_NAME}}
open -a Obsidian ~/Code/{{VAULT_NAME}}
```

Then in Obsidian: trust the vault, turn off Restricted Mode, install the 4 required community plugins, and you're done. Full steps below.

---

## 1. Prerequisites checklist

Before starting, confirm each of the following on the new Mac:

| Requirement | How to check / install | Why |
|---|---|---|
| macOS Sonoma or newer | `sw_vers` | Obsidian 1.5+ requires Sonoma |
| Apple ID signed in | System Settings > Apple ID | Keychain entry used by git / gh |
| Xcode Command Line Tools | `xcode-select --install` | Provides git |
| Homebrew (recommended) | `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` | Simpler install of every tool below |
| GitHub CLI (`gh`) | `brew install gh && gh auth login` | Cloning private vault repos |
| Claude Code CLI (`claude`) | Install from https://claude.ai/download | Needed later for ingest; not for Obsidian itself |
| Telegram account | Any phone | Needed later to connect the librarian bot |
| A non-iCloud work folder | e.g. `~/Code/` or `~/Developer/` | Must not live inside iCloud Drive; see step 5 |

If any of Claude Code, Telegram, or Hermes are missing, that is fine for this doc — those are for later steps in `SETUP.md`. Only git, `gh`, and Obsidian itself are hard prerequisites here.

---

## 2. Install Obsidian

Two supported paths. Pick one.

### Option A — Homebrew Cask (recommended)

```bash
brew install --cask obsidian
```

This drops `Obsidian.app` in `/Applications/`, registers it with macOS, and keeps it auto-updatable via `brew upgrade --cask obsidian`.

### Option B — Direct DMG

1. Go to https://obsidian.md
2. Click Download for macOS; the browser downloads a `.dmg`.
3. Open the DMG, drag `Obsidian.app` to `/Applications/`.
4. Eject the DMG.

### Version compatibility

This template was written against Obsidian 1.5+. Anything older will miss the Bases / Dataview UX improvements several plugins below expect. Check with:

```bash
/Applications/Obsidian.app/Contents/MacOS/Obsidian --version
```

### First launch — Gatekeeper

The first time you open Obsidian, macOS shows a dialog warning that the app was downloaded from the internet. Click Open. If macOS blocks it outright (older Gatekeeper policy), open System Settings > Privacy & Security and click Open Anyway next to the Obsidian entry.

---

## 3. First-run configuration (skip the paid prompts)

Obsidian opens a welcome screen offering two paid services. Decline both.

| Prompt | What to do | Why |
|---|---|---|
| Obsidian Sync signup | Skip / Close | We use Git + the daily-backup script, not Obsidian Sync. Running both at once causes write-race conflicts. |
| Obsidian Publish signup | Skip / Close | Not used in this template |
| Language | English | All repo docs are English-only |
| Theme | Whatever you like | Cosmetic; not tracked in git (see `.gitignore`) |

Close the welcome vault (Obsidian opens a default "Obsidian Help" vault). You will open your real vault in step 6.

---

## 4. Clone your vault repo

Assumes the vault repo `{{GITHUB_USER}}/{{VAULT_REPO}}` already exists on GitHub. If it does not, stop here and do `SETUP.md` step 3 first — it scaffolds the repo — then come back.

Pick a parent directory. The rest of this doc uses `~/{{LOCAL_ROOT}}/` (typically `~/Code/` or `~/Developer/`). Then:

```bash
mkdir -p ~/{{LOCAL_ROOT}}
cd ~/{{LOCAL_ROOT}}
gh repo clone {{GITHUB_USER}}/{{VAULT_REPO}} {{VAULT_NAME}}
cd {{VAULT_NAME}}
ls CLAUDE.md && echo "vault cloned"
```

### Critical: do NOT clone into iCloud-synced folders

macOS defaults (Documents, Desktop) are often iCloud-synced. iCloud fights with Git and Obsidian in several ways:

- iCloud lazy-downloads files, so Obsidian sees `.md` files as tombstones and cannot read them.
- iCloud rewrites file metadata on every sync, producing spurious `git status` changes.
- iCloud has its own conflict-resolution (`file (conflicted copy).md`) that collides with Git's.
- iCloud + Obsidian Git + the daily-backup script together produce unrecoverable three-way conflicts.

Clone into `~/Code/`, `~/Developer/`, `~/Projects/`, or anywhere outside iCloud. Verify:

```bash
mdls -name kMDItemIsUbiquitous ~/{{LOCAL_ROOT}}/{{VAULT_NAME}}
# Expect: kMDItemIsUbiquitous = 0   (NOT 1)
```

If the command prints `1`, move the clone out of iCloud before opening in Obsidian.

---

## 5. Open the vault in Obsidian

1. Launch Obsidian (from `/Applications/` or Spotlight).
2. From the vault switcher (bottom-left) click Open folder as vault.
3. Navigate to `~/{{LOCAL_ROOT}}/{{VAULT_NAME}}` and click Open.
4. Obsidian asks Trust author and enable plugins? — click Trust. Plugins from the repo's `.obsidian/community-plugins.json` will enable.
5. In the file tree on the left, confirm `CLAUDE.md` is visible at the top level. It is a normal `.md` file, not hidden. If it is missing, the clone failed — re-check step 4.

---

## 6. Install required community plugins

Open Settings (`Cmd+,`) > Community plugins > Turn on community plugins. Dismiss the warning. Then Browse and install each of the four below, configured exactly as described.

| Plugin | Why | Key settings |
|---|---|---|
| **Obsidian Git** | Pulls before you edit; commits after you edit; safety net alongside the nightly `_ops` backup | Auto-pull on startup: ON. Auto-pull interval: 10 min. Auto-commit after file change: OFF (or 30 min if you want belt-and-braces). Auto-push: OFF — the `_ops` daily-backup owns pushes. Commit message template: `vault: {{date}} {{numFiles}} files`. |
| **Dataview** | Powers every query in `wiki/index.md`, dashboards, lint queries | Enable JavaScript Queries: ON. Refresh interval: 2500ms. |
| **Templater** | Scaffolds entity frontmatter when you create a new person / company / decision page | Template folder: `templates`. Trigger on new file: ON (only if the vault has new-file templates; otherwise OFF). |
| **Web Clipper companion** | Receives articles clipped from the browser extension (see step 9) | Set vault = `{{VAULT_NAME}}`. Note folder: `raw/articles/`. |

For each plugin:

1. Settings > Community plugins > Browse.
2. Search the plugin name, click Install, then Enable.
3. A gear icon appears next to the plugin — open it and apply the settings above.
4. Verify: Settings > Community plugins, the plugin is listed and toggled on.

### Obsidian Git credential setup

The plugin uses the system git configured in step 1 via `gh auth login`. Confirm it works:

```bash
cd ~/{{LOCAL_ROOT}}/{{VAULT_NAME}}
git fetch origin
```

If this prompts for credentials, run `gh auth setup-git` once, then retry. If you prefer SSH instead of HTTPS, swap the remote:

```bash
git remote set-url origin git@github.com:{{GITHUB_USER}}/{{VAULT_REPO}}.git
ssh -T git@github.com   # confirm your SSH key is loaded
```

---

## 7. Enable recommended core plugins

Settings > Core plugins. Turn ON:

- Backlinks
- Outgoing links
- Tag pane
- Graph view
- Outline
- File recovery (critical — saves snapshots every 5 min; a Templater misfire or a bad find-replace is survivable)
- Templates (Obsidian's built-in, separate from Templater community plugin)

These are all local-only and off by default on a fresh install.

---

## 7b. Image download hotkey (Karpathy's recommended config)

The Karpathy gist explicitly calls this out — set it up once and forget:

1. Settings → Files and links → Attachment folder path → `raw/assets` (or wherever your raw assets live).
2. Settings → Hotkeys → search for `Download` → find **"Download attachments for current file"** → bind to `Cmd+Shift+D`.
3. After clipping a web article via Web Clipper (step 9), open the clipped note and hit `Cmd+Shift+D`. Every remote image referenced in the markdown gets downloaded to disk and rewritten to a local path.

Why: an LLM can view images you pass it as files, but cannot reliably fetch image URLs at query time. Local images means the LLM can read the markdown text first, then view the specific images it needs as separate steps. Inline images in markdown are not natively readable in one pass — that's an LLM-capability limit, not an Obsidian one.

The `Local Images Plus` community plugin (installed in step 7) is what implements the download command. Without it, the hotkey shows nothing.

---

## 8. Editor conventions

Settings > Files & Links:

| Setting | Value | Why |
|---|---|---|
| Default location for new notes | In the folder specified below |
| New note folder | `raw/inbox/` | Matches the routing contract in `CLAUDE.md` — human captures land in the same inbox the Telegram bot writes to, and the next ingest pass picks them up |
| Use `[[wikilinks]]` | ON | The template's cross-reference convention |
| New link format | Relative path to file | Stable across vault renames |
| Automatically update internal links | ON | Safest default: renaming `david-chen.md` to `david-c-chen.md` rewrites all backlinks. Tradeoff: this is a bulk edit that can produce large commits; the daily-backup's 20-file delete tripwire tolerates it because renames are moves, not deletes. Confirm the vault's own `CLAUDE.md` has no conflicting guidance before accepting this. |
| Default location for new attachments | In folder specified below > `raw/assets/` | Keeps images out of `wiki/` |

Settings > Editor:

- Readable line length: ON
- Show line numbers: personal preference
- Spell check: ON

---

## 9. Install the Web Clipper browser extension

The Web Clipper is a browser extension that sends web pages into `raw/articles/` where the ingest pipeline picks them up.

1. Install the extension:
   - Chrome / Edge / Brave / Arc: https://chromewebstore.google.com/detail/obsidian-web-clipper (search for Obsidian Web Clipper by the Obsidian team)
   - Firefox: https://addons.mozilla.org/firefox (same name)
   - Safari: available via the Mac App Store (search "Obsidian Web Clipper")
2. Click the extension icon > Settings > add a Template named `{{VAULT_NAME}}` with:
   - Vault: `{{VAULT_NAME}}`
   - Note location: `raw/articles/`
   - Properties: `title`, `source`, `author`, `clipped: {{date}}`, `type: source`, `status: raw`
3. Test: on any article page, click the extension icon, pick the `{{VAULT_NAME}}` template, click Clip. A new file should appear at `~/{{LOCAL_ROOT}}/{{VAULT_NAME}}/raw/articles/<slug>.md` within a second.

If the extension complains Obsidian is not running, make sure Obsidian is open with your vault loaded — the extension talks to the running app via URL handler.

---

## 10. Round-trip verification

Prove that a Mac-side edit propagates to GitHub, so you know backup + restore works before you rely on it.

1. In Obsidian, create a new note at `raw/inbox/test-setup.md`. Type "hello from new mac".
2. Wait ~15 seconds for Obsidian Git's auto-pull interval, or open its sidebar pane (gear icon > Obsidian Git > Open source control view) and click Commit-and-sync. Obsidian Git commits locally.
3. In Terminal, push manually (since auto-push is OFF by design):

```bash
cd ~/{{LOCAL_ROOT}}/{{VAULT_NAME}}
git log --oneline -n 3
git push origin main
```

4. Open the repo on GitHub in a browser. The commit should be visible with `raw/inbox/test-setup.md`.
5. Delete the test file (`rm raw/inbox/test-setup.md`), commit, push — confirm it disappears on GitHub too.

If any step fails, go to the Troubleshooting table before proceeding.

---

## 11. Hand-off

At this point:

- Obsidian is installed and configured on this Mac.
- The vault is cloned, opened, and trusted.
- The four required community plugins are installed, enabled, configured.
- Web Clipper is wired up.
- A test commit round-tripped to GitHub.

Next step depends on what you're doing:

- **Setting up a fresh vault** — continue to [`02-vault-setup.md`](02-vault-setup.md) to scaffold folders, `CLAUDE.md`, frontmatter, and Dataview dashboards.
- **Restoring an existing vault** — you are basically done; continue to [`../templates/ops/docs/RESTORE.md.template`](../templates/ops/docs/RESTORE.md.template) step C (secrets) if you also need the librarian / ops backbone.
- **Whole-system bootstrap** — jump back to [`../SETUP.md`](../SETUP.md) step 4 and continue.

---

## 12. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Obsidian opens, file tree is empty | Wrong folder selected; opened parent of `{{VAULT_NAME}}` instead of `{{VAULT_NAME}}` itself | Vault switcher > Open folder as vault > pick the folder that contains `CLAUDE.md` directly |
| `CLAUDE.md` not visible in the file tree | You are looking at a nested folder in the left pane | Click the folder-up arrow / root icon; `CLAUDE.md` is at the vault root |
| Files show as 0 bytes or generic cloud icons | Vault is inside iCloud Drive | Move the folder out of iCloud per step 4 warning; re-clone if needed |
| Obsidian Git says "not a git repository" | Opened the wrong folder, or the repo was downloaded as a zip instead of cloned | Re-clone with `gh repo clone` per step 4 |
| Obsidian Git says "authentication failed" on pull/push | `gh` not set up as git credential helper | `gh auth setup-git` in Terminal, then retry |
| Obsidian Git says "could not find ssh key" | Remote is SSH but no key loaded | `ssh-add ~/.ssh/id_ed25519` or switch remote to HTTPS with `git remote set-url origin https://github.com/{{GITHUB_USER}}/{{VAULT_REPO}}.git` |
| Community plugins don't load, Restricted Mode locked on | You opened the vault and clicked Don't Trust at the trust prompt | Close and reopen the vault; on the trust prompt click Trust, then turn community plugins back on in Settings |
| Dataview queries show "Dataview: no data" | Plugin enabled but index not built yet | Wait ~30s for first index, or Command Palette > Dataview: Rebuild current file's index |
| Conflict: `file (conflicted copy 2).md` appears | iCloud or Obsidian Sync is running alongside Git | Disable Obsidian Sync; move vault out of iCloud; resolve the conflict file manually then delete it |
| `git push` refuses with "updates were rejected" | Remote has commits the local clone doesn't have (another machine pushed) | `git pull --rebase --autostash origin main` then re-push |
| Web Clipper says "Obsidian not running" | App is closed or the vault is not the frontmost | Open Obsidian with the right vault loaded, retry |
| Obsidian window opens but is all white / blank | Corrupt workspace file | Quit Obsidian, `rm .obsidian/workspace.json` in the vault, relaunch (this file is gitignored per `02-vault-setup.md`) |
| Commands palette can't find Templater / Dataview | Plugin installed but not enabled | Settings > Community plugins > toggle the plugin's switch to on |

---

## If you're an AI agent reading this

When the user says some variant of "help me set up Obsidian on my new Mac", "bootstrap Obsidian on this machine", or "I just reset my laptop, rebuild the vault environment":

1. Confirm they have a vault repo already on GitHub. If not, send them to `SETUP.md` step 3 first — do NOT invent a repo.
2. Ask for `{{LOCAL_ROOT}}`, `{{VAULT_NAME}}`, `{{GITHUB_USER}}`, `{{VAULT_REPO}}` explicitly. NEVER assume defaults like `~/Documents/` (iCloud risk) or use a hardcoded path from an example.
3. Walk them through the 12 numbered sections in order. Do not skip ahead even if they claim an earlier step is already done — verify with a check command (`which gh`, `ls ~/{{LOCAL_ROOT}}/{{VAULT_NAME}}/CLAUDE.md`, etc.) before moving on.
4. NEVER let them clone into `~/Documents/`, `~/Desktop/`, or anywhere under iCloud Drive / Dropbox / OneDrive / Google Drive. Enforce the iCloud check (`mdls -name kMDItemIsUbiquitous`) before trusting the clone location.
5. NEVER let them enable Obsidian Sync on top of Git. The two systems fight and produce unrecoverable conflicts. Decline the sync signup prompt in step 3.
6. NEVER tell them to run `git push --force`, `git reset --hard`, or `git commit --amend`. The paranoid-backup contract forbids those. If the round-trip test in step 10 fails, diagnose with `git status` and `git log` — never paper over with force operations.
7. NEVER commit `.obsidian/workspace.json` or `.obsidian/cache` — those are per-machine UI state and are gitignored for a reason; do not "fix" their absence from the repo.
8. After step 11 Hand-off, pause and ask the user which of the three paths they want to take (fresh vault / restore / whole-system). Do not auto-continue.
9. If anything goes wrong, send them to the Troubleshooting table first; fall back to reading logs (`tail -n 100 ~/Library/Logs/obsidian.log` where applicable) before proposing fixes.
10. Hard constraint: the end of this walkthrough is the user seeing `raw/inbox/test-setup.md` land on GitHub. Do not claim success before verifying that commit lands.

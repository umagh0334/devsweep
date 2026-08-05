# DevSweep 🧹

**English** | [한국어](README.ko.md) | [日本語](README.ja.md) | [简体中文](README.zh-Hans.md) | [繁體中文](README.zh-Hant.md)

Reclaim the gigabytes your dev toolchain forgot about. Every `gradle` build, `docker` pull, and `npm install` leaves caches behind — DevSweep scans **44 categories** across your Mac, flags what's safe to delete, and sweeps them back. No guesswork.

Beyond caches, it also hunts down **scattered build folders** (`node_modules`, `target`, …) and runs a **security check** for exposed secrets (`.env`, private keys, credentials) — all from a single **home dashboard**.

Ships as both a **CLI** (`devsweep`, a single bash script) and a **native macOS app** (`DevSweep.app`, SwiftUI). The GUI is a thin shell over the same verified engine.

---

## Design principles

| Principle | What it means |
|-----------|---------------|
| **Whitelist-only** | Only explicitly-known cache paths and commands are touched. Anything unrecognized is left alone — your source and projects are never in scope. |
| **Dry-run by default** | Running it just shows what *would* be freed. Deletion only happens with `--yes` (CLI) or a confirmation (GUI). |
| **Native cleanup first** | Uses each tool's own cleaner — `brew cleanup`, `npm cache clean`, `docker system prune` — and only falls back to `rm` when there's none. |

> The heavy lifting (measuring, deleting) is done by the OS and each tool; DevSweep only decides *where*, *safely*, and *clearly*. That's why a single bash script is enough for the engine.

> 🛡 **Privacy** — This app never reads the contents of sensitive files and never sends any data anywhere, under any circumstances. All scans and checks happen entirely on this Mac. (The network is used only to check for and download updates from GitHub — and even that can be turned off in settings.)

---

## Features

**CLI**
- Scan, dry-run preview, and selective/full cleanup
- `--json` / `detail` machine output for the GUI
- `scan-projects` / `scan-secrets` — project-folder & sensitive-file scanners
- `--older-than=Nd` age filter · protect list via config file

**macOS app**
- **Home dashboard** — time-of-day greeting with your name, lifetime reclaimed stats and a dev-persona profile chip, plus a disk gauge with the reclaimable slice highlighted, per-mode summary cards with top-3 previews, and a one-click scan-everything button
- **Cache mode** — master–detail UI, risk-tiered badges (safe / mid / caution), recommended selection, size/name sort, and a live cleaning-progress window
- **Project scanner** — finds scattered `node_modules` / `target` / `.next` / `Pods` … with size and last-used age, plus a 30d+ unused filter
- **Security check** — flags exposed secrets with git-aware risk levels (committed = critical, not gitignored = high): `.env` files, SSH/TLS private keys, kubeconfig, Docker / GitHub CLI / gcloud credentials, DB passwords (`.pgpass`, `.my.cnf`), Apple `AuthKey` keys and more. Also warns on stale credentials (180 d+) and loose `~/.ssh` permissions. Report-only: never reads contents, never deletes. One-click `.gitignore` / `chmod` fixes — single or batch
- **Git history scan** — finds secrets buried in commit history by delegating to [gitleaks](https://github.com/gitleaks/gitleaks) (optional; the app works fine without it). Only the finding's type, file, commit and date are taken in — the secret value itself is never held or shown
- **Real-time watch** (opt-in) — notices when a new `.env` or key file appears in a risky state (not gitignored, loose permissions) and alerts you *before* it gets committed. Watches paths via FSEvents — file contents are never read
- **Trash or permanent delete** — recoverable by default, with "empty just-trashed items" in one click
- **Menu bar & background mode** — status item with reclaimable size, hide-Dock option, launch at login
- **Signed auto-update** — Ed25519-verified releases, checked automatically once a day
- **Scheduled auto-clean** — daily / weekly / monthly via launchd; stateful tools like Docker are excluded from the automatic pass on purpose
- **Prompt-free scanning** — TCC-protected folders (Desktop/Documents/Downloads) are skipped by default and media libraries (Music/Pictures/Movies) always, so macOS permission dialogs never pop up; opt-in toggle + Full Disk Access onboarding in settings
- **Protect list · age filter · done notifications · custom confirmation modal**
- **15 languages** — auto-detected from your system locale, switchable in settings

---

## Categories (44)

**Safe** (26 — included in the default sweep):

`gradle` `npm` `yarn` `pnpm` `bun` `pip` `uv` `cargo` `go` `cocoapods` `swiftpm` `composer` `nuget` `deno` `brew` `colima` `xcode` `vscode` `cursor` `zed` `codemate` `electron` `ccache` `gem` `poetry` `carthage`

**Heavy** (18 — costly to re-download, cleared only when named or via `all`):

`docker` `maven` `pub` `playwright` `rustup-targets` `xcode-sim` `huggingface` `jetbrains` `androidstudio` `codex` `puppeteer` `cypress` `ollama` `lmstudio` `xcode-devsupport` `simruntime` `conda` `bazel`

---

## CLI usage

```bash
devsweep                  # scan (sizes only, deletes nothing)
devsweep list             # list supported categories
devsweep clean            # dry-run preview (safe categories)
devsweep clean --yes      # actually clean
devsweep clean gradle npm         # specific categories (preview)
devsweep clean --yes gradle npm   # specific categories (clean)
devsweep clean --yes all          # everything, incl. heavy
devsweep --older-than=30d clean   # only caches older than 30 days

# machine output (used by the GUI)
devsweep --json           # all categories as a JSON array
devsweep detail <cat>     # one category's detail as a JSON object
devsweep scan-projects ~  # scattered build/dependency folders as JSON
devsweep scan-secrets ~   # exposed sensitive files as JSON (report-only, never reads contents)
                          # add --include-protected to also scan Desktop/Documents/Downloads
devsweep scan-git-secrets ~   # secrets in git history via gitleaks — metadata only, never the secret value
devsweep check-secret <path>  # verdict for a single file (used by the real-time watch)
```

Optional — symlink it onto your `PATH` to run anywhere:

```bash
ln -s "$PWD/devsweep" ~/.local/bin/devsweep
```

---

## Build

The build script is not included in the repository — grab the ready-made app from [Releases](https://github.com/umagh0334/devsweep/releases).

Rolling your own is straightforward: compile `Sources/*.swift` with `swiftc` (Xcode Command Line Tools; full Xcode not needed), bundle `Resources/Info.plist`, the `devsweep` engine and icons into an `.app`, and ad-hoc code-sign it. Targets macOS 14+, **universal binary** (Apple Silicon + Intel).

---

## Project structure

```
devsweep/
├── devsweep               # CLI engine (bash) — fully standalone
├── Sources/               # SwiftUI app
│   ├── DevSweepApp.swift  #  @main entry
│   ├── Engine.swift       #  @Observable — drives the devsweep subprocess + JSON
│   ├── ContentView.swift  #  master-detail UI, custom confirm modal
│   ├── SettingsView.swift #  preferences · auto-clean · about
│   ├── AutoClean.swift    #  launchd scheduling + reclaim reconcile
│   ├── Notifier.swift     #  cleanup notifications
│   ├── Localization.swift #  15-language table
│   └── Models · Theme · Icons · AppInfo · UpdateChecker …
├── Resources/
│   ├── Info.plist · AppIcon.icns · icons/*.svg
└── web/                   # release landing page (15-language)
```

---

## Notes

- **Full Disk Access** — to read and clean `~/Library/Caches` (pip, brew, playwright, Xcode), grant `DevSweep.app` access under **System Settings → Privacy & Security → Full Disk Access**. Home-level paths (`~/.gradle`, `~/.cargo`, `~/.npm`) work without it.
- **Ad-hoc signed** — Gatekeeper may warn on first launch → **right-click → Open**.
- **Re-download cost** — some caches (e.g. `wrapper/dists`, registry caches) are re-fetched on the next build, so the first build afterward can be slower. No data is lost.

---

## First launch — Gatekeeper

DevSweep is **ad-hoc signed** (not notarized), so macOS Gatekeeper blocks it on first launch — and on recent macOS, "right-click → Open" is often not enough. Allow it one of two ways:

**Terminal (most reliable)** — strip the quarantine attribute:

```bash
xattr -dr com.apple.quarantine /path/to/DevSweep.app
```

Then double-click as usual. You only need this once per download — the in-app auto-update strips quarantine automatically.

**System Settings** — right after the block: **System Settings → Privacy & Security → "Open Anyway"**.

> Seeing *"DevSweep is damaged and can't be opened"*? Same Gatekeeper block — the `xattr` command above clears it.

For open-on-double-click distribution to everyone, the app would need an Apple Developer ID signature + notarization (paid).

---

## Roadmap

**Shipped**
- ✅ Protect list · age filter (`--older-than`) · scheduled auto-clean (launchd)
- ✅ 44 cache categories · project folder scanner · security check with single & batch fixes
- ✅ Git history secret scanning (gitleaks integration)
- ✅ Real-time watch for newly exposed sensitive files (FSEvents)
- ✅ Trash mode · menu bar & background mode · personalized home dashboard
- ✅ Ed25519-signed auto-update · 15 languages

**Planned**
- Cleanup history — "when / what / how much"
- Custom user-defined categories
- More accurate reclaimed-space measurement
- Developer ID signing & notarization (no more Gatekeeper hoops)

---

## License

MIT License. Icons from the [Iconify Solar](https://icon-sets.iconify.design/solar/) set.

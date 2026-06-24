# DevSweep 🧹

**English** | [한국어](README.ko.md) | [日本語](README.ja.md) | [简体中文](README.zh-Hans.md) | [繁體中文](README.zh-Hant.md)

Reclaim the gigabytes your dev toolchain forgot about. Every `gradle` build, `docker` pull, and `npm install` leaves caches behind — DevSweep scans **31 categories** across your Mac, flags what's safe to delete, and sweeps them back. No guesswork.

Ships as both a **CLI** (`devsweep`, a single bash script) and a **native macOS app** (`DevSweep.app`, SwiftUI). The GUI is a thin shell over the same verified engine.

---

## Design principles

| Principle | What it means |
|-----------|---------------|
| **Whitelist-only** | Only explicitly-known cache paths and commands are touched. Anything unrecognized is left alone — your source and projects are never in scope. |
| **Dry-run by default** | Running it just shows what *would* be freed. Deletion only happens with `--yes` (CLI) or a confirmation (GUI). |
| **Native cleanup first** | Uses each tool's own cleaner — `brew cleanup`, `npm cache clean`, `docker system prune` — and only falls back to `rm` when there's none. |

> The heavy lifting (measuring, deleting) is done by the OS and each tool; DevSweep only decides *where*, *safely*, and *clearly*. That's why a single bash script is enough for the engine.

---

## Features

**CLI**
- Scan, dry-run preview, and selective/full cleanup
- `--json` / `detail` machine output for the GUI
- `--older-than=Nd` age filter · protect list via config file

**macOS app**
- **Master–detail UI** — category list + per-category breakdown (paths, exact command, regeneration cost, safety, Full Disk Access hints)
- **Risk-tiered badges** — a traffic-light read (safe / mid / caution) before you commit
- **Scheduled auto-clean** — daily / weekly / monthly via launchd; stateful tools like Docker are excluded from the automatic pass on purpose
- **Done notifications** — a system notification when a sweep finishes, with how much it freed
- **Protect list** — pin caches that are never swept (manual, scheduled, or `all`)
- **Age filter** — only clear caches older than N days
- **Select-all toggle** and a **custom confirmation modal** before any deletion
- **15 languages** — auto-detected from your system locale, switchable in settings

---

## Categories (31)

**Safe** (21 — included in the default sweep):

`gradle` `npm` `yarn` `pnpm` `bun` `pip` `uv` `cargo` `go` `cocoapods` `swiftpm` `composer` `nuget` `deno` `brew` `colima` `xcode` `vscode` `cursor` `zed` `codemate`

**Heavy** (10 — costly to re-download, cleared only when named or via `all`):

`docker` `maven` `pub` `playwright` `rustup-targets` `xcode-sim` `huggingface` `jetbrains` `androidstudio` `codex`

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
```

Optional — symlink it onto your `PATH` to run anywhere:

```bash
ln -s "$PWD/devsweep" ~/.local/bin/devsweep
```

---

## Build

**Requires** Xcode Command Line Tools (`swiftc`). Full Xcode is **not** needed.

```bash
./build.sh
open DevSweep.app
```

`build.sh` compiles `Sources/*.swift` with `swiftc`, bundles `Info.plist` + the verified `devsweep` engine + icons, generates `.lproj` folders for 15 locales, and ad-hoc signs the app. Builds a **universal binary** (Apple Silicon + Intel) for macOS 14+.

---

## Project structure

```
devsweep/
├── devsweep               # CLI engine (bash) — fully standalone
├── build.sh               # swiftc → DevSweep.app bundle
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

## License

MIT License. Icons from the [Iconify Solar](https://icon-sets.iconify.design/solar/) set.

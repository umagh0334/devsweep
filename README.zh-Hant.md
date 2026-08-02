# DevSweep 🧹

[English](README.md) | [한국어](README.ko.md) | [日本語](README.ja.md) | [简体中文](README.zh-Hans.md) | **繁體中文**

找回被開發工具鏈遺忘的那幾個 GB。每次 `gradle` 建置、`docker` 拉取、`npm install`，都會留下快取——DevSweep 掃描 Mac 上的 **44 個類別**，標示哪些可以安全刪除，然後一掃而空。不用猜，不用擔心。

不只是快取：還有找出散落**建置/相依資料夾**（`node_modules`、`target` 等）的專案掃描器，以及檢查外洩敏感資訊（`.env`、私鑰、憑證）的**安全模式**——一切都從**主頁儀表板**開始。

同時提供 **CLI** 版（`devsweep`，單一 bash 腳本）和**原生 macOS 應用程式**（`DevSweep.app`，SwiftUI）。GUI 只是同一套經過驗證的引擎之上的薄殼。

---

## 設計原則

| 原則 | 意義 |
|------|------|
| **白名單限定** | 只處理明確知曉的快取路徑與指令。任何不認識的路徑一律略過——原始碼和專案目錄永遠不在掃描範圍內。 |
| **預設試跑模式** | 執行時僅顯示*將會*釋放的空間，不會實際刪除。刪除動作需要加上 `--yes`（CLI）或手動確認（GUI）。 |
| **優先使用工具原生清理器** | 優先呼叫各工具自己的清理指令——`brew cleanup`、`npm cache clean`、`docker system prune`——只在沒有對應指令時才退而使用 `rm`。 |

> 真正費工的部分（量測、刪除）由作業系統和各個工具負責；DevSweep 只決定*在哪裡*、*如何安全地*、*清楚地*進行。這就是為什麼單一 bash 腳本就足以作為引擎。

---

## 功能特色

**CLI**
- 掃描、試跑預覽、選擇性或全面清理
- `--json` / `detail` 機器可讀輸出，供 GUI 使用
- `scan-projects` / `scan-secrets` — 專案資料夾與敏感檔案掃描器
- `--older-than=Nd` 時間篩選 · 透過設定檔設定保護清單

**macOS 應用程式**
- **主頁儀表板** — 標示可回收空間的磁碟量表、各模式摘要卡片（前三預覽）、一鍵全部掃描
- **快取模式** — 主從式介面、風險燈號標章（安全 / 中等 / 謹慎）、推薦選取、依大小/名稱排序、即時清理進度視窗
- **專案掃描器** — 找出散落的 `node_modules` / `target` / `.next` / `Pods` … 並顯示大小與閒置時間，支援 30 天+ 未用篩選
- **安全檢查** — 以 git 感知的風險等級標示外洩的 `.env`、私鑰與憑證（已提交=嚴重，未加入 gitignore=高）。僅回報：不讀取內容、不刪除。一鍵 `.gitignore` / `chmod 600` 修正——單筆或批次
- **垃圾桶/永久刪除可選** — 預設移至可復原的垃圾桶，並可一鍵「僅清空本次移入項目」
- **選單列與背景模式** — 顯示可回收空間的狀態圖示、隱藏 Dock 圖示、登入時啟動
- **簽署自動更新** — 僅安裝通過 Ed25519 簽章驗證的版本，每天自動檢查一次
- **排程自動清理** — 透過 launchd 設定每日 / 每週 / 每月；有狀態的工具（如 Docker）在自動清理時刻意排除在外
- **無權限彈窗掃描** — 預設略過 macOS 保護資料夾（桌面/文件/下載）以避免權限彈窗；提供包含開關 + 設定中的完整磁碟取用權限引導
- **保護清單 · 時間篩選 · 完成通知 · 自訂確認視窗**
- **15 種語言** — 自動偵測系統語言，也可在設定中手動切換

---

## 類別（44 個）

**安全**（26 個——預設清理範圍）：

`gradle` `npm` `yarn` `pnpm` `bun` `pip` `uv` `cargo` `go` `cocoapods` `swiftpm` `composer` `nuget` `deno` `brew` `colima` `xcode` `vscode` `cursor` `zed` `codemate` `electron` `ccache` `gem` `poetry` `carthage`

**重量級**（18 個——重新下載成本高，僅在明確指定或使用 `all` 時才清除）：

`docker` `maven` `pub` `playwright` `rustup-targets` `xcode-sim` `huggingface` `jetbrains` `androidstudio` `codex` `puppeteer` `cypress` `ollama` `lmstudio` `xcode-devsupport` `simruntime` `conda` `bazel`

---

## CLI 用法

```bash
devsweep                  # 掃描（僅顯示大小，不刪除）
devsweep list             # 列出支援的類別
devsweep clean            # 試跑預覽（安全類別）
devsweep clean --yes      # 實際清理
devsweep clean gradle npm         # 指定類別（預覽）
devsweep clean --yes gradle npm   # 指定類別（清理）
devsweep clean --yes all          # 全部清理，包含重量級類別
devsweep --older-than=30d clean   # 只清除 30 天前的快取

# 機器可讀輸出（供 GUI 使用）
devsweep --json           # 所有類別輸出為 JSON 陣列
devsweep detail <cat>     # 單一類別詳細資訊輸出為 JSON 物件
devsweep scan-projects ~  # 散落的建置/相依資料夾輸出為 JSON
devsweep scan-secrets ~   # 外洩的敏感檔案輸出為 JSON（僅回報，不讀取內容）
                          # 加 --include-protected 可一併掃描桌面/文件/下載
```

選用——建立符號連結到 `PATH`，讓你在任何目錄都能執行：

```bash
ln -s "$PWD/devsweep" ~/.local/bin/devsweep
```

---

## 建置

**需要** Xcode Command Line Tools（`swiftc`）。不需要完整的 Xcode。

```bash
./build.sh
open DevSweep.app
```

`build.sh` 使用 `swiftc` 編譯 `Sources/*.swift`，將 `Info.plist`、已驗證的 `devsweep` 引擎和圖示打包，為 15 種語言地區產生 `.lproj` 資料夾，並以 ad-hoc 方式簽署應用程式。建置為 **universal binary**（Apple Silicon + Intel），支援 macOS 14+。

---

## 專案結構

```
devsweep/
├── devsweep               # CLI 引擎（bash）— 完全獨立
├── build.sh               # swiftc → DevSweep.app 套件
├── Sources/               # SwiftUI 應用程式
│   ├── DevSweepApp.swift  #  @main 進入點
│   ├── Engine.swift       #  @Observable — 驅動 devsweep 子程序 + JSON
│   ├── ContentView.swift  #  主從式介面、自訂確認視窗
│   ├── SettingsView.swift #  偏好設定 · 自動清理 · 關於
│   ├── AutoClean.swift    #  launchd 排程 + 釋放空間對帳
│   ├── Notifier.swift     #  清理通知
│   ├── Localization.swift #  15 語言對照表
│   └── Models · Theme · Icons · AppInfo · UpdateChecker …
├── Resources/
│   ├── Info.plist · AppIcon.icns · icons/*.svg
└── web/                   # 發布頁（15 種語言）
```

---

## 注意事項

- **Full Disk Access** — 若要讀取和清理 `~/Library/Caches`（pip、brew、playwright、Xcode），請至**系統設定 → 隱私權與安全性 → 完整磁碟存取**，將 `DevSweep.app` 加入允許清單。主目錄層級的路徑（`~/.gradle`、`~/.cargo`、`~/.npm`）無需此權限即可運作。
- **Ad-hoc 簽署** — Gatekeeper 在首次啟動時可能發出警告 → 請**按右鍵 → 開啟**。
- **重新下載成本** — 某些快取（例如 `wrapper/dists`、套件庫快取）會在下次建置時重新取得，因此清理後的第一次建置可能較慢。不會有任何資料遺失。

---

## 首次啟動 — Gatekeeper

DevSweep 為 **ad-hoc 簽署**（未公證），因此 macOS Gatekeeper 會攔截首次啟動 —— 在較新的 macOS 上，「右鍵 → 開啟」往往也不夠。可用以下兩種方式之一放行：

**終端機（最可靠）** —— 移除 quarantine 屬性：

```bash
xattr -dr com.apple.quarantine /路徑/DevSweep.app
```

接著照常雙擊即可啟動。每次下載只需執行一次 —— 應用程式內的自動更新會自動移除 quarantine。

**系統設定** —— 攔截後立即前往：**系統設定 → 隱私權與安全性 → 「仍要開啟」**。

> 看到 *「DevSweep 已損毀，無法打開」*？這同樣是 Gatekeeper 攔截 —— 用上面的 `xattr` 指令即可解除。

若要讓任何人下載後雙擊即可開啟，應用程式需要 Apple Developer ID 簽署 + 公證（付費）。

---

## 授權

MIT License。圖示來自 [Iconify Solar](https://icon-sets.iconify.design/solar/) 圖示集。

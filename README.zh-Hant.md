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

> 🛡 **隱私** — 本應用程式在任何情況下都不會讀取敏感資訊的內容，也不會向外部傳送任何資料。所有掃描與檢查都只在這台 Mac 上進行。（網路僅用於從 GitHub 檢查與下載更新，且此功能也可在設定中關閉。）

---

## 功能特色

**CLI**
- 掃描、試跑預覽、選擇性或全面清理
- `--json` / `detail` 機器可讀輸出，供 GUI 使用
- `scan-projects` / `scan-secrets` — 專案資料夾與敏感檔案掃描器
- `--older-than=Nd` 時間篩選 · 透過設定檔設定保護清單

**macOS 應用程式**
- **主頁儀表板** — 依時段問候（顯示名字）、累計回收統計、開發者類型個人檔案卡，加上標示可回收空間的磁碟量表、各模式摘要卡片（前三預覽）、一鍵全部掃描
- **快取模式** — 主從式介面、風險燈號標章（安全 / 中等 / 謹慎）、推薦選取、依大小/名稱排序、即時清理進度視窗
- **專案掃描器** — 找出散落的 `node_modules` / `target` / `.next` / `Pods` … 並顯示大小與閒置時間，支援 30 天+ 未用篩選
- **安全檢查** — 以 git 感知的風險等級標示外洩的敏感資訊（已提交=嚴重，未加入 gitignore=高）：`.env`、SSH/TLS 私鑰、kubeconfig、Docker/GitHub CLI/gcloud 憑證、資料庫密碼（`.pgpass`、`.my.cnf`）、Apple `AuthKey` 等。也會提醒過舊憑證（180 天+）與寬鬆的 `~/.ssh` 權限。僅回報：不讀取內容、不刪除。一鍵 `.gitignore` / `chmod` 修正——單筆或批次
- **git 歷史掃描** — 透過委派 [gitleaks](https://github.com/gitleaks/gitleaks) 尋找埋在提交歷史中的密鑰（選用，未安裝也不影響使用）。只取得類型、檔案、提交與日期，**密鑰內容本身既不保存也不顯示**
- **即時監視**（選用） — 當新的 `.env` 或密鑰檔案以危險狀態（未加入 gitignore、權限寬鬆）出現時，**在被提交之前**提醒你。透過 FSEvents 只監視路徑，絕不讀取檔案內容
- **垃圾桶/永久刪除可選** — 預設移至可復原的垃圾桶，並可一鍵「僅清空本次移入項目」
- **選單列與背景模式** — 顯示可回收空間的狀態圖示、隱藏 Dock 圖示、登入時啟動
- **簽署自動更新** — 僅安裝通過 Ed25519 簽章驗證的版本，每天自動檢查一次
- **排程自動清理** — 透過 launchd 設定每日 / 每週 / 每月；有狀態的工具（如 Docker）在自動清理時刻意排除在外
- **無權限彈窗掃描** — 預設略過 macOS 保護資料夾（桌面/文件/下載），媒體資料夾（音樂/圖片/影片）永遠排除——權限彈窗徹底消失；提供包含開關 + 設定中的完整磁碟取用權限引導
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
devsweep scan-git-secrets ~   # 用 gitleaks 掃描 git 歷史——僅中繼資料，不輸出密鑰內容
devsweep check-secret <path>  # 判定單一檔案（即時監視使用）
```

選用——建立符號連結到 `PATH`，讓你在任何目錄都能執行：

```bash
ln -s "$PWD/devsweep" ~/.local/bin/devsweep
```

---

## 建置

建置腳本不包含在儲存庫中——請從 [Releases](https://github.com/umagh0334/devsweep/releases) 取得成品應用程式。

自行建置也不難：用 `swiftc`（Xcode Command Line Tools，無需完整 Xcode）編譯 `Sources/*.swift`，將 `Resources/Info.plist`、`devsweep` 引擎與圖示打包為 `.app`，再以 ad-hoc 方式簽署即可。macOS 14+，**universal binary**（Apple Silicon + Intel）。

---

## 專案結構

```
devsweep/
├── devsweep               # CLI 引擎（bash）— 完全獨立
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

## 路線圖

**已完成**
- ✅ 保護清單 · 時間篩選（`--older-than`）· 排程自動清理（launchd）
- ✅ 44 個快取類別 · 專案資料夾掃描器 · 安全檢查（單筆/批次修正）
- ✅ git 歷史密鑰掃描（整合 gitleaks）
- ✅ 敏感檔案即時監視（FSEvents）
- ✅ 垃圾桶模式 · 選單列與背景模式 · 個人化主頁儀表板
- ✅ Ed25519 簽章自動更新 · 15 種語言

**規劃中**
- 清理歷史——「何時 / 清了什麼 / 釋放多少」
- 使用者自訂類別
- 更精確的回收空間量測
- Developer ID 簽章與公證（告別 Gatekeeper 麻煩）

---

## 授權

MIT License。圖示來自 [Iconify Solar](https://icon-sets.iconify.design/solar/) 圖示集。

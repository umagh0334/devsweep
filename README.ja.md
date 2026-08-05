# DevSweep 🧹

[English](README.md) | [한국어](README.ko.md) | **日本語** | [简体中文](README.zh-Hans.md) | [繁體中文](README.zh-Hant.md)

開発ツールチェーンが放置したギガバイトを取り戻そう。`gradle` のビルド、`docker` のプル、`npm install` ——これらはすべてキャッシュを残していく。DevSweep は Mac 上の **44カテゴリ**をスキャンし、安全に削除できるものを洗い出して一掃する。当て推量は不要。

キャッシュだけではない。散らばった**ビルド/依存フォルダ**（`node_modules`、`target` など）を見つけるプロジェクトスキャナと、露出した機密情報（`.env`、秘密鍵、クレデンシャル）を検査する**セキュリティモード**も搭載——すべて**ホームダッシュボード**から始まる。

**CLI**（`devsweep`、単一の bash スクリプト）と**ネイティブ macOS アプリ**（`DevSweep.app`、SwiftUI）の両方を同梱。GUI は同じ検証済みエンジンの薄いラッパーに過ぎない。

---

## 設計原則

| 原則 | 意味 |
|------|------|
| **ホワイトリスト制** | 明示的に認識されたキャッシュパスとコマンドのみを対象とする。未知のものは一切触らない——ソースコードやプロジェクトファイルがスコープに入ることはない。 |
| **デフォルトはドライラン** | 実行しても「何が解放されるか」を表示するだけ。削除は `--yes`（CLI）または確認操作（GUI）を経て初めて行われる。 |
| **ネイティブクリーナー優先** | 各ツール自身のクリーナー（`brew cleanup`、`npm cache clean`、`docker system prune` など）を使い、それがない場合にのみ `rm` にフォールバックする。 |

> 計測・削除という重処理は OS と各ツールが担い、DevSweep は*どこを*、*安全に*、*明確に*扱うかを決めるだけ。だから単一の bash スクリプトでエンジンが成立する。

> 🛡 **プライバシー** — このアプリはいかなる場合も機密情報の内容を読み取らず、データを外部に送信しません。すべてのスキャンと検査はこの Mac の中だけで行われます。（ネットワークは GitHub からのアップデート確認・ダウンロードにのみ使用され、それも設定でオフにできます。）

---

## 機能

**CLI**
- スキャン、ドライラン プレビュー、選択/全体クリーンアップ
- GUI 向け `--json` / `detail` マシン出力
- `scan-projects` / `scan-secrets` ——プロジェクトフォルダ・機密ファイルスキャナ
- `--older-than=Nd` 日数フィルター・設定ファイルによる保護リスト

**macOS アプリ**
- **ホームダッシュボード** ——時間帯別の挨拶（名前表示）・累計回収量・開発タイプのプロフィールチップ、回収可能領域を示すディスクゲージ、モード別サマリーカード（トップ3プレビュー）、ワンクリック一括スキャン
- **キャッシュモード** ——マスター–デテール UI、リスクティア バッジ（安全 / 中程度 / 注意）、おすすめ選択、サイズ/名前ソート、リアルタイム進行ウインドウ
- **プロジェクトスキャナ** ——散らばった `node_modules` / `target` / `.next` / `Pods` … をサイズ・未使用期間つきで発見、30日+ 未使用フィルター
- **セキュリティ検査** ——露出した機密情報を git 連動のリスクレベルで判定（コミット済み=重大、gitignore 未設定=高）: `.env`、SSH/TLS 秘密鍵、kubeconfig、Docker・GitHub CLI・gcloud 認証、DB パスワード（`.pgpass`・`.my.cnf`）、Apple `AuthKey` など。古いクレデンシャル（180日+）と緩い `~/.ssh` 権限も警告。レポート専用: 内容は読まず、削除もしない。`.gitignore` 追加 / `chmod` のワンクリック修正——個別または一括
- **git履歴検査** ——コミット履歴に埋もれたシークレットを [gitleaks](https://github.com/gitleaks/gitleaks) に委譲して検出（任意。無くてもアプリは正常動作）。取り込むのは種類・ファイル・コミット・日付のみで、**シークレットの値そのものは保持も表示もしない**
- **リアルタイム監視** ——新しい `.env` や鍵ファイルが危険な状態（gitignore 未設定・権限が緩い）で作られると、**コミットされる前に**通知。既定でオン、設定でオフにできる。FSEvents でパスのみを監視し、ファイルの内容は読まない
- **ゴミ箱/完全削除の選択** ——デフォルトは復元可能なゴミ箱。「今回移動した項目だけ完全削除」もワンクリック
- **メニューバー & バックグラウンドモード** ——回収容量つきステータスアイコン、Dock 非表示、ログイン時に起動
- **署名付き自動アップデート** ——Ed25519 署名検証済みリリースのみ適用、1日1回自動チェック
- **スケジュール自動クリーン** ——launchd による日次 / 週次 / 月次実行。Docker のようなステートフルなツールは自動実行から意図的に除外
- **許可ダイアログなしのスキャン** ——macOS 保護フォルダ（デスクトップ・書類・ダウンロード）は既定で除外、メディアフォルダ（ミュージック・写真・ムービー）は常に除外——確認ダイアログが一切出ない。含めるトグル + 設定にフルディスクアクセス案内
- **保護リスト · 日数フィルター · 完了通知 · カスタム確認モーダル**
- **15言語対応** ——システムロケールから自動検出、設定で切り替え可能

---

## カテゴリ（44）

**Safe**（26 ——デフォルトのスイープ対象）:

`gradle` `npm` `yarn` `pnpm` `bun` `pip` `uv` `cargo` `go` `cocoapods` `swiftpm` `composer` `nuget` `deno` `brew` `colima` `xcode` `vscode` `cursor` `zed` `codemate` `electron` `ccache` `gem` `poetry` `carthage`

**Heavy**（18 ——再ダウンロードコストが高く、明示指定または `all` でのみ削除）:

`docker` `maven` `pub` `playwright` `rustup-targets` `xcode-sim` `huggingface` `jetbrains` `androidstudio` `codex` `puppeteer` `cypress` `ollama` `lmstudio` `xcode-devsupport` `simruntime` `conda` `bazel`

---

## CLI の使い方

```bash
devsweep                  # スキャン（サイズ表示のみ、削除なし）
devsweep list             # 対応カテゴリ一覧
devsweep clean            # ドライラン プレビュー（Safe カテゴリ）
devsweep clean --yes      # 実際にクリーン
devsweep clean gradle npm         # 特定カテゴリ（プレビュー）
devsweep clean --yes gradle npm   # 特定カテゴリ（クリーン）
devsweep clean --yes all          # Heavy 含む全カテゴリ
devsweep --older-than=30d clean   # 30日より古いキャッシュのみ

# マシン出力（GUI が使用）
devsweep --json           # 全カテゴリを JSON 配列で出力
devsweep detail <cat>     # 1カテゴリの詳細を JSON オブジェクトで出力
devsweep scan-projects ~  # 散らばったビルド/依存フォルダを JSON で出力
devsweep scan-secrets ~   # 露出した機密ファイルを JSON で出力（レポート専用・内容は読まない）
                          # --include-protected でデスクトップ・書類・ダウンロードも対象に
devsweep scan-git-secrets ~   # gitleaks で git 履歴を検査——メタデータのみ、シークレット値は出力しない
devsweep check-secret <path>  # ファイル1件の判定（リアルタイム監視が使用）
```

任意で `PATH` にシンボリックリンクを作成すると、どこからでも実行できる:

```bash
ln -s "$PWD/devsweep" ~/.local/bin/devsweep
```

---

## ビルド

ビルドスクリプトはリポジトリに含まれていない——完成品のアプリは [Releases](https://github.com/umagh0334/devsweep/releases) から入手を。

自分でビルドするのも難しくない: `swiftc`（Xcode Command Line Tools、フル Xcode 不要）で `Sources/*.swift` をコンパイルし、`Resources/Info.plist`・`devsweep` エンジン・アイコンを `.app` バンドルにまとめ、ad-hoc 署名するだけ。macOS 14+、**universal binary**（Apple Silicon + Intel）。

---

## プロジェクト構成

```
devsweep/
├── devsweep               # CLI エンジン（bash）——完全スタンドアロン
├── Sources/               # SwiftUI アプリ
│   ├── DevSweepApp.swift  #  @main エントリ
│   ├── Engine.swift       #  @Observable — devsweep サブプロセスと JSON を管理
│   ├── ContentView.swift  #  マスター–デテール UI、カスタム確認モーダル
│   ├── SettingsView.swift #  設定 · 自動クリーン · アバウト
│   ├── AutoClean.swift    #  launchd スケジューリング + 解放量の照合
│   ├── Notifier.swift     #  クリーンアップ通知
│   ├── Localization.swift #  15言語テーブル
│   └── Models · Theme · Icons · AppInfo · UpdateChecker …
├── Resources/
│   ├── Info.plist · AppIcon.icns · icons/*.svg
└── web/                   # リリース ランディングページ（15言語対応）
```

---

## 注意事項

- **Full Disk Access** ——`~/Library/Caches`（pip、brew、playwright、Xcode）を読み書きするには、**システム設定 → プライバシーとセキュリティ → フルディスクアクセス**で `DevSweep.app` を許可する。`~/.gradle`、`~/.cargo`、`~/.npm` などホームレベルのパスは許可なしで動作する。
- **Ad-hoc 署名** ——初回起動時に Gatekeeper の警告が表示される場合は**右クリック → 開く**を選択。
- **再ダウンロードコスト** ——一部のキャッシュ（`wrapper/dists`、レジストリキャッシュなど）は次回ビルド時に再取得されるため、クリーン後の最初のビルドが遅くなることがある。データは失われない。

---

## 初回起動 — Gatekeeper

DevSweep は **ad-hoc 署名**(notarization なし)のため、macOS Gatekeeper が初回起動をブロックします — 最近の macOS では「右クリック → 開く」でも回避できないことが多いです。次のいずれかで許可してください:

**ターミナル (最も確実)** — quarantine 属性を削除:

```bash
xattr -dr com.apple.quarantine /パス/DevSweep.app
```

あとは通常どおりダブルクリックで起動します。ダウンロードごとに1回だけで済み、アプリ内の自動アップデートは quarantine を自動的に削除します。

**システム設定** — ブロック直後に: **システム設定 → プライバシーとセキュリティ → 「このまま開く」**。

> *「DevSweep は壊れているため開けません」* と表示されても同じ Gatekeeper のブロックです — 上記の `xattr` コマンドで解決します。

誰でもダブルクリックで開ける配布には、Apple Developer ID 署名 + notarization(有料)が必要です。

---

## ロードマップ

**実装済み**
- ✅ 保護リスト · 日数フィルター（`--older-than`）· スケジュール自動クリーン（launchd）
- ✅ キャッシュ44カテゴリ · プロジェクトフォルダスキャナ · セキュリティ検査（個別/一括修正）
- ✅ git履歴のシークレット検査（gitleaks 連携）
- ✅ 機密ファイルのリアルタイム監視（FSEvents）
- ✅ ゴミ箱モード · メニューバー & バックグラウンドモード · パーソナライズされたホームダッシュボード
- ✅ Ed25519 署名付き自動アップデート · 15言語

**予定**
- クリーンアップ履歴 ——「いつ / 何を / どれだけ」
- ユーザー定義カテゴリ
- 回収容量測定の精密化
- Developer ID 署名・公証（Gatekeeper の手間を解消）

---

## ライセンス

MIT License. アイコンは [Iconify Solar](https://icon-sets.iconify.design/solar/) セットより。

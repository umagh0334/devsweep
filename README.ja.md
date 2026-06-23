# DevSweep 🧹

[English](README.md) | [한국어](README.ko.md) | **日本語** | [简体中文](README.zh-Hans.md) | [繁體中文](README.zh-Hant.md)

開発ツールチェーンが放置したギガバイトを取り戻そう。`gradle` のビルド、`docker` のプル、`npm install` ——これらはすべてキャッシュを残していく。DevSweep は Mac 上の **31カテゴリ**をスキャンし、安全に削除できるものを洗い出して一掃する。当て推量は不要。

**CLI**（`devsweep`、単一の bash スクリプト）と**ネイティブ macOS アプリ**（`DevSweep.app`、SwiftUI）の両方を同梱。GUI は同じ検証済みエンジンの薄いラッパーに過ぎない。

---

## 設計原則

| 原則 | 意味 |
|------|------|
| **ホワイトリスト制** | 明示的に認識されたキャッシュパスとコマンドのみを対象とする。未知のものは一切触らない——ソースコードやプロジェクトファイルがスコープに入ることはない。 |
| **デフォルトはドライラン** | 実行しても「何が解放されるか」を表示するだけ。削除は `--yes`（CLI）または確認操作（GUI）を経て初めて行われる。 |
| **ネイティブクリーナー優先** | 各ツール自身のクリーナー（`brew cleanup`、`npm cache clean`、`docker system prune` など）を使い、それがない場合にのみ `rm` にフォールバックする。 |

> 計測・削除という重処理は OS と各ツールが担い、DevSweep は*どこを*、*安全に*、*明確に*扱うかを決めるだけ。だから単一の bash スクリプトでエンジンが成立する。

---

## 機能

**CLI**
- スキャン、ドライラン プレビュー、選択/全体クリーンアップ
- GUI 向け `--json` / `detail` マシン出力
- `--older-than=Nd` 日数フィルター・設定ファイルによる保護リスト

**macOS アプリ**
- **マスター–デテール UI** ——カテゴリ一覧 + カテゴリ別の詳細（パス、実行コマンド、再生成コスト、安全性、Full Disk Access のヒント）
- **リスクティア バッジ** ——削除前に信号機方式で確認（安全 / 中程度 / 注意）
- **スケジュール自動クリーン** ——launchd による日次 / 週次 / 月次実行。Docker のようなステートフルなツールは自動実行から意図的に除外
- **完了通知** ——スイープ終了時に解放容量を添えてシステム通知
- **保護リスト** ——手動・スケジュール・`all` のいずれでも掃除されないキャッシュを固定
- **日数フィルター** ——N 日より古いキャッシュのみ削除
- **全選択トグル**と削除前の**カスタム確認モーダル**
- **15言語対応** ——システムロケールから自動検出、設定で切り替え可能

---

## カテゴリ（31）

**Safe**（24 ——デフォルトのスイープ対象）:

`gradle` `npm` `yarn` `pnpm` `bun` `pip` `uv` `cargo` `go` `maven` `cocoapods` `swiftpm` `composer` `nuget` `deno` `pub` `brew` `colima` `xcode` `vscode` `cursor` `zed` `codemate`

**Heavy**（7 ——再ダウンロードコストが高く、明示指定または `all` でのみ削除）:

`docker` `playwright` `rustup-targets` `xcode-sim` `huggingface` `jetbrains` `androidstudio` `codex`

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
```

任意で `PATH` にシンボリックリンクを作成すると、どこからでも実行できる:

```bash
ln -s "$PWD/devsweep" ~/.local/bin/devsweep
```

---

## ビルド

**必要条件**: Xcode Command Line Tools（`swiftc`）。フル Xcode は**不要**。

```bash
./build.sh
open DevSweep.app
```

`build.sh` は `Sources/*.swift` を `swiftc` でコンパイルし、`Info.plist` + 検証済み `devsweep` エンジン + アイコンをバンドルし、15ロケール分の `.lproj` フォルダを生成してアプリに ad-hoc 署名を行う。**universal binary**(Apple Silicon + Intel)でビルドされ、macOS 14 以降に対応。

---

## プロジェクト構成

```
devsweep/
├── devsweep               # CLI エンジン（bash）——完全スタンドアロン
├── build.sh               # swiftc → DevSweep.app バンドル
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

## ライセンス

MIT License. アイコンは [Iconify Solar](https://icon-sets.iconify.design/solar/) セットより。

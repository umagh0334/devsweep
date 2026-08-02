# DevSweep 🧹

[English](README.md) | [한국어](README.ko.md) | [日本語](README.ja.md) | **简体中文** | [繁體中文](README.zh-Hant.md)

找回被开发工具链悄悄占用的磁盘空间。每一次 `gradle` 构建、`docker` 拉取和 `npm install` 都会留下缓存——DevSweep 扫描 Mac 上 **44 个类别**，标记可以安全删除的内容，并将其一扫而空。无需猜测。

不止是缓存：还有找出散落**构建/依赖文件夹**（`node_modules`、`target` 等）的项目扫描器，以及检查暴露敏感信息（`.env`、私钥、凭证）的**安全模式**——一切都从**主页仪表盘**开始。

提供两种形态：**CLI**（`devsweep`，单一 bash 脚本）和**原生 macOS 应用**（`DevSweep.app`，SwiftUI）。图形界面是对同一套经过验证的引擎的薄层封装。

---

## 设计原则

| 原则 | 含义 |
|------|------|
| **白名单机制** | 只处理明确已知的缓存路径和命令。任何未识别的内容一概不动——源代码和项目文件永远不在处理范围内。 |
| **默认预演模式** | 直接运行只会显示*将会*释放的空间，不会删除任何内容。删除操作需要显式使用 `--yes`（CLI）或在 GUI 中确认。 |
| **优先使用原生清理工具** | 调用各工具自带的清理命令——`brew cleanup`、`npm cache clean`、`docker system prune`——只有在没有原生命令时才回退到 `rm`。 |

> 繁重的工作（测量、删除）由操作系统和各工具自身完成；DevSweep 只负责决定*在哪里*、*安全地*、*清晰地*执行。这也是为什么单一 bash 脚本足以作为引擎的原因。

---

## 功能特性

**CLI**
- 扫描、预演预览，以及选择性/全量清理
- `--json` / `detail` 机器可读输出（供 GUI 使用）
- `scan-projects` / `scan-secrets` — 项目文件夹与敏感文件扫描器
- `--older-than=Nd` 时间过滤 · 通过配置文件设置保护列表

**macOS 应用**
- **主页仪表盘** — 按时段问候（显示名字）、累计回收统计、开发者画像资料卡，加上高亮可回收空间的磁盘量表、各模式摘要卡片（前三预览）、一键全部扫描
- **缓存模式** — 主从视图界面、风险红绿灯徽章（安全 / 中等 / 谨慎）、推荐选择、按大小/名称排序、实时清理进度窗口
- **项目扫描器** — 找出散落的 `node_modules` / `target` / `.next` / `Pods` … 并显示大小与闲置时长，支持 30 天+ 未用过滤
- **安全检查** — 以 git 感知的风险等级标记暴露的敏感信息（已提交=严重，未加入 gitignore=高）：`.env`、SSH/TLS 私钥、kubeconfig、Docker/GitHub CLI/gcloud 凭证、数据库密码（`.pgpass`、`.my.cnf`）、Apple `AuthKey` 等。还会提醒过旧凭证（180 天+）和宽松的 `~/.ssh` 权限。仅报告：不读取内容、不删除。一键 `.gitignore` / `chmod` 修复——单个或批量
- **废纸篓/彻底删除可选** — 默认移到可恢复的废纸篓，并可一键"仅清空本次移入项"
- **菜单栏与后台模式** — 显示可回收空间的状态图标、隐藏 Dock 图标、登录时启动
- **签名自动更新** — 仅安装通过 Ed25519 签名验证的版本，每天自动检查一次
- **定时自动清理** — 通过 launchd 设置每日 / 每周 / 每月执行；有状态的工具（如 Docker）有意从自动清理中排除
- **无权限弹窗扫描** — 默认跳过 macOS 保护文件夹（桌面/文稿/下载），媒体文件夹（音乐/图片/影片）始终排除——权限弹窗彻底消失；提供包含开关 + 设置中的完全磁盘访问引导
- **保护列表 · 时间过滤 · 完成通知 · 自定义确认对话框**
- **15 种语言** — 自动从系统语言环境检测，可在设置中手动切换

---

## 类别（44 个）

**安全类**（26 个——包含在默认清理范围内）：

`gradle` `npm` `yarn` `pnpm` `bun` `pip` `uv` `cargo` `go` `cocoapods` `swiftpm` `composer` `nuget` `deno` `brew` `colima` `xcode` `vscode` `cursor` `zed` `codemate` `electron` `ccache` `gem` `poetry` `carthage`

**重量类**（18 个——重新下载成本较高，只有显式指定或使用 `all` 时才会清理）：

`docker` `maven` `pub` `playwright` `rustup-targets` `xcode-sim` `huggingface` `jetbrains` `androidstudio` `codex` `puppeteer` `cypress` `ollama` `lmstudio` `xcode-devsupport` `simruntime` `conda` `bazel`

---

## CLI 用法

```bash
devsweep                  # 扫描（只显示大小，不删除任何内容）
devsweep list             # 列出支持的类别
devsweep clean            # 预演预览（安全类别）
devsweep clean --yes      # 实际执行清理
devsweep clean gradle npm         # 指定类别（预览）
devsweep clean --yes gradle npm   # 指定类别（清理）
devsweep clean --yes all          # 清理全部，包括重量类
devsweep --older-than=30d clean   # 只清理超过 30 天的缓存

# 机器可读输出（供 GUI 使用）
devsweep --json           # 所有类别输出为 JSON 数组
devsweep detail <cat>     # 单个类别的详情输出为 JSON 对象
devsweep scan-projects ~  # 散落的构建/依赖文件夹输出为 JSON
devsweep scan-secrets ~   # 暴露的敏感文件输出为 JSON（仅报告，不读取内容）
                          # 加 --include-protected 可同时扫描桌面/文稿/下载
```

可选——将其软链接到 `PATH` 以便在任意位置运行：

```bash
ln -s "$PWD/devsweep" ~/.local/bin/devsweep
```

---

## 构建

**需要** Xcode 命令行工具（`swiftc`），**不需要**完整的 Xcode。

```bash
./build.sh
open DevSweep.app
```

`build.sh` 使用 `swiftc` 编译 `Sources/*.swift`，将 `Info.plist`、经过验证的 `devsweep` 引擎和图标打包在一起，为 15 个语言区域生成 `.lproj` 文件夹，并对应用进行 ad-hoc 签名。构建为 **universal binary**（Apple Silicon + Intel），支持 macOS 14+。

---

## 项目结构

```
devsweep/
├── devsweep               # CLI 引擎（bash）——完全独立运行
├── build.sh               # swiftc → DevSweep.app 打包
├── Sources/               # SwiftUI 应用
│   ├── DevSweepApp.swift  #  @main 入口
│   ├── Engine.swift       #  @Observable — 驱动 devsweep 子进程 + JSON
│   ├── ContentView.swift  #  主从视图界面，自定义确认对话框
│   ├── SettingsView.swift #  偏好设置 · 自动清理 · 关于
│   ├── AutoClean.swift    #  launchd 调度 + 回收空间核对
│   ├── Notifier.swift     #  清理完成通知
│   ├── Localization.swift #  15 语言对照表
│   └── Models · Theme · Icons · AppInfo · UpdateChecker …
├── Resources/
│   ├── Info.plist · AppIcon.icns · icons/*.svg
└── web/                   # 发布落地页（15 种语言）
```

---

## 注意事项

- **Full Disk Access** — 若要读取和清理 `~/Library/Caches`（pip、brew、playwright、Xcode），请在**系统设置 → 隐私与安全性 → 完全磁盘访问权限**中为 `DevSweep.app` 授权。家目录级路径（`~/.gradle`、`~/.cargo`、`~/.npm`）无需此权限即可访问。
- **Ad-hoc 签名** — 首次启动时 Gatekeeper 可能发出警告，请**右键单击 → 打开**。
- **重新下载成本** — 部分缓存（例如 `wrapper/dists`、注册表缓存）会在下次构建时重新获取，因此清理后的第一次构建可能会较慢。不会有任何数据丢失。

---

## 首次启动 — Gatekeeper

DevSweep 为 **ad-hoc 签名**（未公证），因此 macOS Gatekeeper 会拦截首次启动 —— 在较新的 macOS 上，“右键 → 打开”往往也不够。可用以下两种方式之一放行：

**终端（最可靠）** —— 移除 quarantine 属性：

```bash
xattr -dr com.apple.quarantine /路径/DevSweep.app
```

然后照常双击即可启动。每次下载只需执行一次 —— 应用内自动更新会自动移除 quarantine。

**系统设置** —— 拦截后立即前往：**系统设置 → 隐私与安全性 → “仍要打开”**。

> 看到 *“DevSweep 已损坏，无法打开”*？这同样是 Gatekeeper 拦截 —— 用上面的 `xattr` 命令即可解除。

若要让任何人下载后双击即可打开，应用需要 Apple Developer ID 签名 + 公证（付费）。

---

## 许可证

MIT License。图标来自 [Iconify Solar](https://icon-sets.iconify.design/solar/) 图标集。

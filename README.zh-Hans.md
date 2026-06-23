# DevSweep 🧹

[English](README.md) | [한국어](README.ko.md) | [日本語](README.ja.md) | **简体中文** | [繁體中文](README.zh-Hant.md)

找回被开发工具链悄悄占用的磁盘空间。每一次 `gradle` 构建、`docker` 拉取和 `npm install` 都会留下缓存——DevSweep 扫描 Mac 上 **31 个类别**，标记可以安全删除的内容，并将其一扫而空。无需猜测。

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
- `--older-than=Nd` 时间过滤 · 通过配置文件设置保护列表

**macOS 应用**
- **主从视图界面** — 类别列表 + 每个类别的详细分解（路径、具体命令、重新生成成本、安全性、Full Disk Access 提示）
- **风险分级徽章** — 执行前以红绿灯形式显示风险等级（安全 / 中等 / 谨慎）
- **定时自动清理** — 通过 launchd 设置每日 / 每周 / 每月执行；有状态的工具（如 Docker）有意从自动清理中排除
- **完成通知** — 清理完成后发送系统通知，显示释放了多少空间
- **保护列表** — 固定永不清理的缓存（手动、定时或 `all` 模式均适用）
- **时间过滤** — 只清理超过 N 天的缓存
- **全选切换**以及删除前的**自定义确认对话框**
- **15 种语言** — 自动从系统语言环境检测，可在设置中手动切换

---

## 类别（31 个）

**安全类**（24 个——包含在默认清理范围内）：

`gradle` `npm` `yarn` `pnpm` `bun` `pip` `uv` `cargo` `go` `maven` `cocoapods` `swiftpm` `composer` `nuget` `deno` `pub` `brew` `colima` `xcode` `vscode` `cursor` `zed` `codemate`

**重量类**（7 个——重新下载成本较高，只有显式指定或使用 `all` 时才会清理）：

`docker` `playwright` `rustup-targets` `xcode-sim` `huggingface` `jetbrains` `androidstudio` `codex`

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

`build.sh` 使用 `swiftc` 编译 `Sources/*.swift`，将 `Info.plist`、经过验证的 `devsweep` 引擎和图标打包在一起，为 15 个语言区域生成 `.lproj` 文件夹，并对应用进行 ad-hoc 签名。目标平台为 macOS 14+ / Apple Silicon。

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

## 许可证

MIT License。图标来自 [Iconify Solar](https://icon-sets.iconify.design/solar/) 图标集。

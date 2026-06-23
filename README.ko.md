# DevSweep 🧹

[English](README.md) | **한국어** | [日本語](README.ja.md) | [简体中文](README.zh-Hans.md) | [繁體中文](README.zh-Hant.md)

개발 도구들이 슬그머니 쌓아놓은 기가바이트를 되찾아 오세요. `gradle` 빌드, `docker` pull, `npm install`… 할 때마다 캐시가 쌓입니다. DevSweep은 Mac 전체에서 **31개 카테고리**를 스캔해 삭제해도 안전한 항목을 찾아내고, 깔끔하게 비워줍니다. 이제 눈치게임은 그만.

**CLI**(`devsweep`, 단일 bash 스크립트)와 **네이티브 macOS 앱**(`DevSweep.app`, SwiftUI) 두 가지 형태로 제공됩니다. GUI는 동일한 검증된 엔진 위에 얹은 얇은 인터페이스입니다.

---

## 설계 원칙

| 원칙 | 의미 |
|------|------|
| **화이트리스트 전용** | 명시적으로 등록된 캐시 경로와 명령어만 건드립니다. 알 수 없는 경로는 그대로 둡니다 — 소스 코드와 프로젝트 파일은 절대 범위에 포함되지 않습니다. |
| **기본값은 드라이런** | 실행하면 *무엇이 해제될지*만 보여줍니다. 실제 삭제는 `--yes`(CLI) 또는 확인 버튼(GUI)이 있어야만 실행됩니다. |
| **도구 자체 클리너 우선** | `brew cleanup`, `npm cache clean`, `docker system prune` 등 각 도구의 공식 클리너를 먼저 사용하고, 없을 때만 `rm`으로 대체합니다. |

> 실제 무거운 작업(크기 측정, 삭제)은 OS와 각 도구가 처리합니다. DevSweep은 *어디를*, *안전하게*, *명확하게* 결정하는 역할만 합니다. 엔진으로 단일 bash 스크립트만으로 충분한 이유가 여기 있습니다.

---

## 기능

**CLI**
- 스캔, 드라이런 미리보기, 선택/전체 정리
- `--json` / `detail` — GUI용 기계 가독 출력
- `--older-than=Nd` 나이 필터 · 설정 파일을 통한 보호 목록

**macOS 앱**
- **마스터-디테일 UI** — 카테고리 목록 + 카테고리별 상세 내역(경로, 실행 명령어, 재생성 비용, 안전도, Full Disk Access 안내)
- **위험도 배지** — 삭제 전에 한눈에 파악하는 신호등 표시(안전 / 보통 / 주의)
- **예약 자동 정리** — launchd를 이용한 일간 / 주간 / 월간 자동 실행. Docker처럼 상태가 있는 도구는 자동 실행 대상에서 의도적으로 제외됩니다.
- **완료 알림** — 정리가 끝나면 확보된 용량과 함께 시스템 알림 전송
- **보호 목록** — 수동, 예약, `all` 어느 방식으로도 절대 정리되지 않도록 캐시를 고정
- **나이 필터** — N일보다 오래된 캐시만 정리
- **전체 선택 토글** 및 삭제 전 **커스텀 확인 모달**
- **15개 언어** — 시스템 로케일에서 자동 감지, 설정에서 직접 변경 가능

---

## 카테고리 (31개)

**Safe** (24개 — 기본 정리에 포함):

`gradle` `npm` `yarn` `pnpm` `bun` `pip` `uv` `cargo` `go` `maven` `cocoapods` `swiftpm` `composer` `nuget` `deno` `pub` `brew` `colima` `xcode` `vscode` `cursor` `zed` `codemate`

**Heavy** (7개 — 재다운로드 비용이 크므로 명시적으로 지정하거나 `all` 사용 시만 정리):

`docker` `playwright` `rustup-targets` `xcode-sim` `huggingface` `jetbrains` `androidstudio` `codex`

---

## CLI 사용법

```bash
devsweep                  # 스캔 (크기만 표시, 아무것도 삭제하지 않음)
devsweep list             # 지원 카테고리 목록 표시
devsweep clean            # 드라이런 미리보기 (safe 카테고리)
devsweep clean --yes      # 실제로 정리
devsweep clean gradle npm         # 특정 카테고리 (미리보기)
devsweep clean --yes gradle npm   # 특정 카테고리 (정리)
devsweep clean --yes all          # heavy 포함 전체 정리
devsweep --older-than=30d clean   # 30일보다 오래된 캐시만 정리

# 기계 가독 출력 (GUI에서 사용)
devsweep --json           # 전체 카테고리를 JSON 배열로 출력
devsweep detail <cat>     # 특정 카테고리의 상세 정보를 JSON 객체로 출력
```

어디서든 실행하려면 `PATH`에 심볼릭 링크를 추가하세요:

```bash
ln -s "$PWD/devsweep" ~/.local/bin/devsweep
```

---

## 빌드

**필수 사항** Xcode Command Line Tools(`swiftc`). 전체 Xcode는 **불필요**합니다.

```bash
./build.sh
open DevSweep.app
```

`build.sh`는 `swiftc`로 `Sources/*.swift`를 컴파일하고, `Info.plist`와 검증된 `devsweep` 엔진, 아이콘을 번들로 묶습니다. 15개 로케일용 `.lproj` 폴더를 생성하고 앱을 ad-hoc 서명합니다. 빌드 타겟은 Apple Silicon macOS 14 이상입니다.

---

## 프로젝트 구조

```
devsweep/
├── devsweep               # CLI 엔진 (bash) — 완전 독립 실행
├── build.sh               # swiftc → DevSweep.app 번들 생성
├── Sources/               # SwiftUI 앱
│   ├── DevSweepApp.swift  #  @main 진입점
│   ├── Engine.swift       #  @Observable — devsweep 서브프로세스 및 JSON 처리
│   ├── ContentView.swift  #  마스터-디테일 UI, 커스텀 확인 모달
│   ├── SettingsView.swift #  환경설정 · 자동 정리 · 앱 정보
│   ├── AutoClean.swift    #  launchd 스케줄링 + 회수 용량 조정
│   ├── Notifier.swift     #  정리 완료 알림
│   ├── Localization.swift #  15개 언어 테이블
│   └── Models · Theme · Icons · AppInfo · UpdateChecker …
├── Resources/
│   ├── Info.plist · AppIcon.icns · icons/*.svg
└── web/                   # 릴리스 랜딩 페이지 (15개 언어)
```

---

## 참고 사항

- **Full Disk Access** — `~/Library/Caches`(pip, brew, playwright, Xcode)를 읽고 정리하려면 **시스템 설정 → 개인 정보 보호 및 보안 → 전체 디스크 접근 권한**에서 `DevSweep.app`을 허용하세요. 홈 디렉토리 경로(`~/.gradle`, `~/.cargo`, `~/.npm`)는 해당 권한 없이도 동작합니다.
- **Ad-hoc 서명** — 첫 실행 시 Gatekeeper 경고가 표시될 수 있습니다 → **우클릭 → 열기**.
- **재다운로드 비용** — 일부 캐시(예: `wrapper/dists`, 레지스트리 캐시)는 다음 빌드 시 자동으로 다시 받아집니다. 정리 직후 첫 빌드는 다소 느릴 수 있지만, 데이터 손실은 없습니다.

---

## 라이선스

MIT License. 아이콘은 [Iconify Solar](https://icon-sets.iconify.design/solar/) 세트를 사용합니다.

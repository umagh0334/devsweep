# DevSweep 🧹

[English](README.md) | **한국어** | [日本語](README.ja.md) | [简体中文](README.zh-Hans.md) | [繁體中文](README.zh-Hant.md)

개발 도구들이 슬그머니 쌓아놓은 기가바이트를 되찾아 오세요. `gradle` 빌드, `docker` pull, `npm install`… 할 때마다 캐시가 쌓입니다. DevSweep은 Mac 전체에서 **44개 카테고리**를 스캔해 삭제해도 안전한 항목을 찾아내고, 깔끔하게 비워줍니다. 이제 눈치게임은 그만.

캐시뿐이 아닙니다. 흩어진 **빌드/의존 폴더**(`node_modules`, `target`, …)를 찾아내는 프로젝트 스캐너와, 노출된 비밀정보(`.env`, 개인키, 크리덴셜)를 점검하는 **보안 모드**까지 — 전부 **홈 대시보드** 하나에서 시작합니다.

**CLI**(`devsweep`, 단일 bash 스크립트)와 **네이티브 macOS 앱**(`DevSweep.app`, SwiftUI) 두 가지 형태로 제공됩니다. GUI는 동일한 검증된 엔진 위에 얹은 얇은 인터페이스입니다.

---

## 설계 원칙

| 원칙 | 의미 |
|------|------|
| **화이트리스트 전용** | 명시적으로 등록된 캐시 경로와 명령어만 건드립니다. 알 수 없는 경로는 그대로 둡니다 — 소스 코드와 프로젝트 파일은 절대 범위에 포함되지 않습니다. |
| **기본값은 드라이런** | 실행하면 *무엇이 해제될지*만 보여줍니다. 실제 삭제는 `--yes`(CLI) 또는 확인 버튼(GUI)이 있어야만 실행됩니다. |
| **도구 자체 클리너 우선** | `brew cleanup`, `npm cache clean`, `docker system prune` 등 각 도구의 공식 클리너를 먼저 사용하고, 없을 때만 `rm`으로 대체합니다. |

> 실제 무거운 작업(크기 측정, 삭제)은 OS와 각 도구가 처리합니다. DevSweep은 *어디를*, *안전하게*, *명확하게* 결정하는 역할만 합니다. 엔진으로 단일 bash 스크립트만으로 충분한 이유가 여기 있습니다.

> 🛡 **프라이버시** — 이 앱은 어떠한 경우에도 민감정보의 내용을 직접 읽거나 데이터를 외부로 전송하지 않습니다. 모든 스캔과 점검은 이 Mac 안에서만 이루어집니다. (네트워크는 GitHub 업데이트 확인·다운로드에만 사용되며, 이것도 설정에서 끌 수 있습니다.)

---

## 기능

**CLI**
- 스캔, 드라이런 미리보기, 선택/전체 정리
- `--json` / `detail` — GUI용 기계 가독 출력
- `scan-projects` / `scan-secrets` — 프로젝트 폴더·민감 파일 스캐너
- `--older-than=Nd` 나이 필터 · 설정 파일을 통한 보호 목록

**macOS 앱**
- **홈 대시보드** — 시간대별 웰컴 인사(이름 표시)·누적 회수량·개발 성향 프로필 칩, 회수 가능 영역이 표시된 디스크 게이지, 모드별 요약 카드(톱3 미리보기), 한 번에 스캔 버튼
- **캐시 모드** — 마스터-디테일 UI, 위험도 신호등 배지(안전/보통/주의), 추천 선택, 크기/이름 정렬, 실시간 정리 진행 창
- **프로젝트 스캐너** — 흩어진 `node_modules` / `target` / `.next` / `Pods` … 를 용량·미사용 기간과 함께 발견, 30일+ 미사용 필터
- **보안 점검** — 노출된 비밀정보를 git 인지 위험도로 판정(커밋됨=심각, gitignore 안 됨=높음): `.env`, SSH/TLS 개인키, kubeconfig, Docker·GitHub CLI·gcloud 인증, DB 비밀번호(`.pgpass`·`.my.cnf`), Apple `AuthKey` 등. 오래된 크리덴셜(180일+)과 느슨한 `~/.ssh` 권한도 경고. 리포트 전용: 내용을 읽지 않고 삭제도 안 함. `.gitignore` 추가/`chmod` 원클릭 조치 — 개별 또는 일괄
- **git 히스토리 검사** — 커밋 히스토리에 묻힌 시크릿을 [gitleaks](https://github.com/gitleaks/gitleaks)에 위임해 찾습니다(선택 사항, 없어도 앱은 정상 동작). 종류·파일·커밋·날짜만 가져오며 **시크릿 값 자체는 보유하지도 표시하지도 않습니다**
- **실시간 감시**(선택) — 새 `.env`·키 파일이 위험한 상태(gitignore 안 됨, 권한 느슨)로 생기면 **커밋되기 전에** 알려줍니다. FSEvents로 경로만 관찰하며 파일 내용은 읽지 않습니다
- **휴지통/완전삭제 선택** — 기본은 복구 가능한 휴지통, "방금 옮긴 항목만 영구삭제" 원클릭 제공
- **메뉴바 & 백그라운드 모드** — 회수 용량 표시 상태 아이콘, 독 숨기기, 로그인 시 시작
- **서명된 자동 업데이트** — Ed25519 서명 검증을 거친 릴리스만 설치, 하루 한 번 자동 확인
- **예약 자동 정리** — launchd를 이용한 일간 / 주간 / 월간 자동 실행. Docker처럼 상태가 있는 도구는 자동 실행 대상에서 의도적으로 제외됩니다.
- **권한 팝업 없는 스캔** — macOS 보호 폴더(데스크탑·문서·다운로드)는 기본 제외, 미디어 폴더(음악·사진·동영상)는 항상 제외 → 확인창이 아예 뜨지 않음. 포함 토글 + 설정의 전체 디스크 접근 안내 제공
- **보호 목록 · 나이 필터 · 완료 알림 · 커스텀 확인 모달**
- **15개 언어** — 시스템 로케일에서 자동 감지, 설정에서 직접 변경 가능

---

## 카테고리 (44개)

**Safe** (26개 — 기본 정리에 포함):

`gradle` `npm` `yarn` `pnpm` `bun` `pip` `uv` `cargo` `go` `cocoapods` `swiftpm` `composer` `nuget` `deno` `brew` `colima` `xcode` `vscode` `cursor` `zed` `codemate` `electron` `ccache` `gem` `poetry` `carthage`

**Heavy** (18개 — 재다운로드 비용이 크므로 명시적으로 지정하거나 `all` 사용 시만 정리):

`docker` `maven` `pub` `playwright` `rustup-targets` `xcode-sim` `huggingface` `jetbrains` `androidstudio` `codex` `puppeteer` `cypress` `ollama` `lmstudio` `xcode-devsupport` `simruntime` `conda` `bazel`

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
devsweep scan-projects ~  # 흩어진 빌드/의존 폴더를 JSON으로 출력
devsweep scan-secrets ~   # 노출된 민감 파일을 JSON으로 출력 (리포트 전용, 내용 안 읽음)
                          # --include-protected 추가 시 데스크탑·문서·다운로드도 스캔
devsweep scan-git-secrets ~   # gitleaks 로 git 히스토리 검사 — 메타데이터만, 시크릿 값은 미출력
devsweep check-secret <path>  # 파일 1개 판정 (실시간 감시가 사용)
```

어디서든 실행하려면 `PATH`에 심볼릭 링크를 추가하세요:

```bash
ln -s "$PWD/devsweep" ~/.local/bin/devsweep
```

---

## 빌드

빌드 스크립트는 저장소에 포함되지 않습니다 — 완성된 앱은 [Releases](https://github.com/umagh0334/devsweep/releases)에서 받으세요.

직접 빌드하는 것도 어렵지 않습니다: `swiftc`(Xcode Command Line Tools, 전체 Xcode 불필요)로 `Sources/*.swift`를 컴파일하고, `Resources/Info.plist`·`devsweep` 엔진·아이콘을 `.app` 번들로 묶은 뒤 ad-hoc 서명하면 됩니다. macOS 14+, **universal binary**(Apple Silicon + Intel).

---

## 프로젝트 구조

```
devsweep/
├── devsweep               # CLI 엔진 (bash) — 완전 독립 실행
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

## 첫 실행 — Gatekeeper

DevSweep은 **ad-hoc 서명**(공증 없음)이라 macOS Gatekeeper가 첫 실행을 차단합니다 — 최신 macOS에서는 "우클릭 → 열기"로도 안 되는 경우가 많습니다. 둘 중 한 방법으로 허용하세요:

**터미널 (가장 확실)** — quarantine 속성 제거:

```bash
xattr -dr com.apple.quarantine /경로/DevSweep.app
```

그 다음 평소대로 더블클릭하면 됩니다. 다운로드당 한 번만 하면 되며, 앱 내 자동 업데이트는 quarantine을 자동으로 제거합니다.

**시스템 설정** — 차단 직후: **시스템 설정 → 개인정보 보호 및 보안 → "확인 없이 열기"**.

> *"DevSweep이(가) 손상되었기 때문에 열 수 없습니다"* 가 떠도 같은 Gatekeeper 차단입니다 — 위 `xattr` 명령으로 해결됩니다.

받자마자 더블클릭으로 열리는 배포를 원하면 Apple Developer ID 서명 + 공증(유료)이 필요합니다.

---

## 로드맵

**완료**
- ✅ 보호 목록 · 나이 필터(`--older-than`) · 예약 자동 정리(launchd)
- ✅ 캐시 카테고리 44종 · 프로젝트 폴더 스캐너 · 보안 점검(개별/일괄 조치)
- ✅ git 히스토리 시크릿 검사(gitleaks 연동)
- ✅ 민감 파일 실시간 감시(FSEvents)
- ✅ 휴지통 모드 · 메뉴바 & 백그라운드 모드 · 개인화 홈 대시보드
- ✅ Ed25519 서명 자동 업데이트 · 15개 언어

**지원 예정**
- 정리 히스토리 — "언제 / 뭘 / 얼마나"
- 사용자 정의 카테고리
- 회수 용량 측정 정밀화
- Developer ID 서명·공증 (Gatekeeper 우회 절차 제거)

---

## 라이선스

MIT License. 아이콘은 [Iconify Solar](https://icon-sets.iconify.design/solar/) 세트를 사용합니다.

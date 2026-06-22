# DevSweep 🧹

개인용 **개발 캐시 / 임시파일 정리 도구**. 개발하다 보면 `~/.gradle`, `~/.cargo`, Homebrew, pip, Docker 등에 수 기가씩 캐시가 쌓이는데, 그걸 한눈에 보고 안전하게 정리한다.

**CLI**(`devsweep`)와 **네이티브 macOS 앱**(`DevSweep.app`) 두 가지 형태로 제공되며, GUI는 검증된 CLI 엔진을 그대로 재사용하는 하이브리드 구조다.

---

## 핵심 설계 원칙

| 원칙 | 내용 |
|------|------|
| **화이트리스트 방식** | 지워도 되는 경로/명령만 명시. 모르는 건 절대 안 건드림 (블랙리스트 X) |
| **기본 dry-run** | 그냥 실행하면 "뭘 얼마나 지울지"만 보여줌. 실제 삭제는 `--yes` 필요 |
| **네이티브 우선** | `brew cleanup`, `docker system prune`, `npm cache clean` 등 공식 명령 우선. 없을 때만 `rm` |

> 무거운 일(실제 삭제·용량 측정)은 OS와 각 도구가 하고, devsweep은 "어디를·안전하게·예쁘게"만 담당한다. 그래서 CLI 엔진이 단일 bash 스크립트로 충분하다.

---

## 아키텍처

```
┌─────────────────────────┐
│   DevSweep.app (SwiftUI) │   GUI — 시각화 / 인터랙션
│   Sources/*.swift        │
└───────────┬─────────────┘
            │ Process(/bin/bash) + JSON
            ▼
┌─────────────────────────┐
│   devsweep (bash CLI)    │   엔진 — 경로 규칙 / 안전장치 / 측정·삭제
└─────────────────────────┘
```

- GUI는 번들에 동봉된 `devsweep`을 subprocess로 호출하고, `--json` / `detail` 출력을 `Codable`로 파싱한다.
- 검증된 CLI 로직(화이트리스트·dry-run·방어 코드)을 그대로 재사용 → GUI는 표현 레이어만 담당.

---

## 지원 카테고리

**안전 카테고리** (`clean` / `clean all`에 자동 포함)

| 카테고리 | 대상 | 정리 방식 |
|----------|------|-----------|
| `gradle` | `~/.gradle/{caches,daemon,wrapper/dists,native}` | rm (재생성) |
| `npm` | `~/.npm/_cacache` | `npm cache clean --force` |
| `yarn` | `~/Library/Caches/Yarn` | `yarn cache clean` |
| `pnpm` | `~/Library/pnpm/store` | `pnpm store prune` |
| `bun` | `~/.bun/install/cache` | rm |
| `pip` | `~/Library/Caches/pip` | `pip3 cache purge` |
| `cargo` | `~/.cargo/{registry,git}` | rm |
| `brew` | `~/Library/Caches/Homebrew` | `brew cleanup -s --prune=all` |
| `docker` | 미사용 이미지/컨테이너/네트워크 | `docker system prune -f` |
| `xcode` | `~/Library/Developer/Xcode/DerivedData` | rm |

**heavy 카테고리** (재설치 비용이 커서, 이름을 직접 지정해야만 정리)

| 카테고리 | 대상 | 비고 |
|----------|------|------|
| `playwright` | `~/Library/Caches/ms-playwright` | 브라우저 수백MB~GB 재다운로드 |
| `rustup-targets` | 호스트 외 설치 타겟 | `rustup target remove` (툴체인 본체는 보존) |

---

## CLI 사용법

```bash
devsweep                  # 현황 스캔 (용량만, 아무것도 안 지움)
devsweep list             # 지원 카테고리 목록
devsweep clean            # 정리 미리보기 (dry-run, 안전 카테고리 전체)
devsweep clean --yes      # 실제 정리 실행
devsweep clean gradle npm        # 특정 카테고리만 미리보기
devsweep clean --yes gradle npm  # 특정 카테고리만 실제 정리
devsweep clean --yes all         # heavy 포함 전체 정리

# GUI 연동용 (기계 출력)
devsweep --json           # 전체 카테고리를 JSON 배열로
devsweep detail <cat>     # 카테고리 1개 상세 정보를 JSON 객체로
```

설치(선택): `~/.local/bin` 등 PATH 디렉토리에 심볼릭 링크를 걸면 어디서든 실행 가능.
```bash
ln -s "$PWD/devsweep" ~/.local/bin/devsweep
```

---

## GUI 앱 (DevSweep.app)

| 영역 | 기능 |
|------|------|
| **헤더** | 빗자루 로고 + 총 회수 가능 용량 |
| **리스트** | 체크박스(선택) · Solar 아이콘 · 이름/유형 · 용량 막대 · 용량 |
| **행 클릭 → 인라인 펼침 상세** | ① 경로별 용량 breakdown ② 정리 시 실제 실행 명령(+복사 버튼) ③ 재생성 비용 ④ 안전성 & TCC 권한 ⑤ docker/rustup 특수 정보 ⑥ "이 항목만 정리" |
| **푸터** | 선택 N개·용량 · [다시 스캔] · [선택 정리] |

- **체크박스 = 정리 대상 선택**, **본문 클릭 = 상세 펼침**으로 역할 분리. 여러 행을 동시에 펼쳐 용량을 나란히 비교할 수 있다.
- 상세 정보는 펼칠 때만 lazy 로드 + 캐시 → 스캔 성능 영향 0. 정리/재스캔 후 자동 무효화·재로드.

---

## 빌드

**요구사항**: Xcode Command Line Tools (`swiftc`). **Xcode 정식판 불필요.**

```bash
./build.sh
open DevSweep.app
```

`build.sh`는 `Sources/*.swift`를 `swiftc`로 컴파일하고, `Info.plist` · `devsweep` 엔진 · Solar 아이콘 · 앱 아이콘을 번들에 동봉한 뒤 ad-hoc 코드사이닝한다.

---

## 프로젝트 구조

```
devsweep/
├── devsweep                 # CLI 엔진 (bash, 424줄) — 단독으로도 완전 동작
├── build.sh                 # swiftc 컴파일 → DevSweep.app 번들 생성
├── Sources/                 # SwiftUI 앱 소스
│   ├── DevSweepApp.swift    #  @main 엔트리포인트
│   ├── Models.swift         #  CacheCategory · CategoryDetail · PathEntry
│   ├── Engine.swift         #  @Observable — devsweep subprocess 구동 + JSON 파싱
│   ├── ContentView.swift    #  리스트 · 펼침 상세뷰 · 행 컴포넌트
│   └── Icons.swift          #  SVG 아이콘 로더
├── Resources/
│   ├── Info.plist
│   ├── AppIcon.icns         # 앱 아이콘
│   └── icons/*.svg          # Iconify Solar 아이콘 13종
└── DevSweep.app             # 빌드 산출물
```

---

## 기술적 특징

- **swiftc 단독 빌드** — Xcode 프로젝트 파일(`.xcodeproj`) 없이 Command Line Tools만으로 네이티브 `.app` 생성. 의존성 0.
- **NSImage SVG 직접 로드** — macOS 26의 NSImage는 SVG를 벡터로 렌더한다. `isTemplate=true`로 두면 알파 채널만 사용해 `foregroundStyle` 틴팅(다크모드 자동 대응)이 된다. PNG 변환 파이프라인 불필요.
- **`@Observable` + lazy detail 캐시** — 펼친 카테고리만 `devsweep detail`을 호출하고 `detailCache`에 보관. `.task(id: detail == nil)`로 정리 후 자동 재로드.
- **`set -euo pipefail` 방어** — JSON 조립 중 `du`·`command -v`·`grep`의 비제로 종료가 스크립트를 죽이지 않도록 `[ -e ]` 가드 + `${var:-0}` + 서브셸 `|| echo 0`로 방어.
- **하위호환** — `detail` / `--json` 모드 추가 시에도 기존 `scan`/`clean`/`list` 출력은 무변경.

---

## ⚠️ 주의사항

- **Full Disk Access**: `.app`이 `~/Library/Caches`(pip·brew·playwright·xcode)를 읽고 정리하려면 권한 필요.
  → **시스템 설정 → 개인정보 보호 및 보안 → 전체 디스크 접근 권한**에 `DevSweep.app` 추가.
  `~/.gradle`·`~/.cargo`·`~/.npm` 등 홈 직속 경로는 권한 없이도 동작.
- **코드사이닝**: 개인용 ad-hoc 서명이라 Gatekeeper가 경고할 수 있음 → 첫 실행은 **우클릭 > 열기**.
- **재다운로드 비용**: `modules-2`·`wrapper/dists` 등 일부 캐시는 정리 후 다음 빌드 시 다시 받아야 하므로 첫 빌드가 느려질 수 있음 (데이터 손실은 아님).

---

## 라이선스 / 비고

개인용 도구. 아이콘은 [Iconify Solar](https://icon-sets.iconify.design/solar/) 세트 사용.

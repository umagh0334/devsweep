# CHANGELOG

## 2026-06-22

### ℹ️ 정보 섹션 재구성 + 업데이트 확인
기존(설정 파일 / 총 회수 가능 / 카테고리 / 아이콘 — 쓸모 적음) → 4개로 교체.

- **버전 + 업데이트**: `AppInfo`(버전·repo·제작자·라이선스) + `UpdateChecker` — GitHub `releases/latest` API 의 `tag_name`을 현재 버전과 **semver 비교**. 새 버전이면 릴리스 페이지 열기(수동 다운로드). 자동 설치는 코드사이닝/notarization 필요해 제외
- **총 회수한 용량**: 정리할 때마다 `@AppStorage("totalReclaimedKB")` 에 누적(정보성)
- **저작권**: MIT · **제작자** + GitHub 링크
- **검증**: 버전 비교 5케이스 + GitHub API JSON(`tag_name`/`html_url`) 파싱 확인
- ⚠️ **`AppInfo.swift` 의 `repoOwner`/`repoName`/`author` 는 추측값**(wyatt/devsweep/Wyatt) — 실제 값으로 수정 필요 (현재 `api.github.com/repos/wyatt/devsweep` 는 404)

### ⏳ 나이 필터 완성 (측정 + 정리 + GUI)
이전엔 정리(`clean --older-than`)만 됐고 측정은 전체였음 → 측정·정리 모두 나이 반영으로 완성.

- **CLI**: `--older-than`을 **전역 옵션**으로 승격 → `scan`/`--json`/`detail`/`clean` 모두 적용. `paths_size_kb`가 `find -mtime +N -exec stat`로 **오래된 파일만 집계** → 측정도 나이별(모든 핸들러가 이 함수를 쓰므로 자동 전파)
- **경로 없는 카테고리**(`NO_AGE_CATS` = docker·rustup-targets·xcode-sim)는 나이 필터 시 제외. 네이티브 경로 카테고리(npm 등)는 나이 필터 시 경로를 직접 mtime 삭제(전체 cleanup 명령 우회 → 측정과 정리 일관)
- **GUI**: 설정 > 나이 필터에 기간 picker(끄기/7/30/90/180일, `@AppStorage("olderThanDays")`), 변경 시 재스캔. `Engine`이 scan/detail/clean에 `--older-than=Nd` 전달. 메인 헤더에 활성 배지 `N일+ 만`
- **검증**: 격리 HOME(전체 300KB→30일+ 200KB, old.jar만 삭제·new.jar 보존) + GUI(4.1GB→2.6GB, npm 등 최근 캐시는 "캐시 없음"으로 이동)

### 🗂 메뉴바 로컬라이제이션
- Info.plist `CFBundleLocalizations`(12개 언어) + `CFBundleDevelopmentRegion` 선언 + build.sh 가 빈 `<lang>.lproj` 생성 → **AppKit 표준 메뉴(파일·편집·보기·윈도우·도움말)가 시스템 언어로 자동 번역**. (선언 전엔 영어 고정이었음)
- 커스텀 "설정…" 메뉴 항목도 `tr("menu.settings", .systemDefault)` 로 번역
- 검증: 시스템 언어 ko 환경에서 메뉴바 `파일/편집/보기/윈도우/도움말` 확인
- 한계: 메뉴바는 **시스템 언어** 기반(앱 내 언어 설정과 별개) — AppKit 구조상 런타임 동기화 불가

### 🌐 다국어 (i18n) — 12개 언어
영어 · 한국어 · 일본어 · 중국어(간체/번체) · 태국어 · 베트남어 · 이탈리아어 · 프랑스어 · 스페인어 · 포르투갈어 · 크로아티아어.

- `Localization.swift` 신규: `AppLanguage` enum + 번역 테이블(70+ 키 × 12 언어) + `tr()` 헬퍼 + `kindKey()` 정규화
- **swiftc 단독 빌드라 `.lproj`/`.strings` 대신 Swift 테이블** + `environment(\.appLanguage)` 전파 → 앱 내 **즉시 전환**(`@AppStorage("language")` + 뷰 재평가)
- **설정 > 일반에 언어 picker**(시스템 자동 + 12개 언어, 각 언어 자기 이름으로 표기)
- 번역 범위: 앱 UI 전부(버튼·라벨·섹션·배지) + `kind`(CLI 한국어값 → 키 정규화) + 안전성/재생성 노트(`safety`·`regen_cost` 코드 기반으로 생성)
- CLI 동적 텍스트(실행 명령·경로·docker extra)는 그대로 — CLI i18n 필요해 후속
- 검증: 번역 로직을 명령행에서 직접 실행(`swiftc Localization.swift main.swift`)해 12언어·동적 포맷(`%d`/`%@`)·폴백 확인. 시각 검증은 캡처 권한 제약으로 생략

### 🪟 설정창 Form 레이아웃 · 창 크기 고정
- 설정 섹션(일반·보호 목록·정보)을 **`Form(.grouped)` + `LabeledContent`**로 재구성 — 레이블 좌 / 컨트롤 우, GroupBox 카드(macOS 시스템설정 스타일). 외관=세그먼트, 언어=팝업, 토글은 부제 2줄
- "준비 중" 섹션(나이 필터·자동 정리)의 안내문구 **중앙 정렬**(`.frame(maxWidth/maxHeight: .infinity)` — detail 의 `.topLeading` 무시)
- **창 크기 고정**: 메인 900×620, 설정 680×480 — `.windowResizability(.contentSize)`로 리사이즈 불가(환경설정 스타일)

### 🎨 UI 개편 — "Sweep Console" (frontend-design)
개발 캐시 도구의 핵심(회수량 + 분포)을 주인공으로 세운 비주얼 아이덴티티. AI 디폴트(니어블랙+네온그린) 회피, 차분한 잉크 베이스 + 정보를 인코딩하는 색 시스템.

- **디자인 토큰** `Theme.swift` 신규 — 시맨틱 색: `sweep`(틸-아쿠아, 정리/회수) · `heavy`(앰버) · `guard`(슬레이트, 보호) + 분포 팔레트 8색
- **시그니처: 헤더 분포 스택 바** — 전체 캐시를 카테고리별 색 세그먼트로 ("디스크 개발 캐시 지도"), "brew 최다 · 1.3GB / 외 N종"
- **헤더**: 대형 SF Mono 회수량(틸) + 빗자루 + "N개 추적 중"
- **행**: Solar 아이콘 칩(색 배경) + full-width 용량 게이지(분포바와 같은 순위색) + 선택 시 틸 테두리/체크박스. 0KB는 흐린 트랙으로 차분하게
- **타이포**: 용량/경로/명령 = SF Mono, 제목/이름/배지 = rounded
- **인터랙션: 인라인 펼침 → 마스터-디테일** (`HSplitView`) — 좌측 카테고리 리스트 클릭 시 우측 패널에 상세(아이콘 칩·대형 용량·배지·경로별·명령·노트·정리 버튼). **체크박스(정리 대상)와 행 클릭(상세 보기)을 역할 분리**. 스캔 후 최다 용량 항목 자동선택, `ScrollViewReader` 로 활성 항목 가시성 보장
- **리스트 정렬·그룹화**: 용량 있는 카테고리를 큰 순으로 위에, 캐시 없는(용량 0) 카테고리는 **"캐시 없음" 섹션으로 하단 분리** + 체크박스 비활성 + 흐리게(활성 선택 시 또렷). 정리할 게 있는 항목에 시선 집중. 정렬과 무관하게 동작하도록 `Engine.setSelected(name:_:)` 로 체크 갱신
- **설정창**: 동일 토큰 통일(틸 액센트·rounded·공통 `SettingsHeader`·시맨틱 배지)
- **검증**: 라이트/다크 양쪽 cua-driver 스크린샷 — `.regularMaterial` + 시맨틱 색이 양쪽 적응
- Iconify Solar 아이콘 그대로 유지(`isTemplate` 틴팅)

---

## 2026-06-21

### 🔒 보호 목록 (protect list)
화이트리스트 위에 얹는 "보호 목록" — 등록한 카테고리는 정리/관여에서 영구 제외.

- **CLI** (`devsweep`)
  - `~/.config/devsweep/config` 의 `protect=cat1,cat2` 파싱 → `PROTECTED` 배열, `is_protected()` 헬퍼 (`DEVSWEEP_CONFIG` 로 경로 오버라이드 가능)
  - `scan`: `🔒 보호됨` 마킹 / `--json`·`detail`: `protected` 필드
  - `clean`: 자동(clean/all)은 조용히 제외, 명시 지정(`clean gradle`)은 경고 후 차단 — `--force` 로 우회
- **GUI** (`DevSweep.app`)
  - `CacheCategory`·`CategoryDetail` 에 `protected` 필드
  - 메인 행: 체크박스 비활성 + `보호` 배지 + 흐림, 상세뷰 `보호됨` 배지, "이 항목만 정리" 비활성, 자동선택 제외

### ⏳ 나이 필터 (`--older-than`)
오래된 캐시만 골라 정리 — "정리하면 재빌드 느려짐" 단점 완화.

- `clean --older-than 30d` (또는 `2w` / `30`) → `wipe()` 가 `AGE_DAYS` 있으면 `find -type f -mtime +N -delete` + 빈 디렉터리 정리
- `atime` 대신 `mtime` 채택 (macOS noatime 환경 대응)
- 값 검증(비숫자 오류), 네이티브 카테고리(`npm`/`brew`/`docker` 등)는 나이 개념 없어 건너뜀 + 안내, dry-run 안내 문구

### ⚙️ 환경설정 창 (시스템설정 스타일)
- `Settings` scene → 별도 `Window` + `.defaultPosition(.center)` — 화면 중앙에서 열림(우측 갑툭튀 해결). Cmd+, 와 하단 "환경설정" 버튼으로 연결
- 좌측 사이드바 5섹션 + 우측 디테일. `NavigationSplitView` 가 Window 안에서 콘텐츠 높이를 강제하는 문제 → **수동 `HStack` 레이아웃**(사이드바 `.regularMaterial`)으로 크기 완전 제어 (660×470 고정)
- Solar 아이콘 4종 추가: `shield`·`clock`·`calendar`·`info` (Iconify Solar bold, 기존 13종과 동일 스타일)
- 메인 창과 설정 창이 같은 `Engine` 공유 → 보호 토글 즉시 반영

### 🧩 일반 설정
- **외관**: 시스템 / 라이트 / 다크 (`preferredColorScheme`)
- **앱 시작 시 자동 스캔** on/off (`ContentView.task`)
- **HEAVY 카테고리 기본 선택** on/off (`Engine.scan` 자동선택 규칙)
- `@AppStorage` 저장 — 외관 즉시 반영, HEAVY 토글 시 재스캔

### 보호 목록 관리 UI
- 환경설정 → 보호 목록 섹션의 토글이 `Engine.toggleProtect` 로 `config` 의 `protect=` 라인을 대신 R/W (다른 라인 보존) → config 수동 편집 불필요

### 📦 카테고리 확장 (12 → 23종)
- **SAFE 추가**: `go`(go-build+pkg/mod) · `maven`(.m2) · `cocoapods` · `swiftpm` · `composer`(PHP) · `nuget`(.NET) · `deno` · `pub`(Dart/Flutter) · `colima`
- **HEAVY 추가**: `xcode-sim`(사용불가 시뮬레이터) · `huggingface`(ML 모델, GB급)
- `go`/`nuget` 네이티브 명령 우선(`go clean -cache -modcache`, `dotnet nuget locals all --clear`), `xcode-sim`은 `xcrun simctl delete unavailable`
- **colima 주의**: 다운로드 캐시(`~/Library/Caches/colima`, 317M)만 정리. VM 디스크(`~/.colima/_disks` = 컨테이너 데이터, 관측 57G)는 화이트리스트 밖 — 그쪽 용량은 `docker` 카테고리의 `docker system prune`(colima VM 내부)이 담당
- GUI `Models.iconName` 매핑 갱신 (box/package/server/code/database)

### ✅ 검증
- **CLI**: 격리된 `HOME` 으로 보호/나이필터 왕복 테스트(`old.jar` 삭제·`new.jar` 보존 확인), 회귀(`detail` 12종 JSON valid, `--json` 스키마)
- **GUI**: `cua-driver` 로 실제 앱 구동 — 사이드바 5섹션, 카테고리 토글, 나이필터 섹션 전환, 레이아웃 겹침 수정, 창 높이 정상화 스크린샷 확인

### 파일
- `Sources/SettingsView.swift` 신규(187줄) · `DevSweepApp.swift`·`ContentView.swift`·`Engine.swift`·`Models.swift` 수정
- `devsweep` (CLI) 보호 목록·나이 필터 로직 추가 · `Resources/icons/` 4종 추가
- `TODO.md`·`CHANGELOG.md`

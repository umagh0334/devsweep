# CHANGELOG

## 2026-08-02 (v0.2.0)

### 👋 홈 개인화
- 시간대별 웰컴 인사(아침/오후/저녁/밤) + 이름 — 설정 '표시 이름' > macOS 계정 이름 폴백. 누적 회수량 라인("지금까지 N GB 비웠어요")
- **프로필 칩** — 페르소나(풀스택 잡식러 등)+시즌 배지 수를 홈에 노출, 클릭 시 설정 '내 프로필' 탭 직행
- 설정 > 일반 최상단에 '표시 이름' 입력란

### 🔒 보안 점검 v2
- 민감 파일 패턴 **+11종**: kubeconfig(`~/.kube/config`)·docker/gh/gcloud 인증·`.pgpass`·`.my.cnf`·`AuthKey_*.p8`·GCP 서비스계정 json — 흔한 이름(config 등)은 경로 게이팅으로 오탐 차단
- **오래된 크리덴셜**: 키/크리덴셜이 180일+ 묵으면 🟡 "N일 된 크리덴셜 — 로테이션 권장" (mtime 기반, 내용 안 읽음)
- **~/.ssh 폴더 권한 점검**: 700 아니면 🟡, [권한 수정]이 폴더는 700·파일은 600으로 자동 구분해 조임

### 🔕 권한 팝업 원천 차단
- 스캔 때마다 뜨던 "Apple Music/미디어 보관함 접근" 팝업의 원인 = find 가 `~/Music` 라이브러리 번들에 닿는 것 → **Music·Pictures·Movies 항상 제외**(직접 지정 시 예외)

### 🪟 트레이 '창 열기' 무반응 수정 (dock 숨김 + 로그인 자동실행 조합)
- 로그인 백그라운드 시작 시 창이 key 가 된 적 없으면 창 보존 훅이 안 걸려, 닫는 순간 SwiftUI 가 창을 파괴 → '창 열기'가 무반응이던 버그
- 지연 스캔으로 커버 + identifier 기반 창 판별(설정 창 오인 제거) + 파괴 시 `openWindow(id:"main")` 재생성 폴백
- **동적 정책 전환**: 창이 떠 있는 동안 .regular(좌상단 메뉴 바 = DevSweep, dock 잠깐 표시) ↔ 다 닫으면 .accessory(트레이만) — 메뉴 바가 Finder 로 남던 문제 해소

### 🧭 UI 통일
- 옵션 기어를 4탭 모두 **하단 최우측**으로 통일 · `bottomBarStyle`(minHeight 48) 공통화로 탭 전환 시 경계선 흔들림 제거
- 보안 탭: 요약 스트립(위) ↔ 조치 바(최하단) 스왑 — 캐시/프로젝트와 동일 구조, 조치 바 항상 표시

## 2026-08-01 (v0.1.6 · v0.1.7 · v0.1.8)

### 📊 홈 카드 톱3 미리보기 + 한 번에 스캔 — v0.1.8
- 카드 중앙 빈 공간을 정보로: 캐시=용량 톱3 카테고리+상대크기 미니바 · 프로젝트=무거운 폴더 톱3(경로·용량) · 보안=위험도 분해(심각/높음/보통/낮음, 0건 생략). 스캔 전엔 안내문
- **[한 번에 스캔]** — 캐시+프로젝트+보안 3개 스캔을 `async let` 동시 실행(엔진 재진입 가드가 중복 차단), 완료 후 디스크 여유공간 갱신
- 카드 높이 캡(200~300) — 창 높이에 따라 무한정 늘어나던 여백 제거. `home.*` 3키 × 15언어

### 🏠 홈 대시보드 — v0.1.7
- 4번째 탭이자 시작 화면: `[🏠][캐시][프로젝트][보안]` (홈은 하우스 아이콘 세그먼트)
- **디스크 게이지** — 실제 사용량 바 안에 '회수 가능' 영역을 틸로 하이라이트(volumeAvailableCapacityForImportantUsage, Finder 기준)
- **모드 요약 카드 3장** — 호버 리프트 + 클릭 시 탭 이동, 보안 카드는 위험 유무로 상태색(오렌지/그린)
- **[추천 정리 시작]** — 메뉴바와 동일 플로우(requestCleanRecommended) 재사용
- **실행 시 항상 홈** — appMode 를 @AppStorage→@State 로 강등해 마지막 탭 복원 자체를 제거. `home.*` 11키 × 15언어

### 🛠 보안 일괄 조치 + 권한 수정 — v0.1.6
- **[권한 수정]** — 권한 느슨한 개인키(644 등)를 `chmod 600` 원클릭 조치(FileManager.setAttributes). 권한만 문제던 항목은 낮음으로 강등
- **선택 수정** — 수정 가능 행(untracked·권한 느슨 키)에만 체크박스 + [전체 선택]/[선택 항목 수정] 일괄 바. 항목별 조치 자동 라우팅(untracked→.gitignore, 느슨한 키→chmod, 둘 다면 둘 다)
- 🔴 심각(tracked)은 배치 제외 — gitignore 추가로는 히스토리가 안 지워져 거짓 안심이 되므로 개별 확인 유도

### 🚫 TCC 보호 폴더 기본 제외 + FDA 온보딩 — v0.1.6
- 스캔 때마다 "폴더 접근 허용?" 팝업이 뜨던 문제: 데스크탑·문서·다운로드를 **기본 prune**(`set_prot_prune`) → 팝업 원천 차단. 툴바 [보호 폴더 포함] 토글(`--include-protected`)로 옵트인, 보호 폴더를 root 로 **직접 지정하면 예외**(사용자 의도 존중)
- 설정 > 일반에 **전체 디스크 접근(FDA)** 상태 행 + 시스템 설정 딥링크. 감지는 TCC.db 열기 시도(팝업 없이 판별), 시스템 설정에서 돌아오면 자동 재확인
- ad-hoc 서명은 빌드마다 cdhash 가 바뀌어 TCC 허용이 리셋됨 — 근본 해결은 Developer ID(백로그)

### 🧭 헤더 탭 위치 고정 — v0.1.6
- 캐시↔프로젝트↔보안 전환 시 방금 누른 탭이 옆으로 밀리던 문제: 회수량 블록이 탭 오른쪽에 조건부로 붙어 있던 것이 원인 → 우측 코너를 VStack(탭 상단 고정 + 회수량 그 아래)으로 재배치, 창 620→650

## 2026-07-31 (v0.1.5)

### 🔒 보안 점검 모드 (신규 탭)
- `.env`·개인키(id_rsa 등)·크리덴셜(.npmrc·.netrc·~/.aws)·tfstate 를 찾아 **노출 위험도** 판정: git tracked=🔴심각(히스토리 노출) / untracked=🟠높음(다음 커밋에 딸려감) / 개인키 권한 느슨=🟡보통 / 보호됨=🟢낮음
- **report-only 원칙**: 파일명·git 상태·권한만 판정 — 내용을 절대 읽지 않고 삭제도 안 함. 조치는 [Finder 열기]·[.gitignore 추가]
- CLI `scan-secrets` (`secret_kind`+`git_leak_state`, 서브디렉토리는 `git -C` 로 repo 루트 기준 판정). `.env.example`·`.pub`·node_modules 등 제외. `sec.*` 20키 × 15언어

### 📦 카테고리 31 → 44
- Safe +5: electron ccache gem poetry carthage / Heavy +8: puppeteer cypress ollama lmstudio xcode-devsupport simruntime conda bazel
- 기존 경로 보강: npm `_npx`, playwright `ms-playwright-go`, vscode/cursor `CachedExtensionVSIXs`

### 🗑 휴지통 정리 마감 · 🔄 자동 업데이트 확인 · ⚙️ 기타
- 휴지통 모드 정리 후 완료 화면에서 [휴지통 열기]/[방금 항목만 영구삭제] — 이번에 옮긴 것만 비움(휴지통 전체는 절대 안 비움)
- 24시간마다 새 버전 자동 확인(끌 수 있음), 새 버전만 알림 — 설치는 여전히 사용자가 승인
- 로그인 시 시작(SMAppService, 실패 시 토글 자동 복원) · App Translocation 감지 배너([옮기고 재시작] 원클릭)

## 2026-07-20 (v0.1.4 — 첫 정식 배포)

### 🔐 자동 업데이트 Ed25519 서명 검증 (신뢰 경계 확립)
- 릴리스 zip 에 분리 서명(`.app.zip.sig`)을 첨부하고, 앱에 내장된 공개키로 **압축 해제 전에** 검증. 서명 누락/불일치 시 설치 거부
- 개인키는 repo 밖(`~/.config/devsweep/`)에만 존재. `build.sh --release` 가 서명 후 앱 공개키로 자체검증(불일치 시 릴리스 중단). `tools/ed25519.swift`(CryptoKit, 의존성 0)
- 실측: 배포본 비인증 다운로드→검증 OK, 1바이트 변조→거부

### 🗑 휴지통/완전삭제 선택 · ⚡ 정리 진행 창
- 정리 확인창에서 삭제 방식 선택: 휴지통(기본·복구 가능) / 완전삭제. 큰 폴더도 UI 를 막지 않게 백그라운드 수행
- 정리 중 항목별 대기→정리 중→완료/실패 상태와 누적 회수량을 실시간 모달로 표시. 실패 항목은 회수량에 반영 안 됨(부분 실패 묻힘 수정)

### 📊 메뉴바 · 📁 프로젝트 폴더 스캐너
- NSStatusItem 메뉴바: 회수 가능 용량 한눈에 + 안전셋 정리·다시 스캔·창 열기. 설정에서 용량 표시·독 숨기기 토글
- 프로젝트 스캐너(신규 탭): 고정 경로 캐시로 안 잡히던 흩어진 `node_modules`·`target`·`.next`·`dist`·`Pods`·`.venv` 등을 크기·미사용 기간과 함께 발견, 30일+ 필터

### ✨ UI 다듬기
- 추천 버튼을 누를 수 있는 칩으로(테두리+포인터 커서) · 크기순/이름순 정렬 토글 · 설치 버튼 `vv0.1.3` 표기 수정 · 릴리스 zip `._*` 잡파일 제거(`--norsrc --noextattr --noqtn`)

## 2026-06-23

### ⏰ 자동 정리 스케줄 커스터마이징 (실행 시각·요일·날짜)
- 실행 시각 하드코딩(새벽 3시) 제거 → **DatePicker(시:분)**로 사용자가 지정. 모든 주기 공통
- **매주 → 요일 선택**(매주 화요일 등), **매월 → 날짜 선택**(1~28일). 요일명은 `Calendar.standaloneWeekdaySymbols`+앱 언어 `Locale`로 OS 현지화(요일 i18n 84개 회피), launchd Weekday(0=일)와 인덱스 일치
- **"매월 특정 요일"은 미지원**: launchd `StartCalendarInterval`이 Weekday·Day 를 동시 지정 시 AND 아닌 **OR**로 동작해 "매월 둘째 화요일" 표현 불가 → 매월은 날짜 기준. 매월 Day 는 29~31 짧은달 누락 방지로 1~28 만
- `AutoClean.enable`/`syncIfNeeded` 시그니처에 hour·minute·weekday·day 추가, `scheduleXML` clamp(시0~23·분0~59·요일0~6·일1~28). AppStorage 4키(autoCleanHour/Minute/Weekday/Day). onChange 들을 `reapplySchedule`(백그라운드 디스패치)로 통합
- `auto.time`/`auto.weekday`/`auto.monthday`/`auto.dayFmt` 12언어 + `auto.toggleDesc` "새벽 3시"→"지정한 시각" 일반화
- 검증: 빌드 + **생성 plist 확인**(매주 화 14:30 → `Weekday:2 Hour:14 Minute:30`, `RunAtLoad=false` 유지) + UI 스크린샷(실행 시각 "오후 2:30"·요일 "화요일"). 검증 LaunchAgent·defaults 원복

### ✏️ '오래된 캐시만 정리' → '오래된 캐시 정리'
- 섹션 헤더 `set.age` 에서 "만" 제거 → 더 간결하게 (12언어)

### ✏️ 고급 설정 나이 필터 라벨 명확화
- 섹션 헤더 `set.age` "오래된 항목만" → **"오래된 캐시만 정리"**(동작까지 한눈에, "항목"→"캐시" 구체화), 12언어 갱신
- Picker 라벨 `age.label` 한국어 "기간 기준" → **"기준 기간"**(어순 교정, ko만)
- 검증: 빌드, cua 스크린샷

### 🏷️ '개발자' 탭 → '내 프로필'로 개명 + 위치 이동
- '개발자' 탭이 옆의 '고급 설정'과 혼동돼 전문/고급 기능처럼 오해될 소지 → **'내 프로필'**(My Profile)로 개명. 실제 내용(캐시로 본 개발 성향·스택·배지)이 "프로필"에 부합
- 사이드바 순서: 맨 끝(고급 설정 뒤) → **일반 바로 다음**(일반 → 내 프로필 → 보호 목록 → 고급 설정 → 정보). 발견성↑, '일반' 첫 자리 관례 유지
- `SettingsSection` 선언 순서가 사이드바 순서이므로 enum 재배열 + `set.developer`→`set.profile` rename(12언어 "내 프로필"). 케이스명/구조체(DeveloperSettings)는 유지 — 내부 식별자 불변
- 검증: 빌드, cua 스크린샷(순서·라벨 반영 확인)

### 💎 배지 희소성(획득 난이도) 등급 시스템
- 배지마다 조건 난이도 기반 **정적 희소성 등급** 4단계: 보통/중간/희소/매우 희소 (로컬 전용 앱이라 유저 통계% 같은 동적 희소도는 불가 → 조건 난이도로 정적 부여)
- 분류: 보통 4(multimanager·container·apple·cleanup) · 중간 5(compile·e2e·hoarder·diskhog·early) · 희소 5(ml·polymaster·vmheavy·builder·crossplat) · 매우 희소 2(datasci·cleanmaster)
- 색 관습(게임식): 보통 회색 · 중간 파랑 · 희소 보라 · 매우 희소 금색. **enum은 데이터(DevProfile), 색은 뷰(SettingsView)** 분리(DevProfile은 Foundation만 의존)
- 표시: 획득 타일에 등급 테두리 색 / 호버 팝오버 `[이모지][제목]···[희소도]` 한 줄 + 설명 둘째 줄(유동 너비 — 제목 `fixedSize`로 줄바꿈 차단, 설명만 maxWidth 안에서 wrap → 긴 언어에서도 안 깨짐) / 전체 배지 갤러리에 이름 아래 등급 라벨 + 테두리(미획득도 희귀도 미리 노출 → 해금 동기)
- `rarity.*` 4종 × 12언어 신규. 검증: 빌드, cua 스크린샷(타일 테두리 회색/파랑 구분, 갤러리 등급 라벨 렌더)

### 🏅 획득 배지 → 아이콘 전용 + 호버 설명
- 획득 배지 섹션을 칩(아이콘+제목)에서 **아이콘 타일만** 표시로 개편. 마우스 오버 시 제목(굵게)+설명이 위쪽 팝오버로 떠서 정보 노출(깜빡임 방지 위해 `arrowEdge:.top`로 배지를 안 가림)
- 배지 설명 `badge.<key>.desc` 16종 × 12언어 신규(획득 조건을 친근하게). `[...]` 전체 배지 갤러리는 그대로 유지
- 검증: 빌드 통과, cua AX 트리로 아이콘 전용 렌더(🧩🐳🦀🎭📦, 제목 없음) + 스크린샷 확인

## 2026-06-22

### ⏰ 자동 정리 (launchd 주기 실행) 구현
- 고급 설정에 **토글 + 주기(매일/매주/매월)**. 켜면 새벽 3시 launchd LaunchAgent 가 `devsweep clean` 을 headless 실행 (보호 목록·나이 필터 그대로 적용)
- 설계: 독립 설계안 3 + launchd 함정 전문가 워크플로 → 적대적 비평(go=true) → 비평의 high 결함(측정 의미 불일치·python3 숨은 의존·native 측정 오차) 모두 수정 반영
  - `launchctl bootout→bootstrap gui/$UID` 멱등(EBUSY 회피), `RunAtLoad=false`(켜자마자 삭제 방지), `StartCalendarInterval`(Day:1·Minute:0 고정)
  - 엔진/래퍼를 `~/Library/Application Support/DevSweep/engine/` 로 복사(번들 경로 불안정 회피) + 버전 self-heal
  - 회수량: **`devsweep total` 신설**(clean과 동일 타겟의 KB만 출력) → 래퍼가 before/after diff(python3 등 외부 의존 0). `runs.jsonl` append만, 앱이 워터마크 reconcile 로 `totalReclaimedKB` 단독 write (cfprefsd 레이스 차단)
  - TCC: `~/Library/Caches` 계열은 headless 권한으로 빠질 수 있어 blocked 시 전체 디스크 접근 안내(과약속 안 함)
- 신규 `AutoClean.swift`, `devsweep cmd_total`, `auto.*` 12언어. 미사용 `adv.soon`/`coming.scheduleDesc` 제거
- **적대적 코드 리뷰**(3차원 병렬 → 확정 검증, 18후보→5확정) 반영: ① 회수량을 before/after diff→**정리 직전 추정치**로 통일(네이티브 명령이 측정 경로 밖을 비우는 불일치 해소) ② reconcile 워터마크 ts→**라인카운트**(같은 초 다중 run 누락 방지) ③ onChange의 launchctl/파일복사 **백그라운드 디스패치**(메인스레드 블로킹/UI 끊김 제거) ④ 신뢰 못 할 'blocked' 휴리스틱 제거 → FDA 안내 상시화(정상 0회수 오탐 방지)
- 검증: 빌드, `total` 일관성, launchctl bootstrap/bootout/kickstart 메커니즘 + EBUSY 재현, reconcile 멱등성·증분(라인카운트, 같은 초 안전), UI 렌더, 잔여 에이전트 0

### 🔭 홈 폴더 캐시 전수 검토 → uv·codex 추가
- `~/` 숨김 폴더 전수 조사 후 안전한 캐시만 선별 추가. 카테고리 29→31개
- **uv**(Python, Astral): `~/.cache/uv`(+`~/Library/Caches/uv`) 222M, 네이티브 `uv cache clean`. SAFE. `~/.local/share/uv`(설치된 파이썬·툴)은 데이터라 제외
- **codex 런타임**: `~/.cache/codex-runtimes` 1.4G, 재다운로드 비용 커서 HEAVY + NO_AGE(런타임 all-or-nothing). `~/.codex`(세션·설정)은 제외
- 큰데 캐시 아닌 것 의도적 제외: `.colima`(58G VM 디스크), `.vscode`(1.3G 설치 확장), `.claude`(대화·프로젝트 데이터), `.nvm`(설치된 Node 버전), `.rustup`(툴체인)

### 💻 IDE 캐시 지원 추가
- 패키지 매니저 외 IDE 캐시 5종: **JetBrains · VS Code · Cursor · Android Studio · Zed** (Xcode DerivedData는 기존 지원). 카테고리 23→28개
- 순수 캐시/인덱스 디렉토리만 (설정·확장·워크스페이스 상태 제외). JetBrains·Android Studio는 재인덱싱 비용 커서 HEAVY 분류
- `devsweep` CLI에 `SAFE/HEAVY_CATS` 등록 + `do_<name>` 핸들러 + `cmd_detail` 메타(kind=재생성·safety·command)만 추가하면 GUI(리스트·스택 도넛·배지)는 `--json`으로 자동 반영, `code` 아이콘
- 검증: vscode 148MB(CachedData 132MB) 측정, 미설치 IDE는 0으로 "캐시 없음" 그룹
- **codemate(자체 IDE) 추가**: `~/.codemate`는 대부분 비-캐시(lib·bin 본체, local.db, auth, settings)라 **로그/캐시만**(`userdata/logs` 83M + `caches` + `daemon.log`) 타겟. 검증 85MB. 본체·DB·인증·설정은 제외
- cmux는 미추가 — 진짜 캐시 없이 활성 이벤트 로그(events.jsonl 등)뿐이고, cmux.app이 세션을 실시간 구동 중이라 정리 대상으로 부적합

### 🪟 설정 창이 재실행 시 같이 뜨던 문제 수정
- 설정 창을 켠 채 앱을 종료하면, 다시 실행할 때 macOS **창 상태 복원**으로 설정 창까지 같이 팝업되던 버그
- Info.plist `NSQuitAlwaysKeepsWindows=false` 로 창 복원 비활성화. 메인 창은 `WindowGroup`이라 항상 새로 생성되므로 영향 없고, 보조 `Window`(설정)만 복원에서 빠짐
- 검증: 설정 열고 정상 종료 → 재실행 시 창이 메인 1개뿐(`DevSweep`)

### 🎲 개발 성향 카드 (재미)
- **"개발자" 설정 섹션 신설** — 사이드바 5개로(일반 / 보호 목록 / 고급 설정 / 개발자 / 정보), Solar `user` 아이콘. 성향 카드를 정보 탭에서 개발자 섹션으로 분리
- 캐시 분포로 추정한 **개발 성향 카드**: 생태계별(node·python·rust·apple·container·ml·jvm·go·brew…) 용량 집계 → 최다 생태계로 페르소나 + 재치 멘트
- 6개+ 생태계면 "🧰 풀스택 잡식러", cargo 최다면 "🦀 러스트 장인", docker/colima 최다면 "🐳 컨테이너 집사" 등. 규칙 기반(LLM 호출 없음)
- **전 언어 번역**: 페르소나(별명 17 + 멘트 17) + 배지 8 = 42키를 12개 언어로 (`profile.title.*` / `profile.sum.*` / `badge.*`). `DevProfile`을 `ko ? :` 분기에서 `tr()` 기반으로 리팩토링 — 멘트의 용량은 `%@`, 생태계 수는 `%d` 포맷. 생태계명(Node·Rust·Homebrew…)은 고유명사라 미번역
- 검증: 일본어 전환 시 "フルスタック雑食 / 6個のエコシステム… / マルチマネージャ" 정상
- **스택 분포 도넛 차트**: 생태계별 용량을 도넛으로 시각화 — `Circle().trim(from:to:)` 누적(의존성 0, Swift Charts 미사용)으로 섹터를 그리고, 중앙에 총합 + 우측 범례(색·이름·용량). 메인 분포 바와 같은 팔레트(`Theme.segment`)
- **획득 배지(업적) 16종**: 멀티 매니저(node 매니저 2개+) / 컨테이너 운영 / 컴파일 인내(rust 200MB+) / ML 탐험가 / E2E 신봉자 / 애플 개발자 / 패키지 수집가(생태계 5종+) / 정리왕(누적 1GB+) / 디스크 대식가(총 10GB+) / 다언어 마스터(생태계 8종+) / VM 헤비웨이트(컨테이너 3GB+) / 데이터 사이언티스트(python+ML) / 얼리어답터(deno·bun) / 빌드 장인(컴파일 언어 2종+) / 크로스플랫폼(Dart) / 정리 마스터(누적 10GB+) — 조건 충족분만 칩으로. 모두 독립 조건이라 이론적 컴플리션 가능
- **배지 (획득/총) 카운터 + 전체 배지 목록**: 헤더가 "획득 배지 (5/16)"(카운터를 제목 바로 옆) + 우측 […] 버튼 → 팝오버에 전체 16개 표시(`Grid` 3열[이모지·이름·상태], 획득=컬러+✓·미획득=흐림+🔒 **우측 정렬**, 폭은 이름 열에 맞춰 유동). 배지 정의를 `allBadges` 데이터 배열로 리팩토링해 총 개수 자동 산출
- **시즌제 배지**: 한 번 획득하면 유지 기간(1·3·6개월 선택, 기본 1달) 동안은 캐시를 정리해도 유지되고, 만료되면 현재 조건으로 재판정. 획득 시각을 `@AppStorage`(badgeEarned JSON)에 저장하고 진입·기간변경 시 `refreshEarned`로 만료 제거+신규 획득. 검증: 미충족 배지를 10일 전 획득으로 심으니 1달 기간 내라 칩 유지됨(6/16)
- **유지 기간 설정은 고급 설정으로 이동**: 개발자 탭 배지 헤더에선 (획득/총) 카운터만, 기간(1·3·6개월) 선택은 고급 설정 > 획득 배지 섹션에 picker + 설명
- **다른 타입 둘러보기**: 성향 카드 우측 […] 버튼 → 팝오버에 전체 페르소나 **별명만** 나열 (보기 전용). 설명은 실제로 그 성향이 됐을 때 카드에서 보이는 "해금" 재미 (`galleryItem`은 이모지+별명만 반환). 팝오버 폭은 가장 긴 별명에 맞춰 자동 조절(`fixedSize(horizontal:)`)
- **성향 카드 레이아웃**: 설명을 이름 바로 아래(아이콘 옆 텍스트 블록)로 정렬

### 🔧 나이 필터로 0이 된 항목 안내 (혼란 완화)
- "보호 해제했는데 체크 안 됨" 신고 → 진단 결과 **보호 버그 아님**. 나이 필터("오래된 항목만") 켜진 상태에서 최근 캐시(colima 317MB 등)가 나이 기준 0으로 잡혀 "캐시 없음"+비활성된 것. 보호 해제(`protected=false`)는 정상 반영됐지만 `!hasSize`(나이 0)로 잠금 유지
- 비활성 항목 툴팁 분기: 나이 필터 활성 + 용량 0이면 "정리할 캐시 없음" → **"최근 — 필터로 제외 (끄면 표시)"** 로 이유 명시
- **정리 가능 항목이 전부 비었을 때**(필터 기준에 걸리는 게 없음) 리스트에 안내 배너 + **"필터 끄기" 버튼**: "N일보다 오래된 항목이 없어요 / 필터를 끄면 전체 정리 가능"
- 실제 정리하려면 고급 설정 > 오래된 항목만 = 끄기

### ⚙️ 나이 필터 + 자동 정리 → "고급 설정" 통합
- 설정 사이드바 5→4개 (일반 / 보호 목록 / 고급 설정 / 정보). 나이 필터·자동 정리를 **"고급 설정" 한 화면의 두 Form Section**으로 묶음 (`AgeSettings` → `AdvancedSettings`)
- Solar `tuning` 아이콘 추가, 미사용 `comingSoon` 헬퍼 제거
- 검증: 사이드바 4섹션 + 고급 설정에 "나이 필터(기간 기준)" / "자동 정리(준비 중)" 두 Section 확인

### 🔒 보호 항목 별도 그룹
- 메인 리스트를 **3그룹**으로: 정리 가능(용량순) / 🔒 보호됨(자물쇠 헤더) / 캐시 없음. 이전엔 보호 항목이 용량 유무에 따라 정리가능·캐시없음에 섞여 있었음
- 보호된 항목은 **회수 가능량·분포 바·선택 정리에서 제외** (정리 대상이 아니므로) — `totalKB`·`ranked` 가 `!protected` 필터
- 검증: cargo 임시 보호 시 회수량 4.1→3.8GB, 분포바 "외 6종→5종", cargo 가 보호됨 그룹으로 이동

### 🎯 메인·설정 창 항상 화면 중앙
- 켤 때마다 화면 중앙에 표시 (macOS 의 이전 위치 복원 무시). `.onAppear`에서 `center()`로 복원 위치를 덮어씀 + `defaultPosition(.center)` 보조. 메인은 `NSApp.windows.first(isVisible)`, 설정창은 title("DevSweep 설정")로 식별
- 검증: 메인 — (100,100)으로 옮겨도 재실행 시 (450,135) 복귀 / 설정창 — (560,170), 둘 다 화면 중앙
- (시행착오) `.background(NSViewRepresentable)` 로 윈도우 잡으려다 생성이 깨짐(0개) → `.onAppear` + `NSApp.windows` 로 전환

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

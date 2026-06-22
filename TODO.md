# DevSweep TODO 🧹

향후 추가/개선 기능 목록. 우선순위 순. 각 항목에 구현 포인트(`파일:라인`)와 GUI 연동 메모를 같이 적어둔다.

> 설계 철학(화이트리스트 · 기본 dry-run · 네이티브 우선)을 깨지 않는 선에서만 추가한다.
> CLI(`devsweep`)는 **앱 없이 단독 완전 동작**을 유지한다 — 설정/상태를 앱 전용 경로에 두지 않는다.

---

## P1 — 보호 목록 (protect list) 🔒 ✅ *(GUI 토글 제외 완료)*

**무엇**: 환경설정으로 특정 카테고리를 "정리 대상에서 영구 제외"한다. 화이트리스트에 있어도 devsweep이 삭제/관여하지 않음. (남겨둬야 하는 캐시 보호용)

**용어**: 기존 화이트리스트(지울 것만 명시) **위에 얹는 보호 목록**. 전역 `--yes` 안전장치를 "특정 카테고리만 영구 dry-run"으로 세분화한 것.

- [x] **설정 파일** — `~/.config/devsweep/config` (단순 텍스트, CLI 단독 동작 유지). `DEVSWEEP_CONFIG` 환경변수로 경로 오버라이드 가능
  ```
  protect=gradle,cargo   # 주석 가능
  ```
  - 시작 시 1회 파싱 → `PROTECTED=(...)` 배열. `is_protected()` 헬퍼로 판정
- [x] **`clean` 필터** — `targets` 확정 직후 보호 카테고리 제거. `clean` / `clean all` 자동 건너뜀
- [x] **`scan` / `--json` / `detail` 표시** — scan은 `🔒 보호됨` 마킹, json/detail은 `"protected":bool` 필드. (정리 대상 ≠ 가시성)
- [x] **명시 지정 충돌** — `clean gradle`인데 gradle이 보호 목록이면 **경고 후 차단**. `--force`로 우회
- [x] **GUI 표시** — `CacheCategory`/`CategoryDetail`에 `protected` 필드 → 행 체크박스 비활성 + `보호` 배지 + 흐림 처리, 상세뷰 `보호됨` 배지, "이 항목만 정리" 비활성, 자동선택에서 제외
- [x] **GUI 환경설정 토글** — `Settings` scene(Cmd+, / footer 환경설정 버튼)에 카테고리 목록 + 보호 스위치. 토글 시 `Engine.toggleProtect`가 `~/.config/devsweep/config`의 `protect=` 라인을 대신 쓰고 재스캔 → 메인 창 자물쇠 즉시 반영. config 수동 편집 불필요

---

## P1 — 나이 기반 필터 (`--older-than <N>d`) ⏳ ✅ *완료 (측정·정리·GUI)*

**무엇**: 전부 날리지 말고 **오래된 캐시만** 정리. 이 도구의 유일한 실질 단점("정리하면 재빌드 느려짐")을 직접 해소.

- [x] `clean --older-than 30d`(또는 `2w`/`30`) → `wipe()`가 `AGE_DAYS` 있으면 `find -type f -mtime +N -delete` + 빈 디렉터리 정리. **`atime` 대신 `mtime` 채택** (macOS noatime 환경에서 atime 비신뢰)
- [x] 값 정규화/검증 — `Nd`/`Nw`/`N` 파싱, 비숫자는 오류 후 `return 1`
- [x] 네이티브 cleanup 카테고리(`NATIVE_CATS`)는 나이 개념 없음 → 나이 필터 지정 시 **건너뜀 + 안내**
- [x] dry-run에 나이 필터 안내 문구(전체 기준 용량임을 정직하게 표기)
- [x] **size 핸들러 정밀 측정 완료** — `paths_size_kb`가 `find -mtime +N -exec stat`로 나이별 집계 → `--older-than` 전역화로 scan/json/detail/clean 측정 모두 정확. 경로 없는 항목은 `NO_AGE_CATS`로 제외

---

## P2 — before/after 측정 정확도 개선

**무엇**: 현재 확보량 측정이 하드코딩 경로 기준이라 부정확. playwright만 지워도 "확보 0"으로 나올 수 있음.

- [ ] `cmd_clean`의 before/after를 하드코딩 경로(`devsweep:402-403`, `devsweep:408-409`)가 아니라 **실제 정리한 `targets`의 경로 합산**으로 변경
- [ ] 재료는 이미 있음 — `"do_$c" paths` 액션(`devsweep:92`)으로 카테고리별 경로를 뽑아 합산하면 됨
- [ ] docker/rustup은 경로 합산 대상에서 제외(VM 내부 / 추정 불가) 유지

---

## P2 — JSON 출력 견고성 (경로 특수문자)

**무엇**: `emit_json`이 name/kind를 escape 없이 박음(`devsweep:70-74`). 카테고리 이름이 고정인 현재는 안 터지지만, 사용자 정의 카테고리/보호 목록 도입 시 깨질 수 있음.

- [ ] `--json` 출력도 `json_escape`(`devsweep:77`) 적용해 `detail`과 일관성 확보
- [ ] (선택) 경로에 `"` `\` 들어가는 케이스 회귀 테스트

---

## P2 — 카테고리 확장

**무엇**: `do_<cat>` + `handle_paths` 패턴(`devsweep:86-107`)이 정형화돼 있어 경로형 카테고리는 거의 한 줄 추가. 빠진 굵직한 것들:

- [x] **12 → 23종 확장** — `go`·`maven`·`cocoapods`·`swiftpm`·`composer`·`nuget`·`deno`·`pub`·`colima`(SAFE), `xcode-sim`·`huggingface`(HEAVY)
- [x] `go`/`nuget` 네이티브 명령 우선, `xcode-sim`은 `xcrun simctl delete unavailable`
- [x] `colima`는 다운로드 캐시만 — VM 디스크(컨테이너 데이터)는 제외, docker prune 담당
- [ ] (남음) `ccache`(`~/.ccache`), conda·electron·node-gyp·vcpkg 등 추가 후보
- [ ] (남음) `docker system prune` 에 `--volumes` 옵션 검토 (colima/docker 볼륨까지 회수)

---

## P3 — 히스토리 로그

**무엇**: "언제 / 뭘 / 얼마 확보"를 기록해 정리 빈도 관리. heavy 카테고리 재다운로드 비용이 큰 만큼 쓸모 있음.

- [ ] `~/.devsweep/history.log`에 `clean --yes` 실행 시 1줄 append (timestamp · 카테고리 · 확보 용량)
- [ ] (선택) `devsweep history` 명령으로 조회

---

## P3 — launchd 주기 실행

**무엇**: macOS 네이티브답게 주기적 자동 정리. "네이티브 우선" 철학과 일치.

- [ ] `devsweep schedule weekly` → `~/Library/LaunchAgents/com.devsweep.cleanup.plist` 생성, 주 1회 `clean --yes`
- [ ] `devsweep schedule off` → plist 제거 + `launchctl unload`
- [ ] 보호 목록 자동 반영(P1과 연동) — 스케줄 정리도 보호 카테고리는 건너뜀
- [ ] GUI 환경설정에 토글

---

## 설정창 — 준비중 섹션 실구현 (신규)

환경설정 창에 자리만 잡아둔 섹션들을 실제 기능으로 채우기.

- [x] **나이 필터 섹션 완료** — 기간 picker(끄기/7/30/90/180일) → `@AppStorage("olderThanDays")` → `Engine`이 scan/detail/clean 에 `--older-than=Nd` 전달, 변경 시 재스캔, 메인 헤더 `N일+ 만` 배지
- [ ] **자동 정리 섹션** — P3 launchd 토글을 이 섹션에 배치(주기 선택 + on/off). 보호 목록·나이 필터와 연동
- [ ] **정리 전 확인 다이얼로그** — GUI "선택 정리" / "이 항목만 정리"에 `confirmationDialog` (실수 방지). 일반 설정에 on/off 토글
- [ ] **정보 섹션 보강** — 히스토리 로그(P3) 연동 시 "마지막 정리: 날짜·용량" 표시

---

## 공통 메모

- GUI 연동은 대부분 `Models.swift`에 `Codable` 필드 1개 추가 → `ContentView.swift`에서 표시. **CLI를 먼저 고치면 앱은 거의 따라옴.**
- 모든 신규 출력은 기존 `scan`/`clean`/`list`/`--json`/`detail` 하위호환 유지(README 기술적 특징 §하위호환).
- `set -euo pipefail` 하에서 외부 명령 실패가 JSON/스크립트를 죽이지 않도록 `[ -e ]` 가드 · `${var:-0}` · `|| echo 0` 방어 패턴 준수.

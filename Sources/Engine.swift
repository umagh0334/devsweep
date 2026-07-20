import Foundation
import Observation

/// devsweep CLI 엔진을 subprocess로 구동하는 어댑터.
/// 모든 상태 변경은 MainActor에서, 무거운 Process 실행만 백그라운드 큐로 내보낸다.
@MainActor
@Observable
final class Engine {
    var categories: [CacheCategory] = []
    var isScanning = false
    var isCleaning = false
    var lastLog = ""
    var errorMessage: String?

    // ── 정리 진행 창 상태 (순차 정리 루프가 실시간 갱신) ──
    var showCleanProgress = false      // 진행 오버레이 표시 여부
    var cleanItems: [CleanItem] = []   // 정리 대상별 실시간 상태
    var cleanReclaimedKB = 0           // 누적 회수량(성공 항목만)
    var cleanDone = false              // 루프 종료 → 요약+닫기 표시

    // ── 프로젝트 폴더 스캐너 상태 (node_modules·target 등) ──
    var isScanningProjects = false
    var projectDirs: [ProjectDir] = []
    var projectScanRoot = ""

    /// 펼친 카테고리의 상세 정보 캐시 (lazy 로드). 정리/재스캔 후 무효화됨.
    var detailCache: [String: CategoryDetail] = [:]
    var loadingDetails: Set<String> = []
    /// scan/clean 으로 detailCache 가 비워질 때마다 증가. 같은 항목이 선택된 상태에서도
    /// DetailPanel 의 .task(id:) 를 재실행시켜 상세가 빈칸으로 남는 것을 방지한다.
    var detailRevision = 0

    /// 앱 번들 Resources에 복사된 devsweep 스크립트 경로
    private var enginePath: String? {
        Bundle.main.url(forResource: "devsweep", withExtension: nil)?.path
    }

    /// 나이 필터 인자 — 설정값(olderThanDays)이 0보다 크면 --older-than=Nd 적용 (측정·정리 공통)
    private var ageArgs: [String] {
        let d = UserDefaults.standard.integer(forKey: "olderThanDays")
        return d > 0 ? ["--older-than=\(d)d"] : []
    }

    /// 에러 배너용 표시 언어 — 사용자가 앱에서 고른 언어, 없으면 시스템 추정 (DevSweepApp.lang 과 동일 규칙).
    private var uiLang: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "language") ?? "") ?? .systemDefault
    }

    /// `devsweep --json`을 돌려 카테고리 목록을 갱신한다.
    func scan() async {
        guard !isScanning, !isCleaning else { return }   // 정리 중엔 동시 스캔 차단(상태 꼬임 방지)
        isScanning = true; errorMessage = nil
        defer { isScanning = false }

        guard let path = enginePath else {
            errorMessage = tr("err.engineMissing", uiLang); return
        }
        do {
            let out = try await run([path, "--json"] + ageArgs)
            let decoded = try JSONDecoder().decode([CacheCategory].self, from: Data(out.utf8))
            let keepSelected = Set(categories.filter(\.selected).map(\.name))
            let includeHeavy = UserDefaults.standard.bool(forKey: "selectHeavy")
            categories = decoded.map { item in
                var c = item
                // 신규 선택이든 기존 선택 보존이든 hasSize && !protected 를 강제 —
                // 재스캔 후 0KB/보호로 바뀐 항목이 체크된 채 남아 카운트를 오염시키지 않게.
                c.selected = keepSelected.isEmpty
                    ? ((includeHeavy || !item.heavy) && item.hasSize && !item.protected)
                    : (keepSelected.contains(item.name) && item.hasSize && !item.protected)
                return c
            }
            detailCache.removeAll()   // 용량이 갱신됐으니 stale 상세 무효화
            detailRevision &+= 1      // 같은 항목 선택 상태에서도 상세 패널 재로드 트리거
            // 메뉴바 표시용 회수 가능 용량(보호 제외) 저장
            UserDefaults.standard.set(categories.filter { !$0.protected }.reduce(0) { $0 + $1.sizeKB }, forKey: "reclaimableKB")
        } catch {
            errorMessage = tr("err.scanFmt", uiLang, error.localizedDescription)
        }
    }

    /// 카테고리 1개 상세 정보를 lazy 로드 (펼칠 때 호출). 캐시 히트/중복 로드 가드.
    func loadDetail(_ name: String) async {
        guard detailCache[name] == nil, !loadingDetails.contains(name) else { return }
        guard let path = enginePath else { return }
        loadingDetails.insert(name)
        defer { loadingDetails.remove(name) }
        do {
            let out = try await run([path, "detail", name] + ageArgs)
            detailCache[name] = try JSONDecoder().decode(CategoryDetail.self, from: Data(out.utf8))
        } catch {
            errorMessage = tr("err.detailFmt", uiLang, name, error.localizedDescription)
        }
    }

    /// targets=nil이면 선택된 것 전체, 값 있으면 그 카테고리만 정리한다.
    /// 카테고리를 **하나씩 순차** 정리하며 진행 창(cleanItems)을 실시간 갱신 — 항목별 exit code(P1)로
    /// 완료/실패를 정확히 판정하고, 회수량은 성공한 항목만 누적한다(거짓 회수량 방지).
    func clean(targets: [String]? = nil) async {
        let names = targets ?? categories.filter(\.selected).map(\.name)
        guard !names.isEmpty, !isCleaning else { return }
        isCleaning = true; errorMessage = nil

        guard let path = enginePath else {
            errorMessage = tr("err.engineMissing", uiLang); isCleaning = false; return
        }

        // 진행 모델 초기화 — 큰 것부터(회수량이 빠르게 오름). 크기는 정리 전 측정치.
        let sizeByName = Dictionary(categories.map { ($0.name, $0.sizeKB) }, uniquingKeysWith: { a, _ in a })
        cleanItems = names.map { CleanItem(name: $0, sizeKB: sizeByName[$0] ?? 0) }
                          .sorted { $0.sizeKB > $1.sizeKB }
        cleanReclaimedKB = 0
        cleanDone = false
        showCleanProgress = true

        // 삭제 방식 — 0=휴지통(기본·복구가능) 1=완전삭제. 확인창 세그먼트가 AppStorage 로 저장.
        let useTrash = UserDefaults.standard.integer(forKey: "deleteMode") == 0

        for i in cleanItems.indices {
            cleanItems[i].status = .cleaning
            do {
                try await cleanOne(cleanItems[i].name, path: path, useTrash: useTrash)
                cleanItems[i].status = .done
                cleanReclaimedKB += cleanItems[i].sizeKB
            } catch {
                cleanItems[i].status = .failed
                cleanItems[i].reason = error.localizedDescription
            }
        }

        // 성공분만 누적 + 알림 (실패 항목은 회수량에서 제외)
        if cleanReclaimedKB > 0 {
            let prev = UserDefaults.standard.integer(forKey: "totalReclaimedKB")
            UserDefaults.standard.set(prev + cleanReclaimedKB, forKey: "totalReclaimedKB")
            if UserDefaults.standard.object(forKey: "notifyOnClean") as? Bool ?? true {
                Notifier.cleanDone(reclaimedKB: cleanReclaimedKB)
            }
        }
        cleanDone = true
        isCleaning = false
        await scan()   // 배경 리스트 갱신(용량 0으로). 모달은 별도 cleanItems 라 안 흔들림.
    }

    /// 카테고리 1개 정리 — 휴지통(경로를 trashItem, 복구가능) 또는 완전삭제(CLI clean). 실패 시 throw.
    private func cleanOne(_ name: String, path: String, useTrash: Bool) async throws {
        if useTrash {
            // 삭제 대상 경로를 받아 휴지통으로. 경로 없는 명령기반(docker·rustup)은 네이티브 clean 폴백.
            let out = try await run([path, "paths", name])
            let paths = out.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
            if paths.isEmpty {
                _ = try await run([path, "clean", "--yes", name] + ageArgs)
            } else {
                try trashPaths(paths)
            }
        } else {
            _ = try await run([path, "clean", "--yes", name] + ageArgs)
        }
    }

    /// 경로들을 macOS 휴지통으로 이동 (복구가능·되돌리기 지원). 없는 경로는 스킵, 실패 시 throw.
    private func trashPaths(_ paths: [String]) throws {
        let fm = FileManager.default
        for p in paths {
            let url = URL(fileURLWithPath: (p as NSString).expandingTildeInPath)
            guard fm.fileExists(atPath: url.path) else { continue }
            try fm.trashItem(at: url, resultingItemURL: nil)
        }
    }

    /// 진행 창 닫기 — 완료 요약 확인 후 사용자가 직접 닫을 때.
    func dismissCleanProgress() {
        showCleanProgress = false
        cleanItems = []
        cleanReclaimedKB = 0
        cleanDone = false
    }

    // ── 프로젝트 폴더 스캐너 ──

    /// root 아래에서 무거운 빌드/의존 폴더(node_modules 등)를 찾아 목록 갱신 (크기 내림차순).
    func scanProjects(root: String) async {
        guard !isScanningProjects else { return }
        isScanningProjects = true; errorMessage = nil
        defer { isScanningProjects = false }
        guard let path = enginePath else { errorMessage = tr("err.engineMissing", uiLang); return }
        do {
            let out = try await run([path, "scan-projects", root])
            var dirs = try JSONDecoder().decode([ProjectDir].self, from: Data(out.utf8))
            dirs.sort { $0.sizeKB > $1.sizeKB }
            projectDirs = dirs
            projectScanRoot = root
        } catch {
            errorMessage = tr("err.scanFmt", uiLang, error.localizedDescription)
        }
    }

    func setProjectSelected(_ id: String, _ value: Bool) {
        if let i = projectDirs.firstIndex(where: { $0.id == id }) { projectDirs[i].selected = value }
    }
    func setAllProjectsSelected(_ value: Bool) {
        for i in projectDirs.indices { projectDirs[i].selected = value }
    }

    /// 선택된 프로젝트 폴더를 순차 정리하며 진행 창을 실시간 갱신 (캐시 정리와 동일 UI 재사용).
    /// 삭제 방식(휴지통/완전)은 캐시 정리와 공유(deleteMode).
    func cleanProjects() async {
        let sel = projectDirs.filter(\.selected)
        guard !sel.isEmpty, !isCleaning else { return }
        isCleaning = true; errorMessage = nil
        let useTrash = UserDefaults.standard.integer(forKey: "deleteMode") == 0

        cleanItems = sel.map { CleanItem(name: prettyPath($0.path), sizeKB: $0.sizeKB, id: $0.path) }
                        .sorted { $0.sizeKB > $1.sizeKB }
        cleanReclaimedKB = 0; cleanDone = false; showCleanProgress = true

        for i in cleanItems.indices {
            cleanItems[i].status = .cleaning
            do {
                try await cleanPath(cleanItems[i].id, useTrash: useTrash)
                cleanItems[i].status = .done
                cleanReclaimedKB += cleanItems[i].sizeKB
            } catch {
                cleanItems[i].status = .failed
                cleanItems[i].reason = error.localizedDescription
            }
        }
        if cleanReclaimedKB > 0 {
            let prev = UserDefaults.standard.integer(forKey: "totalReclaimedKB")
            UserDefaults.standard.set(prev + cleanReclaimedKB, forKey: "totalReclaimedKB")
            if UserDefaults.standard.object(forKey: "notifyOnClean") as? Bool ?? true {
                Notifier.cleanDone(reclaimedKB: cleanReclaimedKB)
            }
        }
        cleanDone = true; isCleaning = false
        // 정리 성공한 폴더는 목록에서 제거
        let doneIds = Set(cleanItems.filter { $0.status == .done }.map(\.id))
        projectDirs.removeAll { doneIds.contains($0.path) }
    }

    /// 경로 1개를 휴지통(복구가능) 또는 완전삭제(rm). 큰 폴더가 UI 를 막지 않게 백그라운드에서 수행.
    private func cleanPath(_ path: String, useTrash: Bool) async throws {
        try await Task.detached(priority: .userInitiated) {
            let url = URL(fileURLWithPath: path)
            let fm = FileManager.default
            guard fm.fileExists(atPath: url.path) else { return }
            if useTrash { try fm.trashItem(at: url, resultingItemURL: nil) }
            else { try fm.removeItem(at: url) }
        }.value
    }

    /// 표시용 경로 축약 — 홈은 ~ 로, 너무 길면 앞을 …로.
    private func prettyPath(_ p: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var s = p.hasPrefix(home) ? "~" + p.dropFirst(home.count) : p
        if s.count > 42 { s = "…" + s.suffix(41) }
        return String(s)
    }

    /// 카테고리 선택(정리 대상) 토글 — 마스터 행 체크박스용 (정렬과 무관하게 이름으로 갱신).
    func setSelected(_ name: String, _ value: Bool) {
        if let i = categories.firstIndex(where: { $0.name == name }) {
            categories[i].selected = value
        }
    }

    /// 전체 선택/해제 — 정리 가능(hasSize && !protected) 항목만 일괄 토글.
    /// 0KB/보호 항목은 애초에 체크 불가라 건드리지 않아 선택 규칙(P1-3)과 일관.
    func setAllSelected(_ value: Bool) {
        for i in categories.indices where categories[i].hasSize && !categories[i].protected {
            categories[i].selected = value
        }
    }

    /// 추천 선택 — 안전하게 지워도 되고 실제 용량이 있는 항목만(SAFE·!heavy·hasSize·!protected).
    /// HEAVY(docker·huggingface·xcode-sim 등 재다운로드 비쌈)·보호·0KB 는 제외. 전체 항목에 술어를
    /// 적용해 기존 선택(수동 체크한 heavy 포함)을 추천셋으로 '교체'한다 — 토글 아닌 정규화.
    func setRecommended() {
        for i in categories.indices {
            let c = categories[i]
            categories[i].selected = !c.heavy && c.hasSize && !c.protected
        }
    }

    // ── 보호 목록 관리 (환경설정) ──
    //   GUI 토글이 config 파일을 대신 쓴다. CLI와 동일 경로라 다음 스캔에 즉시 반영.

    /// CLI와 동일 경로: ~/.config/devsweep/config
    private var configURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/devsweep/config")
    }

    /// 카테고리의 보호 여부를 토글 → config 반영 → 재스캔(protected 갱신).
    func toggleProtect(_ name: String, _ on: Bool) async {
        var names = Set(categories.filter(\.protected).map(\.name))
        if on { names.insert(name) } else { names.remove(name) }
        writeProtectedConfig(names)
        await scan()
    }

    /// config 의 protect= 라인만 교체(다른 라인 보존). 디렉터리 없으면 생성.
    private func writeProtectedConfig(_ names: Set<String>) {
        let dir = configURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var lines: [String] = []
        if let existing = try? String(contentsOf: configURL, encoding: .utf8) {
            lines = existing.split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("protect=") }
        }
        if !names.isEmpty { lines.append("protect=" + names.sorted().joined(separator: ",")) }
        while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty { lines.removeLast() }
        let content = lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
        try? content.write(to: configURL, atomically: true, encoding: .utf8)
    }

    /// /bin/bash 로 devsweep 실행, stdout 문자열을 반환. 동기 Process API를 async로 브리지.
    /// 계약: exit≠0 이면 stderr 를 담아 throw → 호출부가 회수량 누적/디코드를 건너뛴다.
    private func run(_ args: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/bin/bash")
                proc.arguments = args
                // GUI 앱은 launchd 환경이라 PATH 가 최소(/usr/bin:/bin…)라서 brew/npm/docker 등
                // 네이티브 cleanup 명령을 못 찾는다. 자동정리 plist 와 동일하게 Homebrew 경로 보강.
                var env = ProcessInfo.processInfo.environment
                let base = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                env["PATH"] = env["PATH"].map { "\(base):\($0)" } ?? base
                proc.environment = env
                let outPipe = Pipe(), errPipe = Pipe()
                proc.standardOutput = outPipe
                proc.standardError = errPipe
                do {
                    try proc.run()
                    // 두 파이프를 동시에 비운다 — 순차로 읽으면 한쪽(예: stderr)이 버퍼(≈64KB)를
                    // 먼저 채울 때 자식이 그 write 에서 블록되고, 안 읽힌 쪽 EOF 가 안 와 데드락이 난다.
                    var errData = Data()
                    let errGroup = DispatchGroup()
                    errGroup.enter()
                    DispatchQueue.global(qos: .userInitiated).async {
                        errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                        errGroup.leave()
                    }
                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    errGroup.wait()
                    proc.waitUntilExit()
                    guard proc.terminationStatus == 0 else {
                        let err = String(decoding: errData, as: UTF8.self)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        cont.resume(throwing: EngineError.cli(code: proc.terminationStatus, stderr: err))
                        return
                    }
                    cont.resume(returning: String(decoding: outData, as: UTF8.self))
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }
}

/// 엔진 subprocess 실패 — exit 코드와 stderr 를 보존해 UI 배너에 노출한다.
enum EngineError: LocalizedError {
    case cli(code: Int32, stderr: String)
    var errorDescription: String? {
        switch self {
        case let .cli(code, stderr):
            return stderr.isEmpty ? "엔진 실패 (코드 \(code))" : "엔진 실패 (코드 \(code)): \(stderr)"
        }
    }
}

/// 정리 진행 창의 항목 1개 — 순차 정리 루프가 status 를 pending→cleaning→done/failed 로 실시간 갱신한다.
/// id 는 고유키(카테고리명 or 프로젝트 전체경로), name 은 표시명(카테고리명 or 축약 경로).
struct CleanItem: Identifiable, Equatable {
    let name: String
    let sizeKB: Int
    var status: CleanStatus = .pending
    var reason: String? = nil        // 실패 시 상세(행 툴팁)
    let id: String
    init(name: String, sizeKB: Int, id: String? = nil) {
        self.name = name; self.sizeKB = sizeKB; self.id = id ?? name
    }
}
enum CleanStatus: Equatable { case pending, cleaning, done, failed }

/// 프로젝트 스캐너가 찾은 무거운 폴더 1개 (node_modules·target 등).
struct ProjectDir: Identifiable, Decodable, Equatable {
    let path: String
    let sizeKB: Int
    let ageDays: Int
    var selected: Bool = true          // JSON 에 없음 → 기본 선택
    var id: String { path }
    enum CodingKeys: String, CodingKey { case path; case sizeKB = "size_kb"; case ageDays = "age_days" }
}

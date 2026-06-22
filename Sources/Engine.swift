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

    /// 펼친 카테고리의 상세 정보 캐시 (lazy 로드). 정리/재스캔 후 무효화됨.
    var detailCache: [String: CategoryDetail] = [:]
    var loadingDetails: Set<String> = []

    /// 앱 번들 Resources에 복사된 devsweep 스크립트 경로
    private var enginePath: String? {
        Bundle.main.url(forResource: "devsweep", withExtension: nil)?.path
    }

    /// 나이 필터 인자 — 설정값(olderThanDays)이 0보다 크면 --older-than=Nd 적용 (측정·정리 공통)
    private var ageArgs: [String] {
        let d = UserDefaults.standard.integer(forKey: "olderThanDays")
        return d > 0 ? ["--older-than=\(d)d"] : []
    }

    /// `devsweep --json`을 돌려 카테고리 목록을 갱신한다.
    func scan() async {
        guard !isScanning else { return }
        isScanning = true; errorMessage = nil
        defer { isScanning = false }

        guard let path = enginePath else {
            errorMessage = "devsweep 엔진을 번들에서 찾을 수 없음"; return
        }
        do {
            let out = try await run([path, "--json"] + ageArgs)
            let decoded = try JSONDecoder().decode([CacheCategory].self, from: Data(out.utf8))
            let keepSelected = Set(categories.filter(\.selected).map(\.name))
            let includeHeavy = UserDefaults.standard.bool(forKey: "selectHeavy")
            categories = decoded.map { item in
                var c = item
                c.selected = keepSelected.isEmpty
                    ? ((includeHeavy || !item.heavy) && item.hasSize && !item.protected)
                    : (keepSelected.contains(item.name) && !item.protected)
                return c
            }
            detailCache.removeAll()   // 용량이 갱신됐으니 stale 상세 무효화
        } catch {
            errorMessage = "스캔 실패: \(error.localizedDescription)"
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
            errorMessage = "상세 로드 실패(\(name)): \(error.localizedDescription)"
        }
    }

    /// targets=nil이면 선택된 것 전체, 값 있으면 그 카테고리만 정리하고 재스캔한다.
    func clean(targets: [String]? = nil) async {
        let names = targets ?? categories.filter(\.selected).map(\.name)
        guard !names.isEmpty, !isCleaning else { return }
        isCleaning = true; errorMessage = nil

        guard let path = enginePath else {
            errorMessage = "devsweep 엔진을 찾을 수 없음"; isCleaning = false; return
        }
        // 정리 직전 측정값 = 회수 예상치 (정보성 누적용)
        let freedKB = categories.filter { names.contains($0.name) }.reduce(0) { $0 + $1.sizeKB }
        do {
            lastLog = try await run([path, "clean", "--yes"] + names + ageArgs)
            let prev = UserDefaults.standard.integer(forKey: "totalReclaimedKB")
            UserDefaults.standard.set(prev + freedKB, forKey: "totalReclaimedKB")
        } catch {
            errorMessage = "정리 실패: \(error.localizedDescription)"
        }
        isCleaning = false
        await scan()   // scan()이 detailCache.removeAll() 수행
    }

    /// 카테고리 선택(정리 대상) 토글 — 마스터 행 체크박스용 (정렬과 무관하게 이름으로 갱신).
    func setSelected(_ name: String, _ value: Bool) {
        if let i = categories.firstIndex(where: { $0.name == name }) {
            categories[i].selected = value
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
    private func run(_ args: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/bin/bash")
                proc.arguments = args
                let outPipe = Pipe()
                proc.standardOutput = outPipe
                proc.standardError = Pipe()
                do {
                    try proc.run()
                    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                    proc.waitUntilExit()
                    cont.resume(returning: String(decoding: data, as: UTF8.self))
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }
}

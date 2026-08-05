import Foundation

/// 민감 파일 실시간 감시 — FSEvents 로 경로 변경만 관찰한다(파일 내용은 절대 읽지 않음).
///
/// 설계 요점: 홈 전체를 감시하면 초당 수십 건의 이벤트가 오므로 **3단으로 걸러** 비용을 없앤다.
///   ① 프룬 경로 제외 + 파일명 패턴 매칭 (여기서 대부분 탈락 — 순수 문자열 비교)
///   ② 디바운스 (에디터 저장 한 번에 여러 이벤트가 오므로 묶어서 1회로)
///   ③ 살아남은 경로만 상위(Engine)가 CLI `check-secret` 으로 정밀 판정
final class SecretWatcher {
    /// 걸러진 경로 묶음을 전달 (MainActor 에서 호출됨)
    var onCandidates: (([String]) -> Void)?

    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "com.wyatt.devsweep.watcher")
    private var pending = Set<String>()
    private var flushWork: DispatchWorkItem?

    var isRunning: Bool { stream != nil }

    /// root 아래를 재귀 감시한다. 이미 실행 중이면 먼저 중단하고 새 root 로 다시 건다.
    func start(root: String) {
        stop()
        let path = (root as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: path) else { return }

        var ctx = FSEventStreamContext(version: 0,
                                       info: Unmanaged.passUnretained(self).toOpaque(),
                                       retain: nil, release: nil, copyDescription: nil)
        // FileEvents = 폴더가 아닌 파일 단위 통보, NoDefer = 첫 이벤트를 지연 없이
        let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes
                           | kFSEventStreamCreateFlagFileEvents
                           | kFSEventStreamCreateFlagNoDefer)
        guard let s = FSEventStreamCreate(nil, watcherCallback, &ctx,
                                          [path] as CFArray,
                                          FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                                          0.5, flags) else { return }
        stream = s
        FSEventStreamSetDispatchQueue(s, queue)
        FSEventStreamStart(s)
    }

    func stop() {
        flushWork?.cancel(); flushWork = nil
        queue.sync { pending.removeAll() }
        guard let s = stream else { return }
        FSEventStreamStop(s)
        FSEventStreamInvalidate(s)
        FSEventStreamRelease(s)
        stream = nil
    }

    deinit { stop() }

    /// ① 패턴 필터 → ② 디바운스 적재. 콜백(감시 큐)에서 호출된다.
    fileprivate func ingest(_ paths: [String]) {
        let hits = paths.filter { Self.isCandidate($0) }
        guard !hits.isEmpty else { return }
        pending.formUnion(hits)
        flushWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let batch = Array(self.pending)
            self.pending.removeAll()
            guard !batch.isEmpty else { return }
            DispatchQueue.main.async { self.onCandidates?(batch) }
        }
        flushWork = work
        queue.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    // ── 필터 ──

    /// 스캐너와 동일하게 무시하는 경로 (이벤트 폭발의 주범)
    private static let prunedFragments = [
        "/node_modules/", "/Library/", "/.Trash/", "/.git/", "/vendor/", "/Pods/",
        "/Music/", "/Pictures/", "/Movies/", "/.build/", "/DerivedData/",
    ]
    /// 경로 게이팅이 필요한 흔한 이름 → 이 조각이 경로에 있을 때만 후보
    private static let gatedNames: [String: [String]] = [
        "config":      ["/.kube/"],
        "config.json": ["/.docker/"],
        "hosts.yml":   ["/.config/gh/"],
        "credentials": ["/.aws/", "/gcloud/"],
    ]
    private static let exactNames: Set<String> = [
        "id_rsa", "id_dsa", "id_ecdsa", "id_ed25519",
        ".npmrc", ".pypirc", ".netrc", ".git-credentials", ".pgpass", ".my.cnf",
        "application_default_credentials.json",
        ".envrc", ".terraformrc", "terraform.rc",
    ]
    private static let suffixes = [
        ".pem", ".key", ".p12", ".pfx", ".keystore", ".jks", ".tfstate", ".tfstate.backup",
        ".env", ".tfvars", ".tfvars.json",      // prod.env 접미형 · terraform 변수
    ]
    /// `.env.example` 류는 위험이 아니므로 후보에서 제외 (CLI 와 동일 규칙)
    private static let envExcluded = [".example", ".sample", ".template", ".dist"]

    /// CLI 를 부를 가치가 있는 경로인가 — 느슨하게 통과시키고 정밀 판정은 CLI 에 맡긴다.
    static func isCandidate(_ path: String) -> Bool {
        for frag in prunedFragments where path.contains(frag) { return false }
        let name = (path as NSString).lastPathComponent
        if name == ".env" { return true }
        if name.hasPrefix(".env.") {
            return !envExcluded.contains { name.hasSuffix($0) }
        }
        if exactNames.contains(name) { return true }
        if name.hasPrefix("AuthKey_") && name.hasSuffix(".p8") { return true }
        if name.hasPrefix("service-account") || name.hasPrefix("serviceAccount") {
            return name.hasSuffix(".json")
        }
        if name.contains("firebase-adminsdk") && name.hasSuffix(".json") { return true }
        // *.env.example 류(템플릿)는 위험이 아니므로 suffix 매칭 전에 걸러낸다
        if envExcluded.contains(where: { name.hasSuffix(".env" + $0) }) { return false }
        if let gates = gatedNames[name] { return gates.contains { path.contains($0) } }
        return suffixes.contains { name.hasSuffix($0) }
    }
}

/// FSEvents C 콜백 — info 로 넘긴 SecretWatcher 로 되돌아온다.
private let watcherCallback: FSEventStreamCallback = { _, info, count, pathsPtr, _, _ in
    guard let info, count > 0 else { return }
    let watcher = Unmanaged<SecretWatcher>.fromOpaque(info).takeUnretainedValue()
    guard let paths = unsafeBitCast(pathsPtr, to: NSArray.self) as? [String] else { return }
    watcher.ingest(paths)
}

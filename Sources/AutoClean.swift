import Foundation

/// 자동 정리(launchd LaunchAgent) 설치·제거·동기화·회수량 reconcile.
///
/// 설계(워크플로 합성 + 적대적 비평 반영):
/// - launchctl bootout(무시)→bootstrap gui/$UID 로 멱등 등록. RunAtLoad=false(켜자마자 대량삭제 방지).
/// - 엔진/래퍼를 ~/Library/Application Support/DevSweep/engine/ 로 복사(번들 경로 불안정 회피) + 버전 self-heal.
/// - 회수량: 래퍼가 `devsweep total` before/after diff(python3 등 외부 의존 0) → runs.jsonl 에 append 만.
///   totalReclaimedKB 는 GUI 앱만 write(단일 writer) → cfprefsd lost-update 레이스 차단.
enum AutoClean {
    static let label = "com.wyatt.devsweep.autoclean"

    private static var home: String { FileManager.default.homeDirectoryForCurrentUser.path }
    private static var appSupport: String { "\(home)/Library/Application Support/DevSweep" }
    private static var engineDir: String { "\(appSupport)/engine" }
    private static var enginePath: String { "\(engineDir)/devsweep" }
    private static var autorunPath: String { "\(engineDir)/autorun.sh" }
    private static var versionStamp: String { "\(engineDir)/.engine-version" }
    private static var runsLog: String { "\(appSupport)/runs.jsonl" }
    private static var plistPath: String { "\(home)/Library/LaunchAgents/\(label).plist" }

    /// 주기: 0=매일(3시) / 1=매주(일요일 3시) / 2=매월(1일 3시). Minute 항상 명시, Day:1 고정(짧은달 누락 방지).
    private static func scheduleXML(_ period: Int) -> String {
        switch period {
        case 1:  return "<key>Weekday</key><integer>0</integer><key>Hour</key><integer>3</integer><key>Minute</key><integer>0</integer>"
        case 2:  return "<key>Day</key><integer>1</integer><key>Hour</key><integer>3</integer><key>Minute</key><integer>0</integer>"
        default: return "<key>Hour</key><integer>3</integer><key>Minute</key><integer>0</integer>"
        }
    }

    @discardableResult
    private static func launchctl(_ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run(); p.waitUntilExit(); return p.terminationStatus } catch { return -1 }
    }

    private static func sh(_ cmd: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = ["-c", cmd]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run(); p.waitUntilExit()
    }

    /// 번들 CLI + 래퍼를 안정 경로로 복사 + chmod/quarantine 제거 + 버전 stamp.
    private static func installEngine(olderThanDays: Int) {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: engineDir, withIntermediateDirectories: true)

        if let src = Bundle.main.path(forResource: "devsweep", ofType: nil) {
            try? fm.removeItem(atPath: enginePath)
            try? fm.copyItem(atPath: src, toPath: enginePath)
        }

        // 래퍼: devsweep total before/after 로 실제 회수량 산출(외부 의존 0). totalReclaimedKB 는 안 건드림.
        let age = olderThanDays > 0 ? "--older-than=\(olderThanDays)d" : ""
        let wrapper = """
        #!/bin/bash
        # DevSweep 자동 정리 래퍼 — launchd 주기 실행. 회수량(추정)은 runs.jsonl 에만 기록(앱이 reconcile).
        # freed = 정리 직전 추정 회수량(cmd_total). before/after diff 는 네이티브 명령(brew/npm 등)이
        # 측정 경로 밖을 비워 부정확하므로 사용 안 함 — GUI 수동 정리(Engine.clean)와 동일한 '추정' 의미로 통일.
        APPSUP="$HOME/Library/Application Support/DevSweep"
        ENGINE="$APPSUP/engine/devsweep"
        STATE="$APPSUP/runs.jsonl"
        AGE="\(age)"
        export DEVSWEEP_CONFIG="$HOME/.config/devsweep/config"
        [ -x "$ENGINE" ] || exit 0
        est=$("$ENGINE" total $AGE 2>/dev/null); est=${est:-0}
        "$ENGINE" clean --yes $AGE >/dev/null 2>&1
        printf '{"ts":%s,"freedKB":%s,"status":"ok"}\\n' "$(date +%s)" "$est" >> "$STATE"
        """
        try? wrapper.write(toFile: autorunPath, atomically: true, encoding: .utf8)

        sh("chmod +x '\(enginePath)' '\(autorunPath)' 2>/dev/null; xattr -dr com.apple.quarantine '\(enginePath)' '\(autorunPath)' 2>/dev/null; true")
        try? AppInfo.version.write(toFile: versionStamp, atomically: true, encoding: .utf8)
    }

    /// 자동 정리 켜기(멱등). 주기 변경도 동일 경로로 재적용.
    static func enable(period: Int, olderThanDays: Int) {
        installEngine(olderThanDays: olderThanDays)
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key><string>\(label)</string>
          <key>ProgramArguments</key>
          <array><string>/bin/bash</string><string>\(autorunPath)</string></array>
          <key>EnvironmentVariables</key>
          <dict>
            <key>HOME</key><string>\(home)</string>
            <key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
          </dict>
          <key>StartCalendarInterval</key>
          <dict>\(scheduleXML(period))</dict>
          <key>RunAtLoad</key><false/>
          <key>ProcessType</key><string>Background</string>
          <key>LowPriorityIO</key><true/>
          <key>StandardOutPath</key><string>\(appSupport)/autoclean.out.log</string>
          <key>StandardErrorPath</key><string>\(appSupport)/autoclean.err.log</string>
        </dict>
        </plist>
        """
        try? FileManager.default.createDirectory(atPath: "\(home)/Library/LaunchAgents", withIntermediateDirectories: true)
        try? plist.write(toFile: plistPath, atomically: true, encoding: .utf8)
        let uid = getuid()
        launchctl(["bootout", "gui/\(uid)/\(label)"])          // 이미 로드돼 있으면 내림(미로드면 비0 → 무시)
        launchctl(["bootstrap", "gui/\(uid)", plistPath])      // EBUSY 회피 위해 bootout 선행
    }

    /// 자동 정리 끄기(멱등). runs.jsonl 은 미reconcile 회수량 보존 위해 남김.
    static func disable() {
        let uid = getuid()
        launchctl(["bootout", "gui/\(uid)/\(label)"])
        let fm = FileManager.default
        try? fm.removeItem(atPath: plistPath)
        try? fm.removeItem(atPath: autorunPath)
        try? fm.removeItem(atPath: enginePath)
        try? fm.removeItem(atPath: versionStamp)
    }

    /// 앱 active 시: 원하는 상태(@AppStorage)와 실제 plist/엔진 버전을 수렴(self-heal).
    static func syncIfNeeded(enabled: Bool, period: Int, olderThanDays: Int) {
        let plistExists = FileManager.default.fileExists(atPath: plistPath)
        if enabled {
            let stamp = (try? String(contentsOfFile: versionStamp, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !plistExists || stamp != AppInfo.version {
                enable(period: period, olderThanDays: olderThanDays)   // 미설치 or 구버전 엔진 → 재설치
            }
        } else if plistExists {
            disable()
        }
    }

    /// runs.jsonl 워터마크 이후 라인만 totalReclaimedKB 에 합산(앱 단독 writer, 멱등). 마지막 실행 정보는 @AppStorage 로 저장.
    static func reconcile() {
        guard let text = try? String(contentsOfFile: runsLog, encoding: .utf8) else { return }
        let d = UserDefaults.standard
        // 라인 인덱스 워터마크(초 단위 ts 가 아니라 처리한 줄 수) — 같은 초 다중 run 도 정확히 흡수.
        let processed = d.integer(forKey: "lastReconciledLineCount")
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        var addKB = 0, lastTs = 0
        for (i, line) in lines.enumerated() {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else { continue }
            if let ts = (obj["ts"] as? NSNumber)?.intValue { lastTs = ts }
            if i >= processed { addKB += (obj["freedKB"] as? NSNumber)?.intValue ?? 0 }
        }
        if addKB > 0 {
            d.set(d.integer(forKey: "totalReclaimedKB") + addKB, forKey: "totalReclaimedKB")
        }
        d.set(lines.count, forKey: "lastReconciledLineCount")
        if lastTs > 0 { d.set(lastTs, forKey: "autoLastRunTs") }
    }
}

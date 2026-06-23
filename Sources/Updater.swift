import Foundation
import AppKit
import Observation

/// 자동 업데이트 — 릴리스 `.app.zip` 을 받아 현재 앱을 교체하고 재실행한다 (의존성 0).
///
/// 실행 중인 앱은 자기 번들을 덮어쓸 수 없으므로(프로세스가 깨짐), 앱 종료를 기다렸다가
/// 교체·재실행하는 별도 `/bin/bash` 헬퍼를 띄우고 스스로 종료한다(Sparkle 과 동일 패턴).
/// 헬퍼는 백업→교체→실패 시 롤백 순서라, 어느 단계에서 죽어도 DEST 가 사라지지 않는다.
@MainActor
@Observable
final class Updater {
    enum Phase: Equatable {
        case idle
        case working          // 다운로드 + 압축 해제
        case relaunching      // 헬퍼 실행 → 곧 재시작
        case failed(String)
    }
    var phase: Phase = .idle

    func install(from assetURL: URL) async {
        phase = .working
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("DevSweepUpdate-\(UUID().uuidString)")
        do {
            try fm.createDirectory(at: work, withIntermediateDirectories: true)

            // 1) zip 다운로드
            let (tmp, resp) = try await URLSession.shared.download(from: assetURL)
            if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
                throw UpdaterError.message("다운로드 실패 (HTTP \(http.statusCode))")
            }
            let zip = work.appendingPathComponent("update.zip")
            try fm.moveItem(at: tmp, to: zip)

            // 2) ditto 로 압축 해제 → DevSweep.app 추출 (번들 메타/서명 보존)
            try runTool("/usr/bin/ditto", ["-x", "-k", zip.path, work.path])
            let newApp = work.appendingPathComponent("DevSweep.app")
            guard fm.fileExists(atPath: newApp.path) else {
                throw UpdaterError.message("압축 해제 후 DevSweep.app 을 찾을 수 없음")
            }

            // 3) quarantine 제거 — ad-hoc 서명이라, 떼면 Gatekeeper 검사 없이 바로 열린다
            try? runTool("/usr/bin/xattr", ["-dr", "com.apple.quarantine", newApp.path])

            // 4) 교체·재실행 헬퍼: 앱(PID) 종료 대기 → 백업 → 교체 → (실패 시 롤백) → open
            let dest = Bundle.main.bundleURL
            let pid = ProcessInfo.processInfo.processIdentifier
            let helper = work.appendingPathComponent("install.sh")
            let script = """
            #!/bin/bash
            PID=\(pid)
            NEW=\(shq(newApp.path))
            DEST=\(shq(dest.path))
            WORK=\(shq(work.path))
            # 부모(앱) 종료를 최대 20초 대기
            for _ in $(seq 1 200); do kill -0 "$PID" 2>/dev/null || break; sleep 0.1; done
            sleep 0.4
            BAK="${DEST}.old-$$"
            if /bin/mv "$DEST" "$BAK" 2>/dev/null && /bin/mv "$NEW" "$DEST" 2>/dev/null; then
              /usr/bin/xattr -dr com.apple.quarantine "$DEST" 2>/dev/null
              /bin/rm -rf "$BAK"
            else
              # 교체 실패 → 백업 롤백(DEST 보존)
              [ -e "$BAK" ] && /bin/mv "$BAK" "$DEST" 2>/dev/null
            fi
            /usr/bin/open "$DEST"
            /bin/rm -rf "$WORK"
            """
            try script.write(to: helper, atomically: true, encoding: .utf8)

            // 5) 헬퍼를 분리 실행(앱이 종료돼도 init 이 reparent 하여 살아남음) → 앱 종료
            phase = .relaunching
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/bash")
            p.arguments = [helper.path]
            try p.run()

            try? await Task.sleep(nanoseconds: 500_000_000)
            NSApp.terminate(nil)
        } catch {
            try? fm.removeItem(at: work)
            phase = .failed(error.localizedDescription)
        }
    }

    /// 동기 외부 도구 실행(ditto/xattr). 비0 종료면 throw.
    private func runTool(_ launch: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launch)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            throw UpdaterError.message("\((launch as NSString).lastPathComponent) 실패 (코드 \(p.terminationStatus))")
        }
    }

    /// 셸 안전 인용 — 작은따옴표 래핑(내부 ' 는 '\\'' 로 이스케이프).
    private func shq(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

enum UpdaterError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(m) = self { return m }; return nil }
}

import Foundation
import AppKit
import Observation
import CryptoKit

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

    /// 실패 메시지 표시 언어 — 사용자 선택 언어, 없으면 시스템 추정 (Engine.uiLang 과 동일 규칙).
    private var uiLang: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "language") ?? "") ?? .systemDefault
    }

    func install(from assetURL: URL, sigURL: URL?) async {
        phase = .working
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("DevSweepUpdate-\(UUID().uuidString)")
        do {
            try fm.createDirectory(at: work, withIntermediateDirectories: true)

            // 1) zip 다운로드
            let (tmp, resp) = try await URLSession.shared.download(from: assetURL)
            if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
                throw UpdaterError.message(tr("err.downloadHttpFmt", uiLang, http.statusCode))
            }
            let zip = work.appendingPathComponent("update.zip")
            try fm.moveItem(at: tmp, to: zip)

            // 1b) Ed25519 서명 검증 — 압축 해제/실행 전에 차단하는 실질 신뢰경계.
            //     서명이 없거나 공개키와 불일치하면 여기서 설치를 거부한다.
            try await verifySignature(zip: zip, sigURL: sigURL)

            // 2) ditto 로 압축 해제 → DevSweep.app 추출 (번들 메타/서명 보존)
            try runTool("/usr/bin/ditto", ["-x", "-k", zip.path, work.path])
            let newApp = work.appendingPathComponent("DevSweep.app")
            guard fm.fileExists(atPath: newApp.path) else {
                throw UpdaterError.message(tr("err.extractMissing", uiLang))
            }

            // 3) 최소 검증 — 손상/엉뚱한 앱/다운그레이드 차단(실패 시 throw, 교체 안 함)
            try verify(newApp)

            // 4) quarantine 제거 — ad-hoc 서명이라, 떼면 Gatekeeper 검사 없이 바로 열린다
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
            throw UpdaterError.message(tr("err.toolFmt", uiLang, (launch as NSString).lastPathComponent, Int(p.terminationStatus)))
        }
    }

    /// 릴리스 zip 의 Ed25519 서명을 앱에 박힌 공개키로 검증한다.
    /// 개인키는 repo 밖에만 있으므로, 릴리스 asset 이 바꿔치기돼도 유효 서명을 만들 수 없다.
    /// (ad-hoc codesign 은 누구나 재서명 가능 → 이 검증이 진짜 신뢰 앵커)
    private func verifySignature(zip: URL, sigURL: URL?) async throws {
        guard let sigURL else { throw UpdaterError.message(tr("err.sigMissing", uiLang)) }
        let (sigData, resp) = try await URLSession.shared.data(from: sigURL)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            throw UpdaterError.message(tr("err.sigMissing", uiLang))
        }
        guard let sigText = String(data: sigData, encoding: .utf8),
              let sig = Data(base64Encoded: sigText.trimmingCharacters(in: .whitespacesAndNewlines)),
              let pubData = Data(base64Encoded: AppInfo.updatePublicKeyB64),
              let pub = try? Curve25519.Signing.PublicKey(rawRepresentation: pubData),
              let zipData = try? Data(contentsOf: zip)
        else { throw UpdaterError.message(tr("err.sigInvalid", uiLang)) }
        guard pub.isValidSignature(sig, for: zipData) else {
            throw UpdaterError.message(tr("err.sigInvalid", uiLang))
        }
    }

    /// 받은 앱 최소 검증 — codesign 유효성(손상) + 번들 ID 일치 + 버전 실제 상승.
    /// ad-hoc 서명이라 '서명 주체 고정' 검증은 불가(완전 방어 아님)지만, 손상·엉뚱한 앱·
    /// 다운그레이드를 막아 명백한 사고는 차단한다. (강한 방어는 Developer ID + notarization 필요)
    private func verify(_ app: URL) throws {
        try runTool("/usr/bin/codesign", ["--verify", "--deep", app.path])
        let info = app.appendingPathComponent("Contents/Info.plist")
        guard let d = NSDictionary(contentsOf: info) else {
            throw UpdaterError.message(tr("err.infoPlistUnreadable", uiLang))
        }
        guard d["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier else {
            throw UpdaterError.message(tr("err.bundleMismatch", uiLang))
        }
        let newVer = d["CFBundleShortVersionString"] as? String ?? "0"
        guard UpdateChecker.isNewer(newVer, than: AppInfo.version) else {
            throw UpdaterError.message(tr("err.notNewerFmt", uiLang, newVer))
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

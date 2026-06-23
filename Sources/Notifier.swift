import AppKit
import UserNotifications

/// 정리 완료 로컬 알림.
/// - 1순위: UNUserNotificationCenter (출처/아이콘 = DevSweep). 권한이 authorized 일 때만.
/// - 폴백: ad-hoc 서명 앱은 UN 권한이 안 잡히는 경우가 많아 → osascript 로 확실히 표시
///   (출처 아이콘은 DevSweep 이 아니지만, 안 뜨는 것보다 낫다). 정식 해결은 Developer ID 서명.
enum Notifier {
    static func cleanDone(reclaimedKB: Int) {
        let lang = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "language") ?? "") ?? .systemDefault
        let title = tr("notify.cleanTitle", lang)
        let body = reclaimedKB > 0
            ? tr("notify.cleanBodyFmt", lang, humanKB(reclaimedKB))
            : tr("notify.cleanBodyZero", lang)

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
            default:
                // denied / notDetermined (ad-hoc 서명에서 흔함) → osascript 폴백
                osascriptNotify(title: title, body: body)
            }
        }
    }

    /// osascript `display notification` 폴백. -e 인자는 Process 가 직접 전달(셸 미경유)이라
    /// AppleScript 문자열 이스케이프(역슬래시 먼저 → 따옴표)만 처리하면 된다.
    private static func osascriptNotify(title: String, body: String) {
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        }
        let script = "display notification \"\(esc(body))\" with title \"\(esc(title))\""
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", script]
        try? p.run()
    }
}

/// 알림 권한 1회 요청 + 포그라운드에서도 배너가 뜨도록 delegate 설정.
/// (NSApplicationDelegateAdaptor 로 DevSweepApp 에 연결)
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// 앱이 떠 있을 때도 배너+소리로 표시(기본은 포그라운드면 억제됨).
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

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

    /// 새 버전 발견 알림 (자동 체크에서 호출).
    static func updateAvailable(tag: String) {
        let lang = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "language") ?? "") ?? .systemDefault
        post(title: tr("notify.updateTitle", lang), body: tr("notify.updateBodyFmt", lang, tag))
    }

    /// 알림 1건 발송 — UN 권한 있으면 UN, 아니면 osascript 폴백(공통 경로).
    private static func post(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                let content = UNMutableNotificationContent()
                content.title = title; content.body = body; content.sound = .default
                center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
            default:
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

/// 메뉴바(AppKit)에서 SwiftUI 상태 접근용 브리지. DevSweepApp 이 launch 시 주입(weak → 수명 안 늘림).
enum AppRefs {
    static weak var engine: Engine?
    static weak var appState: AppState?
}

/// 알림 권한 1회 요청 + 포그라운드 배너 + 메뉴바(NSStatusItem) 관리.
/// (NSApplicationDelegateAdaptor 로 DevSweepApp 에 연결)
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private weak var mainWindow: NSWindow?

    private var menuBarOn: Bool { UserDefaults.standard.object(forKey: "menuBarEnabled") as? Bool ?? true }
    private var showSize: Bool { UserDefaults.standard.bool(forKey: "menuBarShowSize") }
    private var dockHidden: Bool { UserDefaults.standard.bool(forKey: "dockHidden") }
    private var uiLang: AppLanguage { AppLanguage(rawValue: UserDefaults.standard.string(forKey: "language") ?? "") ?? .systemDefault }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        applyActivationPolicy()
        rebuildStatusItem()

        // 자동 업데이트 체크 — 실행 시 1회 + 6시간마다 재평가(실제 조회는 24시간 경과 시에만)
        Task { @MainActor in
            while true {
                await UpdateChecker.autoCheckIfDue()
                try? await Task.sleep(nanoseconds: 6 * 3_600 * 1_000_000_000)
            }
        }

        // 메인 창이 처음 뜰 때 isReleasedWhenClosed=false → 닫아도 메모리 유지(메뉴바에서 재표시 가능)
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] note in
            guard let w = note.object as? NSWindow, w.styleMask.contains(.titled), w.frame.width > 600 else { return }
            w.isReleasedWhenClosed = false
            self?.mainWindow = w
        }
        // 설정 토글(메뉴바 on/off·용량표시·독숨김) + 회수량 변화에 반응
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.applyActivationPolicy()
            self?.rebuildStatusItem()
        }
    }

    // 메뉴바 켜져 있으면 창 닫아도 앱 유지(메뉴바로 재접근). 꺼져 있으면 표준 동작.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { !menuBarOn }
    // 독 아이콘 클릭 등 재활성화 시 창 복원 허용.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMainWindow() }
        return true
    }

    private func applyActivationPolicy() {
        NSApp.setActivationPolicy(dockHidden ? .accessory : .regular)
    }

    private func rebuildStatusItem() {
        guard menuBarOn else { statusItem = nil; return }
        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let img = NSImage(systemSymbolName: "wind", accessibilityDescription: "DevSweep") {
                img.isTemplate = true
                item.button?.image = img
            } else {
                item.button?.title = "DevSweep"
            }
            let menu = NSMenu(); menu.delegate = self
            item.menu = menu
            statusItem = item
        }
        updateStatusTitle()
    }

    private func updateStatusTitle() {
        guard let btn = statusItem?.button else { return }
        if showSize {
            let kb = UserDefaults.standard.integer(forKey: "reclaimableKB")
            btn.title = kb > 0 ? " " + humanKB(kb) : ""
            btn.imagePosition = .imageLeading
        } else {
            btn.title = ""
        }
    }

    // 메뉴는 열릴 때마다 최신 회수량으로 재구성.
    func menuNeedsUpdate(_ menu: NSMenu) {
        updateStatusTitle()
        menu.removeAllItems()
        let kb = UserDefaults.standard.integer(forKey: "reclaimableKB")
        let info = NSMenuItem(title: "\(tr("menubar.reclaimable", uiLang)): \(humanKB(kb))", action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)
        menu.addItem(.separator())
        addItem(menu, tr("menubar.cleanSafe", uiLang), #selector(menuClean))
        addItem(menu, tr("menubar.rescan", uiLang), #selector(menuScan))
        menu.addItem(.separator())
        addItem(menu, tr("menubar.open", uiLang), #selector(menuOpen), key: "o")
        addItem(menu, tr("menubar.quit", uiLang), #selector(menuQuit), key: "q")
    }

    private func addItem(_ menu: NSMenu, _ title: String, _ sel: Selector, key: String = "") {
        let it = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        it.target = self
        menu.addItem(it)
    }

    @objc private func menuScan() { Task { @MainActor in await AppRefs.engine?.scan() } }
    @objc private func menuClean() { showMainWindow(); AppRefs.appState?.requestCleanRecommended = true }
    @objc private func menuOpen() { showMainWindow() }
    @objc private func menuQuit() { NSApp.terminate(nil) }

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        let win = mainWindow ?? NSApp.windows.first { $0.styleMask.contains(.titled) && $0.frame.width > 600 }
        win?.isReleasedWhenClosed = false
        win?.makeKeyAndOrderFront(nil)
    }

    /// 앱이 떠 있을 때도 배너+소리로 표시(기본은 포그라운드면 억제됨).
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

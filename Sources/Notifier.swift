import AppKit
import SwiftUI                 // EnvironmentValues().openWindow — 파괴된 메인 창 재생성용
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
    /// 실시간 감시 — 위험한 민감 파일이 새로 생겼을 때. 문구는 호출부(Engine)가 현지화해 넘긴다.
    static func secretDetected(title: String, body: String) {
        post(title: title, body: body)
    }

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
            guard let self, let w = note.object as? NSWindow, self.isMainAppWindow(w) else { return }
            w.isReleasedWhenClosed = false
            self.mainWindow = w
            self.applyActivationPolicy()   // 창이 떠 있으면 dock 숨김이어도 .regular (메뉴 바 소유)
        }
        // 🔴 로그인 자동실행 커버: 백그라운드로 시작하면 창이 key 가 된 적이 없어 위 훅이 안 걸린다.
        //    잠시 후 창을 직접 찾아 같은 처리를 해두지 않으면, 창을 닫는 순간 SwiftUI 가 파괴해
        //    메뉴바 '창 열기'가 되살릴 대상을 잃는다(무반응 버그의 원인).
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, self.mainWindow == nil else { return }
            if let w = NSApp.windows.first(where: { self.isMainAppWindow($0) }) {
                w.isReleasedWhenClosed = false
                self.mainWindow = w
            }
            self.applyActivationPolicy()
        }
        // 창이 닫힐 때: 남은 창이 없으면 dock 숨김 설정을 실제로 적용(.accessory 복귀).
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.async { self?.applyActivationPolicy() }   // 닫힘 반영 후 재평가
        }
        // 설정 토글(메뉴바 on/off·용량표시·독숨김) + 회수량 변화에 반응
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.applyActivationPolicy()
            self?.rebuildStatusItem()
        }
    }

    /// 메인 앱 창 판별 — identifier 기반(설정 창 제외). WindowGroup id="main" 이라 identifier 에 "main" 이 들어간다.
    private func isMainAppWindow(_ w: NSWindow) -> Bool {
        guard w.styleMask.contains(.titled) else { return false }
        let ident = w.identifier?.rawValue ?? ""
        if ident.contains("settings") { return false }   // 설정 창(680pt)이 폭 필터에 걸리던 오인 방지
        return ident.contains("main") || w.frame.width > 600
    }

    // 메뉴바 켜져 있으면 창 닫아도 앱 유지(메뉴바로 재접근). 꺼져 있으면 표준 동작.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { !menuBarOn }
    // 독 아이콘 클릭 등 재활성화 시 창 복원 허용.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMainWindow() }
        return true
    }

    /// 동적 정책 전환 — macOS 는 메뉴 바를 가지려면 .regular(=dock 표시)여야 해서 둘을 동시에 못 가진다.
    /// 그래서 dock 숨김 모드에서도 '창이 떠 있는 동안'은 .regular(메뉴 바 = DevSweep, dock 잠깐 표시),
    /// 창을 다 닫으면 .accessory(트레이만)로 복귀한다. (Bartender·Ice 등 메뉴바 앱 표준 패턴)
    private func applyActivationPolicy() {
        let hasVisibleWindow = NSApp.windows.contains { $0.isVisible && $0.styleMask.contains(.titled) }
        NSApp.setActivationPolicy(dockHidden && !hasVisibleWindow ? .accessory : .regular)
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
        NSApp.setActivationPolicy(.regular)   // accessory 상태에선 활성화가 불완전 — 창 띄우기 전에 전환
        if let win = mainWindow ?? NSApp.windows.first(where: { isMainAppWindow($0) }) {
            win.isReleasedWhenClosed = false
            win.makeKeyAndOrderFront(nil)
        } else {
            // 보관된 창이 없음(로그인 백그라운드 시작 후 닫혀 파괴된 경우) — SwiftUI 로 새 창 생성
            EnvironmentValues().openWindow(id: "main")
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 앱이 떠 있을 때도 배너+소리로 표시(기본은 포그라운드면 억제됨).
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

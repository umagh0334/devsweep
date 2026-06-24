import SwiftUI
import AppKit
import Observation

@main
struct DevSweepApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate   // 알림 권한·포그라운드 배너
    /// 메인 창과 환경설정 창이 같은 Engine 을 공유 (보호 토글 → 메인 즉시 반영)
    @State private var engine = Engine()
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance") private var appearance = 0   // 0=시스템 1=라이트 2=다크
    @AppStorage("language") private var languageRaw = ""   // 빈값이면 시스템 언어 추정
    @AppStorage("autoClean") private var autoClean = false
    @AppStorage("autoCleanPeriod") private var autoCleanPeriod = 0   // 0=매일 1=매주 2=매월
    @AppStorage("autoCleanHour") private var autoCleanHour = 3       // 실행 시(0~23), 기본 새벽 3시
    @AppStorage("autoCleanMinute") private var autoCleanMinute = 0   // 실행 분(0~59)
    @AppStorage("autoCleanWeekday") private var autoCleanWeekday = 0 // 매주: 0=일~6=토
    @AppStorage("autoCleanDay") private var autoCleanDay = 1         // 매월: 1~28일
    @AppStorage("olderThanDays") private var olderThanDays = 0

    /// 외관을 NSApp.appearance 로 직접 적용. SwiftUI .preferredColorScheme(nil) 은 다크→시스템
    /// 전환 시 윈도우 appearance 가 리셋되지 않아 라이트/다크가 섞이는 버그가 있어 AppKit 으로 명시 제어.
    private func applyAppearance() {
        switch appearance {
        case 1: NSApp.appearance = NSAppearance(named: .aqua)
        case 2: NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil   // 시스템 따름 (잔상 없이 리셋)
        }
    }
    private var lang: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .systemDefault }

    var body: some Scene {
        WindowGroup("DevSweep") {
            ContentView(engine: engine)
                .environment(\.appLanguage, lang)
                .environment(appState)
                .onChange(of: appearance) { _, _ in applyAppearance() }
                .task {
                    // 콜드 런치 시 1회(.onChange 는 초기값엔 미발동) — 외관 적용 + 자동 정리 합산 + self-heal
                    applyAppearance()
                    AutoClean.reconcile()
                    AutoClean.syncIfNeeded(enabled: autoClean, period: autoCleanPeriod, hour: autoCleanHour, minute: autoCleanMinute, weekday: autoCleanWeekday, day: autoCleanDay, olderThanDays: olderThanDays)
                }
                .onChange(of: scenePhase) { _, phase in
                    // 다시 포그라운드 진입 시 재합산(단일 writer)
                    guard phase == .active else { return }
                    AutoClean.reconcile()
                    AutoClean.syncIfNeeded(enabled: autoClean, period: autoCleanPeriod, hour: autoCleanHour, minute: autoCleanMinute, weekday: autoCleanWeekday, day: autoCleanDay, olderThanDays: olderThanDays)
                }
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commands {
            // "DevSweep 에 관하여" 아래에 "업데이트 확인…" — macOS 표준 위치
            CommandGroup(after: .appInfo) { UpdateMenuButton(appState: appState) }
            // Settings scene 을 안 쓰므로 Cmd+, 를 직접 배선 (별도 창 열기)
            CommandGroup(replacing: .appSettings) { OpenSettingsButton() }
        }

        // 별도 설정 창 — 화면 중앙에 띄움(우측 갑툭튀 방지), 시스템설정 스타일
        Window(tr("window.settings", .systemDefault), id: "settings") {
            SettingsView(engine: engine)
                .environment(\.appLanguage, lang)
                .environment(appState)
        }
        .defaultPosition(.center)
        .windowResizability(.contentSize)
    }
}

/// Cmd+, 메뉴 항목 — 별도 설정 창을 연다 (Settings scene 대체).
private struct OpenSettingsButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button(tr("menu.settings", .systemDefault)) { openWindow(id: "settings") }
            .keyboardShortcut(",", modifiers: .command)
    }
}

/// 윈도우 간 공유 상태 — 메뉴(별도 Scene)가 설정창 동작을 트리거하기 위함.
@Observable final class AppState {
    /// 메뉴 "업데이트 확인…" 이 켜면, 설정창이 정보 탭으로 전환하고 자동 체크한다.
    var requestUpdateCheck = false
}

/// 앱 메뉴(About 아래) "업데이트 확인…" — 설정창 정보 탭을 열고 자동 체크를 건다.
private struct UpdateMenuButton: View {
    let appState: AppState
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button(tr("menu.checkUpdate", .systemDefault)) {
            appState.requestUpdateCheck = true
            openWindow(id: "settings")
        }
    }
}

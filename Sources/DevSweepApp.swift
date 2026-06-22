import SwiftUI

@main
struct DevSweepApp: App {
    /// 메인 창과 환경설정 창이 같은 Engine 을 공유 (보호 토글 → 메인 즉시 반영)
    @State private var engine = Engine()
    @AppStorage("appearance") private var appearance = 0   // 0=시스템 1=라이트 2=다크
    @AppStorage("language") private var languageRaw = ""   // 빈값이면 시스템 언어 추정

    private var scheme: ColorScheme? {
        switch appearance { case 1: return .light; case 2: return .dark; default: return nil }
    }
    private var lang: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .systemDefault }

    var body: some Scene {
        WindowGroup("DevSweep") {
            ContentView(engine: engine)
                .preferredColorScheme(scheme)
                .environment(\.appLanguage, lang)
        }
        .windowResizability(.contentSize)
        .commands {
            // Settings scene 을 안 쓰므로 Cmd+, 를 직접 배선 (별도 창 열기)
            CommandGroup(replacing: .appSettings) { OpenSettingsButton() }
        }

        // 별도 설정 창 — 화면 중앙에 띄움(우측 갑툭튀 방지), 시스템설정 스타일
        Window("DevSweep 설정", id: "settings") {
            SettingsView(engine: engine)
                .preferredColorScheme(scheme)
                .environment(\.appLanguage, lang)
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

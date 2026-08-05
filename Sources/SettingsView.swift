import SwiftUI
import AppKit
import ServiceManagement

/// 환경설정 — macOS 시스템설정 스타일. 좌측 섹션 사이드바 + 우측 Form(레이블 좌 / 컨트롤 우).
/// "Sweep Console" 토큰(Theme) + 다국어(tr) 적용.
struct SettingsView: View {
    let engine: Engine
    @State private var section: SettingsSection = .general
    @Environment(\.appLanguage) private var lang
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 680, height: 480)
        .tint(Theme.sweep)
        .onAppear {
            // 설정창도 매번 화면 중앙 (메인과 동일 — 복원 위치를 덮어씀). title 로 설정창만 골라냄.
            DispatchQueue.main.async {
                NSApp.windows.first(where: { $0.title == tr("window.settings", .systemDefault) })?.center()
            }
            if appState.requestUpdateCheck { section = .about }   // 메뉴로 열렸으면 정보 탭
            if appState.requestProfileTab { section = .developer; appState.requestProfileTab = false }
        }
        .onChange(of: appState.requestUpdateCheck) { _, req in
            if req { section = .about }   // 이미 열려 있던 설정창도 정보 탭으로 전환
        }
        .onChange(of: appState.requestProfileTab) { _, req in
            // 홈 프로필 칩 → '내 프로필' 탭 (이미 열려 있던 설정창도 전환)
            if req { section = .developer; appState.requestProfileTab = false }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsSection.allCases) { sec in
                Button { section = sec } label: {
                    HStack(spacing: 10) {
                        Icons.view(sec.icon, size: 16).frame(width: 20)
                            .foregroundStyle(section == sec ? AnyShapeStyle(Theme.sweep) : AnyShapeStyle(.secondary))
                        Text(tr(sec.titleKey, lang)).font(.system(.body, design: .rounded))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.vertical, 7).padding(.horizontal, 10)
                    .background(section == sec ? Theme.sweep.opacity(0.15) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(8)
        .frame(width: 190)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var detail: some View {
        switch section {
        case .general:   GeneralSettings(engine: engine)
        case .protect:   ProtectSettings(engine: engine)
        case .advanced:  AdvancedSettings(engine: engine)
        case .developer: DeveloperSettings(engine: engine)
        case .about:     AboutSettings()
        }
    }
}

/// 좌측 사이드바 섹션 (Solar 아이콘).
enum SettingsSection: String, CaseIterable, Identifiable {
    case general, developer, protect, advanced, about    // 사이드바 표시 순서 = 선언 순서
    var id: String { rawValue }
    var titleKey: String {
        switch self {
        case .general:   return "set.general"
        case .developer: return "set.profile"            // "내 프로필" (캐시로 본 개발 성향·배지)
        case .protect:   return "set.protect"
        case .advanced:  return "set.advanced"
        case .about:     return "set.about"
        }
    }
    var icon: String {
        switch self {
        case .general:   return "settings"
        case .protect:   return "shield"
        case .advanced:  return "tuning"
        case .developer: return "user"
        case .about:     return "info"
        }
    }
}

/// 일반 — 언어 · 외관 · 스캔 동작. Form(레이블 좌 / 컨트롤 우).
struct GeneralSettings: View {
    let engine: Engine
    @Environment(\.appLanguage) private var lang
    @AppStorage("language") private var languageRaw = ""
    @AppStorage("appearance") private var appearance = 0
    @AppStorage("autoScan") private var autoScan = true
    @AppStorage("selectHeavy") private var selectHeavy = false
    @AppStorage("notifyOnClean") private var notifyOnClean = true
    @AppStorage("menuBarEnabled") private var menuBarEnabled = true
    @AppStorage("menuBarShowSize") private var menuBarShowSize = false
    @AppStorage("dockHidden") private var dockHidden = false
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("autoUpdateCheck") private var autoUpdateCheck = true
    @AppStorage("displayName") private var displayName = ""   // 홈 인사말 이름(빈값=시스템 이름)
    @AppStorage("watchSecrets") private var watchSecrets = false   // 민감 파일 실시간 감시
    @State private var fdaGranted = false   // 전체 디스크 접근 상태 (시스템 설정에서만 변경 가능)

    var body: some View {
        Form {
            Section {
                // 홈 인사말 표시 이름 — 비우면 macOS 계정 이름(NSFullUserName) 사용
                LabeledContent {
                    TextField("", text: $displayName, prompt: Text(NSFullUserName()))
                        .textFieldStyle(.roundedBorder).frame(width: 180)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Text(tr("general.displayName", lang))
                    Text(tr("general.displayNameDesc", lang))
                }
                LabeledContent(tr("general.language", lang)) {
                    Picker("", selection: $languageRaw) {
                        Text(tr("general.system", lang)).tag("")
                        Divider()
                        ForEach(AppLanguage.allCases) { l in Text(l.displayName).tag(l.rawValue) }
                    }
                    .labelsHidden().fixedSize()
                }
                LabeledContent(tr("general.appearance", lang)) {
                    Picker("", selection: $appearance) {
                        Text(tr("general.system", lang)).tag(0)
                        Text(tr("general.light", lang)).tag(1)
                        Text(tr("general.dark", lang)).tag(2)
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                }
            }
            Section {
                Toggle(isOn: $autoScan) {
                    Text(tr("general.autoScan", lang))
                    Text(tr("general.autoScanDesc", lang))
                }
                Toggle(isOn: $selectHeavy) {
                    Text(tr("general.selectHeavy", lang))
                    Text(tr("general.selectHeavyDesc", lang))
                }
                .onChange(of: selectHeavy) { _, _ in Task { await engine.scan() } }
                Toggle(isOn: $notifyOnClean) {
                    Text(tr("general.notify", lang))
                    Text(tr("general.notifyDesc", lang))
                }
                // 실시간 감시 — 백그라운드에서 도는 기능이라 기본 꺼짐(사용자가 의식적으로 켠다)
                Toggle(isOn: $watchSecrets) {
                    Text(tr("general.watch", lang))
                    Text(tr("general.watchDesc", lang))
                }
                .onChange(of: watchSecrets) { _, on in
                    if on { engine.startWatching(root: engine.secretScanRoot) }
                    else { engine.stopWatching() }
                }
            }
            Section(tr("general.menuBarSection", lang)) {
                Toggle(isOn: $menuBarEnabled) {
                    Text(tr("general.menuBar", lang))
                    Text(tr("general.menuBarDesc", lang))
                }
                Toggle(isOn: $menuBarShowSize) { Text(tr("general.menuBarSize", lang)) }
                    .disabled(!menuBarEnabled)
                Toggle(isOn: $dockHidden) {
                    Text(tr("general.dockHide", lang))
                    Text(tr("general.dockHideDesc", lang))
                }
                .disabled(!menuBarEnabled)
                // 로그인 항목 등록 — 실패하면(미서명 앱 등) 토글을 원래대로 되돌린다.
                Toggle(isOn: $launchAtLogin) {
                    Text(tr("general.launchAtLogin", lang))
                    Text(tr("general.launchAtLoginDesc", lang))
                }
                .onChange(of: launchAtLogin) { _, on in
                    do {
                        if on { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                    } catch {
                        launchAtLogin = !on
                    }
                }
            }
            Section {
                Toggle(isOn: $autoUpdateCheck) {
                    Text(tr("general.autoUpdate", lang))
                    Text(tr("general.autoUpdateDesc", lang))
                }
            }
            // 전체 디스크 접근(FDA) — 앱이 코드로 요청할 수 없고 사용자가 시스템 설정에서 켜야 한다.
            // 켜면 보호 폴더(데스크탑·문서·다운로드) 포함 모든 스캔에서 macOS 확인창이 사라진다.
            Section {
                LabeledContent {
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: fdaGranted ? "checkmark.circle.fill" : "circle.slash")
                                .foregroundStyle(fdaGranted ? .green : .secondary)
                            Text(tr(fdaGranted ? "general.fdaOn" : "general.fdaOff", lang))
                                .foregroundStyle(fdaGranted ? .primary : .secondary)
                        }
                        if !fdaGranted {
                            Button(tr("general.fdaOpen", lang)) {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .controlSize(.small)
                        }
                    }
                } label: {
                    Text(tr("general.fda", lang))
                    Text(tr("general.fdaDesc", lang))
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { fdaGranted = Self.checkFDA() }
        // 시스템 설정에서 돌아오면(앱 재활성화) 상태 재확인 — FDA 는 알림이 없어 폴링이 유일한 방법
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            fdaGranted = Self.checkFDA()
        }
    }

    /// FDA 여부 판별 — FDA 없이는 절대 못 여는 TCC DB 를 열어본다(실패해도 팝업 없음, EPERM 만).
    private static func checkFDA() -> Bool {
        let p = NSString(string: "~/Library/Application Support/com.apple.TCC/TCC.db").expandingTildeInPath
        guard let h = FileHandle(forReadingAtPath: p) else { return false }
        try? h.close()
        return true
    }
}

/// 나이 필터 — 선택 기간보다 오래된 파일만 정리. 변경 시 재스캔(용량 갱신).
/// 고급 설정 — 나이 필터 + 자동 정리(준비 중)를 한 화면에 묶음.
struct AdvancedSettings: View {
    let engine: Engine
    @Environment(\.appLanguage) private var lang
    @AppStorage("olderThanDays") private var olderThanDays = 0
    @AppStorage("badgePeriodDays") private var badgePeriodDays = 30
    @AppStorage("autoClean") private var autoClean = false
    @AppStorage("autoCleanPeriod") private var autoCleanPeriod = 0      // 0=매일 1=매주 2=매월
    @AppStorage("autoCleanHour") private var autoCleanHour = 3          // 실행 시(0~23)
    @AppStorage("autoCleanMinute") private var autoCleanMinute = 0      // 실행 분(0~59)
    @AppStorage("autoCleanWeekday") private var autoCleanWeekday = 0    // 매주: 0=일~6=토
    @AppStorage("autoCleanDay") private var autoCleanDay = 1            // 매월: 1~28일
    @AppStorage("autoLastRunTs") private var autoLastRunTs = 0

    private var lastRunText: String {
        guard autoLastRunTs > 0 else { return tr("auto.never", lang) }
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: Date(timeIntervalSince1970: TimeInterval(autoLastRunTs)))
    }
    private var autoFooter: String {
        var s = tr("auto.toggleDesc", lang)
        // headless 권한 한계는 신뢰성 있게 감지하기 어려워(정상 0회수와 구분 불가) 켜졌을 때 상시 안내
        if autoClean { s += "\n\n" + tr("auto.fda", lang) }
        return s
    }

    /// 자동 정리 재적용 — launchctl·파일복사라 백그라운드(메인스레드 블로킹 방지). 켜져 있을 때만.
    private func reapplySchedule() {
        guard autoClean else { return }
        let p = autoCleanPeriod, h = autoCleanHour, m = autoCleanMinute, w = autoCleanWeekday, dd = autoCleanDay, o = olderThanDays
        DispatchQueue.global(qos: .utility).async {
            AutoClean.enable(period: p, hour: h, minute: m, weekday: w, day: dd, olderThanDays: o)
        }
    }

    /// 실행 시각 Int(시·분) ↔ DatePicker용 Date 양방향 매핑. set 시 즉시 재적용.
    private var runTime: Binding<Date> {
        Binding(
            get: {
                var c = DateComponents(); c.hour = autoCleanHour; c.minute = autoCleanMinute
                return Calendar.current.date(from: c) ?? Date()
            },
            set: { newValue in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                autoCleanHour = c.hour ?? 3
                autoCleanMinute = c.minute ?? 0
                reapplySchedule()
            }
        )
    }

    /// 요일 인덱스(0=일~6=토) → 앱 언어 기준 요일명. Calendar+Locale 로 OS 현지화(요일 i18n 불필요).
    private func weekdaySymbol(_ wd: Int) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: lang.rawValue)
        let syms = cal.standaloneWeekdaySymbols          // index 0 = Sunday → launchd Weekday 와 일치
        return (wd >= 0 && wd < syms.count) ? syms[wd] : "\(wd)"
    }

    var body: some View {
        Form {
            // 나이 필터
            Section {
                LabeledContent(tr("age.label", lang)) {
                    Picker("", selection: $olderThanDays) {
                        Text(tr("age.off", lang)).tag(0)
                        Text(tr("age.daysFmt", lang, 7)).tag(7)
                        Text(tr("age.daysFmt", lang, 30)).tag(30)
                        Text(tr("age.daysFmt", lang, 90)).tag(90)
                        Text(tr("age.daysFmt", lang, 180)).tag(180)
                    }
                    .labelsHidden().fixedSize()
                    .onChange(of: olderThanDays) { _, _ in Task { await engine.scan() } }
                }
            } header: {
                Text(tr("set.age", lang))
            } footer: {
                Text(tr("age.note", lang)).fixedSize(horizontal: false, vertical: true)
            }
            // 자동 정리 (launchd 주기 실행)
            Section {
                Toggle(isOn: $autoClean) { Text(tr("auto.toggle", lang)) }
                    .onChange(of: autoClean) { _, on in
                        if on { reapplySchedule() }                                 // 켜짐 → 현재 스케줄로 등록
                        else { DispatchQueue.global(qos: .utility).async { AutoClean.disable() } }
                    }
                    .onChange(of: olderThanDays) { _, _ in reapplySchedule() }
                if autoClean {
                    LabeledContent(tr("auto.period", lang)) {
                        Picker("", selection: $autoCleanPeriod) {
                            Text(tr("auto.daily", lang)).tag(0)
                            Text(tr("auto.weekly", lang)).tag(1)
                            Text(tr("auto.monthly", lang)).tag(2)
                        }
                        .labelsHidden().fixedSize()
                        .onChange(of: autoCleanPeriod) { _, _ in reapplySchedule() }
                    }
                    LabeledContent(tr("auto.time", lang)) {
                        DatePicker("", selection: runTime, displayedComponents: .hourAndMinute)
                            .labelsHidden().fixedSize()
                    }
                    if autoCleanPeriod == 1 {                                        // 매주 → 요일
                        LabeledContent(tr("auto.weekday", lang)) {
                            Picker("", selection: $autoCleanWeekday) {
                                ForEach(0..<7, id: \.self) { wd in Text(weekdaySymbol(wd)).tag(wd) }
                            }
                            .labelsHidden().fixedSize()
                            .onChange(of: autoCleanWeekday) { _, _ in reapplySchedule() }
                        }
                    } else if autoCleanPeriod == 2 {                                 // 매월 → 날짜(1~28)
                        LabeledContent(tr("auto.monthday", lang)) {
                            Picker("", selection: $autoCleanDay) {
                                ForEach(1...28, id: \.self) { d in Text(tr("auto.dayFmt", lang, d)).tag(d) }
                            }
                            .labelsHidden().fixedSize()
                            .onChange(of: autoCleanDay) { _, _ in reapplySchedule() }
                        }
                    }
                    LabeledContent(tr("auto.lastRun", lang)) {
                        Text(lastRunText).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(tr("set.schedule", lang))
            } footer: {
                Text(autoFooter).fixedSize(horizontal: false, vertical: true)
            }
            // 배지 유지 기간 (개발자 탭 시즌제 배지)
            Section {
                LabeledContent(tr("badge.keep", lang)) {
                    Picker("", selection: $badgePeriodDays) {
                        Text(tr("badge.monthsFmt", lang, 1)).tag(30)
                        Text(tr("badge.monthsFmt", lang, 3)).tag(90)
                        Text(tr("badge.monthsFmt", lang, 6)).tag(180)
                    }
                    .labelsHidden().fixedSize()
                }
            } header: {
                Text(tr("dev.badges", lang))
            } footer: {
                Text(tr("badge.keepDesc", lang)).fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }
}

/// 보호 목록 — 카테고리별 보호 토글. Form(레이블=아이콘·이름 좌 / 토글 우).
struct ProtectSettings: View {
    let engine: Engine
    @Environment(\.appLanguage) private var lang
    private var protectedCount: Int { engine.categories.filter(\.protected).count }

    var body: some View {
        Form {
            Section {
                Text(tr("protect.sub", lang))
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section(tr("protect.countFmt", lang, protectedCount)) {
                ForEach(engine.categories) { cat in
                    LabeledContent {
                        Toggle("", isOn: Binding(
                            get: { cat.protected },
                            set: { on in Task { await engine.toggleProtect(cat.name, on) } }
                        ))
                        .labelsHidden().toggleStyle(.switch)
                        .help(cat.protected ? tr("protect.off", lang) : tr("protect.on", lang))
                    } label: {
                        rowLabel(cat)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .task { if engine.categories.isEmpty { await engine.scan() } }
    }

    private func rowLabel(_ cat: CacheCategory) -> some View {
        let tone = cat.heavy ? Theme.heavy : Theme.sweep
        return HStack(spacing: 10) {
            Icons.view(cat.iconName, size: 16)
                .foregroundStyle(cat.protected ? AnyShapeStyle(Theme.guardTone) : AnyShapeStyle(tone))
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 7).fill(tone.opacity(cat.protected ? 0.06 : 0.12)))
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(cat.name).font(.system(.body, design: .rounded))
                    if cat.heavy { HeavyBadge() }
                }
                Text(tr(kindKey(cat.kind), lang)).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// 개발자 — 캐시 분포로 추정한 개발 성향 (재미).
struct DeveloperSettings: View {
    let engine: Engine
    @Environment(\.appLanguage) private var lang
    @AppStorage("totalReclaimedKB") private var totalReclaimedKB = 0
    @AppStorage("badgeEarned") private var badgeEarnedJSON = "{}"        // {배지키: 획득 epoch초}
    @AppStorage("badgePeriodDays") private var badgePeriodDays = 30      // 시즌 유지 기간 (기본 1달)
    @State private var showGallery = false
    @State private var showBadgeGallery = false
    @State private var shownKeys: [String] = []
    @State private var hoverBadge: String? = nil       // 호버 중인 획득 배지 키 (툴팁 팝오버)

    var body: some View {
        let slices = DevProfile.breakdown(engine.categories)
        return Form {
            Section { profileCard }
            if !slices.isEmpty {
                Section { breakdownView(slices) } header: { Text(tr("dev.breakdown", lang)) }
            }
            if !shownKeys.isEmpty {
                Section { badgesView(shownKeys) } header: { badgeHeader }
            }
        }
        .formStyle(.grouped)
        .task {
            if engine.categories.isEmpty { await engine.scan() }
            refreshBadges()
        }
    }

    /// 배지 섹션 헤더 — "획득 배지 (n/총)" + 우측 […]로 전체 배지 목록. 유지 기간은 고급 설정에.
    private var badgeHeader: some View {
        HStack(spacing: 6) {
            Text(tr("dev.badges", lang))
            Text("(\(shownKeys.count)/\(DevProfile.allBadges.count))")
                .foregroundStyle(.secondary).monospacedDigit()
            Spacer()
            Button { showBadgeGallery = true } label: {
                Image(systemName: "ellipsis.circle").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(tr("dev.allBadges", lang))
            .popover(isPresented: $showBadgeGallery, arrowEdge: .top) { badgeGalleryPopover }
        }
    }

    /// 전체 배지 목록 — 획득은 컬러+체크, 미획득은 흐림+자물쇠 (보기 전용).
    /// Grid 3열[이모지·이름·상태] — 이름 열이 가장 긴 배지명에 맞춰지고 상태는 우측 열에 정렬.
    /// 폭은 열 합(내용)에 맞춰 자동(fixedSize), 상태(✓/🔒)는 우측.
    private var badgeGalleryPopover: some View {
        ScrollView {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 11) {
                ForEach(DevProfile.allBadges, id: \.key) { b in
                    let earned = shownKeys.contains(b.key)
                    let color = rarityColor(b.rarity)
                    GridRow {
                        Text(b.emoji).font(.body)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(color.opacity(earned ? 0.14 : 0.06)))
                            .overlay(Circle().strokeBorder(color.opacity(earned ? 0.55 : 0.28), lineWidth: 1.2))
                            .opacity(earned ? 1 : 0.5)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(tr("badge.\(b.key)", lang)).font(.callout)
                                .foregroundStyle(earned ? .primary : .secondary)
                            Text(tr("rarity.\(b.rarity.rawValue)", lang)).font(.caption2)
                                .foregroundStyle(color.opacity(earned ? 0.9 : 0.6))
                        }
                        Group {
                            if earned { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.sweep) }
                            else { Image(systemName: "lock.fill").foregroundStyle(.tertiary) }
                        }
                        .font(.caption)
                        .gridColumnAlignment(.trailing)
                    }
                }
            }
            .padding(16)
        }
        .frame(maxHeight: 360)
        .fixedSize(horizontal: true, vertical: false)
    }

    /// 시즌제 배지 갱신: 만료 제거 + 신규 획득 저장 후 표시 키 산출 (개발자 탭 진입·기간 변경 시)
    private func refreshBadges() {
        let now = Date().timeIntervalSince1970
        var earned = Self.decodeBadges(badgeEarnedJSON)
        earned = DevProfile.refreshEarned(earned, cats: engine.categories, reclaimedKB: totalReclaimedKB,
                                          now: now, periodDays: badgePeriodDays)
        badgeEarnedJSON = Self.encodeBadges(earned)
        shownKeys = DevProfile.activeKeys(earned, now: now, periodDays: badgePeriodDays)
    }

    private static func decodeBadges(_ s: String) -> [String: Double] {
        guard let d = s.data(using: .utf8),
              let m = try? JSONDecoder().decode([String: Double].self, from: d) else { return [:] }
        return m
    }
    private static func encodeBadges(_ m: [String: Double]) -> String {
        guard let d = try? JSONEncoder().encode(m), let s = String(data: d, encoding: .utf8) else { return "{}" }
        return s
    }

    /// 캐시 분포로 추정한 개발 성향 카드 (+ 다른 타입 둘러보기 리스트)
    private var profileCard: some View {
        let p = DevProfile.analyze(engine.categories, lang: lang)
        return HStack(alignment: .top, spacing: 11) {
            Text(p.emoji).font(.system(size: 32))
            VStack(alignment: .leading, spacing: 3) {
                Text(p.title).font(.system(.title3, design: .rounded).weight(.bold))
                Text(p.summary).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button { showGallery = true } label: {
                Image(systemName: "ellipsis.circle.fill").font(.title2).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(tr("dev.gallery", lang))
            .popover(isPresented: $showGallery, arrowEdge: .top) { galleryPopover }
        }
        .padding(.vertical, 4)
    }

    /// 모든 페르소나를 둘러보는 리스트 팝오버 (보기 전용, 별명만 — 설명은 해금)
    /// 가로 폭은 가장 긴 별명에 맞춰 자동(fixedSize), 세로만 최대 높이 제한 후 스크롤
    private var galleryPopover: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(DevProfile.galleryKeys, id: \.self) { key in
                    let g = DevProfile.galleryItem(key, lang: lang)
                    HStack(spacing: 10) {
                        Text(g.emoji).font(.title3)
                        Text(g.title).font(.callout).fontWeight(.medium)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 360)
        .fixedSize(horizontal: true, vertical: false)
    }

    /// 생태계별 용량 도넛 차트 + 범례 (메인 분포 바와 같은 팔레트)
    private func breakdownView(_ slices: [DevProfile.EcoSlice]) -> some View {
        let total = max(1, slices.reduce(0) { $0 + $1.sizeKB })
        // 누적 비율로 각 섹터의 시작·끝(0~1)을 미리 계산
        var acc = 0.0
        let arcs = slices.enumerated().map { i, s -> (idx: Int, slice: DevProfile.EcoSlice, from: Double, to: Double) in
            let from = acc
            acc += Double(s.sizeKB) / Double(total)
            return (i, s, from, acc)
        }
        return HStack(alignment: .center, spacing: 22) {
            ZStack {
                ForEach(arcs, id: \.slice.id) { a in
                    Circle()
                        .trim(from: a.from, to: a.to)
                        .stroke(Theme.segment(a.idx), style: StrokeStyle(lineWidth: 20, lineCap: .butt))
                        .rotationEffect(.degrees(-90))   // 12시 방향에서 시작
                }
                Text(humanKB(total)).font(.system(.callout, design: .rounded).weight(.bold))
            }
            .frame(width: 122, height: 122)
            .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 7) {
                ForEach(arcs, id: \.slice.id) { a in
                    HStack(spacing: 8) {
                        Circle().fill(Theme.segment(a.idx)).frame(width: 9, height: 9)
                        Text(a.slice.name).font(.caption)
                        Spacer(minLength: 12)
                        Text(humanKB(a.slice.sizeKB)).font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    /// 희소성 등급 → 색 (게임 관습: 보통 회색 · 중간 파랑 · 희소 보라 · 매우 희소 금색)
    private func rarityColor(_ r: DevProfile.BadgeRarity) -> Color {
        switch r {
        case .common:    return .gray
        case .uncommon:  return .blue
        case .rare:      return .purple
        case .legendary: return Color(red: 0.90, green: 0.64, blue: 0.10)   // gold
        }
    }

    /// 획득 배지 — 아이콘 타일만 표시(테두리=희소성 색), 마우스 오버 시 제목+설명+등급 팝오버
    /// 팝오버를 배지 위쪽(arrowEdge:.top)에 띄워 마우스가 배지를 벗어나지 않게 → 깜빡임 방지
    private func badgesView(_ keys: [String]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(keys, id: \.self) { key in
                let color = rarityColor(DevProfile.rarity(forKey: key))
                Text(DevProfile.emoji(forKey: key))
                    .font(.title2)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(color.opacity(0.14)))
                    .overlay(Circle().strokeBorder(color.opacity(0.55), lineWidth: 1.5))
                    .onHover { hovering in
                        if hovering { hoverBadge = key }
                        else if hoverBadge == key { hoverBadge = nil }
                    }
                    .popover(isPresented: Binding(
                        get: { hoverBadge == key },
                        set: { if !$0 && hoverBadge == key { hoverBadge = nil } }
                    ), arrowEdge: .top) { badgeTip(key) }
            }
        }
        .padding(.vertical, 4)
    }

    /// 호버 시 뜨는 배지 정보 카드 — [이모지][제목]···[희소도] 한 줄 + [설명] 둘째 줄
    /// 유동 너비: 제목 줄은 줄바꿈 금지(fixedSize)로 팝오버 폭을 키우고, 설명만 maxWidth 안에서 wrap
    private func badgeTip(_ key: String) -> some View {
        let rarity = DevProfile.rarity(forKey: key)
        let color = rarityColor(rarity)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(DevProfile.emoji(forKey: key)).font(.title3)
                Text(tr("badge.\(key)", lang)).font(.headline).fixedSize()
                Spacer(minLength: 10)
                HStack(spacing: 4) {
                    Circle().fill(color).frame(width: 6, height: 6)
                    Text(tr("rarity.\(rarity.rawValue)", lang))
                        .font(.caption).fontWeight(.semibold).foregroundStyle(color)
                }
                .fixedSize()
            }
            Text(tr("badge.\(key).desc", lang))
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(minWidth: 170, maxWidth: 340, alignment: .leading)
    }
}

/// 정보 — Form(레이블 좌 / 값 우).
struct AboutSettings: View {
    @Environment(\.appLanguage) private var lang
    @Environment(\.openURL) private var openURL
    @AppStorage("totalReclaimedKB") private var totalReclaimedKB = 0
    @State private var updater = UpdateChecker()
    @State private var installer = Updater()
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Icons.view("broom", size: 30).foregroundStyle(Theme.sweep)
                        .frame(width: 46, height: 46)
                        .background(RoundedRectangle(cornerRadius: 11).fill(Theme.sweep.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DevSweep").font(.system(.title3, design: .rounded).weight(.bold))
                        Text(tr("about.tagline", lang)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            Section {
                LabeledContent(tr("about.version", lang)) {
                    HStack(spacing: 8) {
                        Text(AppInfo.version).font(.system(.callout, design: .monospaced))
                        updateControl
                    }
                }
                LabeledContent(tr("about.totalReclaimed", lang)) {
                    Text(humanKB(totalReclaimedKB)).font(.system(.callout, design: .monospaced))
                }
            }
            Section {
                LabeledContent(tr("about.license", lang), value: AppInfo.license)
                LabeledContent(tr("about.author", lang), value: AppInfo.author)
                LabeledContent("GitHub") {
                    Link("\(AppInfo.repoOwner)/\(AppInfo.repoName)", destination: AppInfo.repoURL)
                }
            }
            // 프라이버시 서약 — 민감정보 미열람·무전송 명문화 (보안 기능 신뢰의 근거)
            Section {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lock.shield.fill").foregroundStyle(Theme.sweep)
                    Text(tr("about.privacy", lang))
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .formStyle(.grouped)
        .task {
            // 콜드 오픈(설정창이 새로 뜨며 정보탭이 처음 렌더)일 때 자동 체크 — 플래그 1회 소비
            if appState.requestUpdateCheck {
                appState.requestUpdateCheck = false
                await updater.check()
            }
        }
        .onChange(of: appState.requestUpdateCheck) { _, req in
            // 설정창이 이미 정보탭에 떠 있으면 .task 가 재실행되지 않으므로, 플래그 변화를 직접 받아 체크.
            guard req else { return }
            appState.requestUpdateCheck = false
            Task { await updater.check() }
        }
    }

    @ViewBuilder private var updateControl: some View {
        switch updater.status {
        case .idle:
            Button(tr("about.checkUpdate", lang)) { Task { await updater.check() } }
                .controlSize(.small)
        case .checking:
            ProgressView().controlSize(.small).scaleEffect(0.7)
        case .upToDate:
            Label(tr("about.upToDate", lang), systemImage: "checkmark.circle.fill")
                .foregroundStyle(Theme.sweep).font(.caption)
        case .noRelease:
            HStack(spacing: 6) {
                Label(tr("about.noRelease", lang), systemImage: "shippingbox")
                    .font(.caption).foregroundStyle(.secondary)
                Button(tr("about.checkUpdate", lang)) { Task { await updater.check() } }.controlSize(.small)
            }
        case .updateAvailable(let tag, let url, let asset, let sig):
            updateAvailableView(tag: tag, page: url, asset: asset, sig: sig)
        case .failed:
            HStack(spacing: 6) {
                Text(tr("about.updateFailed", lang)).font(.caption).foregroundStyle(Theme.danger)
                Button(tr("about.checkUpdate", lang)) { Task { await updater.check() } }.controlSize(.small)
            }
        }
    }

    /// 업데이트 있음 — installer.phase 진행에 따라 [설치] 버튼 / 다운로드·설치 중 / 실패 재시도 표시.
    @ViewBuilder
    private func updateAvailableView(tag: String, page: URL, asset: URL?, sig: URL?) -> some View {
        switch installer.phase {
        case .idle:
            HStack(spacing: 6) {
                if let asset {
                    Button { Task { await installer.install(from: asset, sigURL: sig) } } label: {
                        Label(tr("about.installFmt", lang, tag), systemImage: "arrow.down.circle.fill")
                    }
                    .controlSize(.small).buttonStyle(.borderedProminent).tint(Theme.sweep)
                }
                Button { openURL(page) } label: { Image(systemName: "safari") }
                    .controlSize(.small).help(tr("about.openRelease", lang))
            }
        case .working:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small).scaleEffect(0.7)
                Text(tr("about.downloading", lang)).font(.caption).foregroundStyle(.secondary)
            }
        case .relaunching:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small).scaleEffect(0.7)
                Text(tr("about.installing", lang)).font(.caption).foregroundStyle(.secondary)
            }
        case .failed(let msg):
            HStack(spacing: 6) {
                Text(tr("about.updateFailed", lang)).font(.caption).foregroundStyle(Theme.danger).help(msg)
                if let asset {
                    Button(tr("about.retry", lang)) { Task { await installer.install(from: asset, sigURL: sig) } }.controlSize(.small)
                }
            }
        }
    }
}

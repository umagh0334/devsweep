import SwiftUI

/// 환경설정 — macOS 시스템설정 스타일. 좌측 섹션 사이드바 + 우측 Form(레이블 좌 / 컨트롤 우).
/// "Sweep Console" 토큰(Theme) + 다국어(tr) 적용.
struct SettingsView: View {
    let engine: Engine
    @State private var section: SettingsSection = .general
    @Environment(\.appLanguage) private var lang

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 680, height: 480)
        .tint(Theme.sweep)
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
        case .general:  GeneralSettings(engine: engine)
        case .protect:  ProtectSettings(engine: engine)
        case .age:      AgeSettings(engine: engine)
        case .schedule: comingSoon("calendar", tr("set.schedule", lang), tr("coming.scheduleDesc", lang))
        case .about:    AboutSettings()
        }
    }

    private func comingSoon(_ icon: String, _ title: String, _ desc: String) -> some View {
        ContentUnavailableView {
            Label { Text(title).font(.system(.title3, design: .rounded)) }
            icon: { Icons.view(icon, size: 34).foregroundStyle(.secondary) }
        } description: {
            Text(desc)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)   // detail 의 topLeading 무시하고 중앙 배치
    }
}

/// 좌측 사이드바 섹션 (Solar 아이콘).
enum SettingsSection: String, CaseIterable, Identifiable {
    case general, protect, age, schedule, about
    var id: String { rawValue }
    var titleKey: String {
        switch self {
        case .general:  return "set.general"
        case .protect:  return "set.protect"
        case .age:      return "set.age"
        case .schedule: return "set.schedule"
        case .about:    return "set.about"
        }
    }
    var icon: String {
        switch self {
        case .general:  return "settings"
        case .protect:  return "shield"
        case .age:      return "clock"
        case .schedule: return "calendar"
        case .about:    return "info"
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

    var body: some View {
        Form {
            Section {
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
            }
        }
        .formStyle(.grouped)
    }
}

/// 나이 필터 — 선택 기간보다 오래된 파일만 정리. 변경 시 재스캔(용량 갱신).
struct AgeSettings: View {
    let engine: Engine
    @Environment(\.appLanguage) private var lang
    @AppStorage("olderThanDays") private var olderThanDays = 0

    var body: some View {
        Form {
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
            } footer: {
                Text(tr("age.note", lang)).fixedSize(horizontal: false, vertical: true)
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

/// 정보 — Form(레이블 좌 / 값 우).
struct AboutSettings: View {
    @Environment(\.appLanguage) private var lang
    @Environment(\.openURL) private var openURL
    @AppStorage("totalReclaimedKB") private var totalReclaimedKB = 0
    @State private var updater = UpdateChecker()

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
        }
        .formStyle(.grouped)
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
        case .updateAvailable(let tag, let url):
            Button { openURL(url) } label: {
                Label(tr("about.updateAvailFmt", lang, tag), systemImage: "arrow.down.circle.fill")
            }
            .controlSize(.small).tint(Theme.heavy)
        case .failed:
            HStack(spacing: 6) {
                Text(tr("about.updateFailed", lang)).font(.caption).foregroundStyle(Theme.heavy)
                Button(tr("about.checkUpdate", lang)) { Task { await updater.check() } }.controlSize(.small)
            }
        }
    }
}

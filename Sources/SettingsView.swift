import SwiftUI
import AppKit

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
        .onAppear {
            // 설정창도 매번 화면 중앙 (메인과 동일 — 복원 위치를 덮어씀). title 로 설정창만 골라냄.
            DispatchQueue.main.async {
                NSApp.windows.first(where: { $0.title == "DevSweep 설정" })?.center()
            }
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
    case general, protect, advanced, developer, about
    var id: String { rawValue }
    var titleKey: String {
        switch self {
        case .general:   return "set.general"
        case .protect:   return "set.protect"
        case .advanced:  return "set.advanced"
        case .developer: return "set.developer"
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
/// 고급 설정 — 나이 필터 + 자동 정리(준비 중)를 한 화면에 묶음.
struct AdvancedSettings: View {
    let engine: Engine
    @Environment(\.appLanguage) private var lang
    @AppStorage("olderThanDays") private var olderThanDays = 0

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
            // 자동 정리 (준비 중)
            Section {
                LabeledContent(tr("set.schedule", lang)) {
                    Text(tr("adv.soon", lang)).foregroundStyle(.secondary)
                }
            } footer: {
                Text(tr("coming.scheduleDesc", lang)).fixedSize(horizontal: false, vertical: true)
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

    var body: some View {
        let slices = DevProfile.breakdown(engine.categories)
        let badges = DevProfile.badges(engine.categories, reclaimedKB: totalReclaimedKB, lang: lang)
        return Form {
            Section { profileCard }
            if !slices.isEmpty {
                Section { breakdownView(slices) } header: { Text(tr("dev.breakdown", lang)) }
            }
            if !badges.isEmpty {
                Section { badgesView(badges) } header: { Text(tr("dev.badges", lang)) }
            }
        }
        .formStyle(.grouped)
        .task { if engine.categories.isEmpty { await engine.scan() } }
    }

    /// 캐시 분포로 추정한 개발 성향 카드
    private var profileCard: some View {
        let p = DevProfile.analyze(engine.categories, lang: lang)
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 11) {
                Text(p.emoji).font(.system(size: 32))
                Text(p.title).font(.system(.title3, design: .rounded).weight(.bold))
                Spacer()
            }
            Text(p.summary).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
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

    /// 획득 배지 칩 (반응형 그리드)
    private func badgesView(_ badges: [DevProfile.Badge]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 7)], alignment: .leading, spacing: 7) {
            ForEach(badges) { b in
                HStack(spacing: 5) {
                    Text(b.emoji).font(.callout)
                    Text(b.title).font(.caption).fontWeight(.medium)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Capsule().fill(Theme.sweep.opacity(0.12)))
            }
        }
        .padding(.vertical, 4)
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

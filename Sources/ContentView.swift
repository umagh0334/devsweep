import SwiftUI
import AppKit

struct ContentView: View {
    let engine: Engine
    @State private var selectedDetail: String?
    @Environment(\.openWindow) private var openWindow
    @Environment(\.appLanguage) private var lang
    @AppStorage("autoScan") private var autoScan = true
    @AppStorage("olderThanDays") private var olderThanDays = 0

    private var totalKB: Int { engine.categories.filter { !$0.protected }.reduce(0) { $0 + $1.sizeKB } }
    private var selectedKB: Int { engine.categories.filter(\.selected).reduce(0) { $0 + $1.sizeKB } }
    private var selectedCount: Int { engine.categories.filter(\.selected).count }
    /// 정리 가능(용량 있음 + 보호 안 됨), 용량 내림차순 — 분포 바·색·자동선택의 기준
    private var ranked: [CacheCategory] { engine.categories.filter { $0.hasSize && !$0.protected }.sorted { $0.sizeKB > $1.sizeKB } }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let err = engine.errorMessage { errorBanner(err) }
            HSplitView {
                masterList
                    .frame(minWidth: 300, idealWidth: 332, maxWidth: 440)
                detailPanel
                    .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
            }
            footer
        }
        .frame(width: 900, height: 620)
        .tint(Theme.sweep)
        .onAppear {
            // 매 실행 화면 중앙 (복원된 위치를 덮어씀). .background(NSView)는 윈도우 생성을 깨므로 onAppear 사용.
            DispatchQueue.main.async {
                NSApp.windows.first(where: { $0.isVisible })?.center()
            }
        }
        .task { if autoScan { await engine.scan() } }
        .task(id: engine.categories.count) {
            if selectedDetail == nil { selectedDetail = ranked.first?.name }
        }
    }

    private func rank(of name: String) -> Int? { ranked.firstIndex { $0.name == name } }

    // ── 헤더: 로고 · 대형 회수량 · 분포 스택 바(시그니처) ──
    private var header: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline, spacing: 11) {
                Icons.view("broom", size: 26).foregroundStyle(Theme.sweep)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 5 }
                VStack(alignment: .leading, spacing: 2) {
                    Text("DevSweep").font(.system(.title2, design: .rounded).weight(.bold))
                    HStack(spacing: 6) {
                        Text(tr("header.trackingFmt", lang, engine.categories.count))
                            .font(.caption).foregroundStyle(.secondary)
                        if olderThanDays > 0 {
                            Text(tr("age.badgeFmt", lang, olderThanDays))
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.sweep)
                                .padding(.horizontal, 6).padding(.vertical, 1.5)
                                .background(Theme.sweep.opacity(0.15)).clipShape(Capsule())
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(tr("recoverable", lang)).font(.caption2).foregroundStyle(.secondary)
                        .textCase(.uppercase).tracking(0.6)
                    Text(humanKB(totalKB))
                        .font(.system(size: 30, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.sweep)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: totalKB)
                }
            }
            distributionBar
        }
        .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 14)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) { Divider() }
    }

    /// 시그니처: 전체 캐시를 카테고리별 색 세그먼트로 — "디스크 개발 캐시 지도"
    private var distributionBar: some View {
        let items = ranked
        let sum = max(1, items.reduce(0) { $0 + $1.sizeKB })
        return VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 1.5) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { i, cat in
                        Theme.segment(i)
                            .frame(width: max(3, (geo.size.width - CGFloat(items.count) * 1.5) * Double(cat.sizeKB) / Double(sum)))
                            .help("\(cat.name) · \(cat.sizeHuman)")
                    }
                    if items.isEmpty { Capsule().fill(.quaternary) }
                }
            }
            .frame(height: 9)
            .clipShape(Capsule())
            if let top = items.first {
                HStack(spacing: 5) {
                    Circle().fill(Theme.segment(0)).frame(width: 6, height: 6)
                    Text(tr("header.mostFmt", lang, top.name, top.sizeHuman))
                        .font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    if items.count > 1 {
                        Text(tr("header.othersFmt", lang, items.count - 1)).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // ── 마스터: 카테고리 리스트 (용량 있는 것 + 캐시 없음 섹션) ──
    private var masterList: some View {
        let active = ranked
        let protectedItems = engine.categories.filter(\.protected)
        let empty = engine.categories.filter { !$0.hasSize && !$0.protected }
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 3) {
                    if active.isEmpty && olderThanDays > 0 && !engine.categories.isEmpty {
                        filterEmptyBanner
                    }
                    ForEach(active) { row($0) }
                    if !protectedItems.isEmpty {
                        groupHeader(tr("badge.protected", lang), protectedItems.count, icon: "lock.fill")
                        ForEach(protectedItems) { row($0) }
                    }
                    if !empty.isEmpty {
                        groupHeader(tr("master.empty", lang), empty.count)
                        ForEach(empty) { row($0) }
                    }
                }
                .padding(8)
            }
            .scrollContentBackground(.hidden)
            .onChange(of: selectedDetail) { _, new in
                if let n = new { withAnimation(.snappy) { proxy.scrollTo(n) } }
            }
        }
    }

    private func row(_ cat: CacheCategory) -> some View {
        MasterRow(cat: cat, engine: engine, rank: rank(of: cat.name),
                  isActive: selectedDetail == cat.name,
                  onSelect: { withAnimation(.snappy(duration: 0.18)) { selectedDetail = cat.name } })
            .id(cat.name)
    }

    private func groupHeader(_ title: String, _ n: Int, icon: String? = nil) -> some View {
        HStack(spacing: 7) {
            if let icon { Image(systemName: icon).font(.system(size: 9)).foregroundStyle(Theme.guardTone) }
            Text(title).font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.tertiary).textCase(.uppercase).tracking(0.5)
            Text("\(n)").font(.system(size: 10, design: .rounded)).foregroundStyle(.tertiary)
            Divider()
        }
        .padding(.horizontal, 9).padding(.top, 13).padding(.bottom, 3)
    }

    /// 나이 필터로 정리 가능 항목이 전부 비었을 때 안내 + 끄기 버튼
    private var filterEmptyBanner: some View {
        VStack(spacing: 9) {
            Icons.view("clock", size: 26).foregroundStyle(Theme.sweep)
            Text(tr("filter.emptyTitleFmt", lang, olderThanDays))
                .font(.system(.callout, design: .rounded).weight(.semibold))
            Text(tr("filter.emptyDesc", lang))
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Button {
                olderThanDays = 0
                Task { await engine.scan() }
            } label: {
                Text(tr("filter.turnOff", lang))
            }
            .controlSize(.small).buttonStyle(.borderedProminent).padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22).padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.sweep.opacity(0.06)))
        .padding(.bottom, 4)
    }

    // ── 디테일: 선택된 카테고리 상세 패널 ──
    private var detailPanel: some View {
        Group {
            if let name = selectedDetail, let cat = engine.categories.first(where: { $0.name == name }) {
                DetailPanel(cat: cat, rank: rank(of: name), engine: engine).id(name)
            } else {
                VStack(spacing: 10) {
                    Icons.view("broom", size: 38).foregroundStyle(.tertiary)
                    Text(tr("detail.empty", lang))
                        .font(.callout).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.primary.opacity(0.02))
    }

    private func errorBanner(_ err: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(err).font(.callout)
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16).padding(.vertical, 9)
        .background(Theme.heavy)
    }

    // ── 푸터: 선택 요약 · 액션 ──
    private var footer: some View {
        HStack(spacing: 10) {
            if engine.isScanning || engine.isCleaning {
                ProgressView().controlSize(.small)
                Text(engine.isCleaning ? tr("footer.cleaning", lang) : tr("footer.scanning", lang)).foregroundStyle(.secondary)
            } else if selectedCount > 0 {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.sweep)
                Text(tr("footer.selectedFmt", lang, selectedCount)).fontWeight(.medium)
                Text(tr("footer.willCleanFmt", lang, humanKB(selectedKB))).foregroundStyle(.secondary)
            } else {
                Text(tr("footer.prompt", lang)).foregroundStyle(.secondary)
            }
            Spacer()
            Button { openWindow(id: "settings") } label: {
                Image(systemName: "gearshape").font(.system(size: 13))
            }
            .buttonStyle(.borderless).help(tr("footer.settings", lang))
            Button { Task { await engine.scan() } } label: {
                HStack(spacing: 5) { Icons.view("refresh", size: 12); Text(tr("footer.rescan", lang)) }
            }
            .disabled(engine.isScanning || engine.isCleaning)
            Button { Task { await engine.clean() } } label: {
                HStack(spacing: 5) { Icons.view("trash", size: 12); Text(tr("footer.clean", lang)) }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(selectedCount == 0 || engine.isCleaning || engine.isScanning)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }
}

// ─────────────────────────────────────────────────────────────
//  공유 배지
// ─────────────────────────────────────────────────────────────
struct HeavyBadge: View {
    var body: some View {
        Text("HEAVY").font(.system(size: 8.5, weight: .heavy, design: .rounded)).tracking(0.4)
            .foregroundStyle(Theme.heavy)
            .padding(.horizontal, 5).padding(.vertical, 1.5)
            .background(Theme.heavy.opacity(0.16)).clipShape(Capsule())
    }
}
struct ProtectedBadge: View {
    @Environment(\.appLanguage) private var lang
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "lock.fill").font(.system(size: 8))
            Text(tr("badge.protect", lang)).font(.system(size: 8.5, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(Theme.guardTone)
        .padding(.horizontal, 5).padding(.vertical, 1.5)
        .background(Theme.guardTone.opacity(0.18)).clipShape(Capsule())
    }
}

/// 마스터 행: 체크박스(정리 대상) · 아이콘 칩 · 이름/유형 · 용량. 클릭 시 디테일 활성.
struct MasterRow: View {
    let cat: CacheCategory
    let engine: Engine
    let rank: Int?
    let isActive: Bool
    let onSelect: () -> Void
    @Environment(\.appLanguage) private var lang
    @AppStorage("olderThanDays") private var olderThanDays = 0

    private var accent: Color {
        if cat.protected { return Theme.guardTone }
        if let r = rank { return Theme.segment(r) }
        return cat.heavy ? Theme.heavy : Theme.sweep
    }
    private var dimmed: Bool { !cat.hasSize && !isActive }

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(get: { cat.selected }, set: { engine.setSelected(cat.name, $0) }))
                .labelsHidden().toggleStyle(.checkbox)
                .disabled(cat.protected || !cat.hasSize)
                .help(cat.protected ? tr("master.tipProtected", lang)
                      : (!cat.hasSize ? (olderThanDays > 0 ? tr("master.tipFiltered", lang) : tr("master.tipNoCache", lang))
                                      : tr("master.tipSelect", lang)))
            Icons.view(cat.iconName, size: 16)
                .foregroundStyle(cat.protected ? AnyShapeStyle(Theme.guardTone) : AnyShapeStyle(accent))
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 7).fill(accent.opacity(cat.hasSize ? 0.14 : 0.06)))
                .opacity(cat.protected ? 0.7 : 1)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(cat.name).font(.system(.body, design: .rounded).weight(.medium))
                        .foregroundStyle(cat.protected ? .secondary : .primary)
                    if cat.heavy { HeavyBadge() }
                    if cat.protected { Image(systemName: "lock.fill").font(.system(size: 8)).foregroundStyle(Theme.guardTone) }
                }
                Text(tr(kindKey(cat.kind), lang)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 6)
            Text(cat.sizeHuman).font(.system(.callout, design: .monospaced))
                .foregroundStyle(cat.hasSize ? .primary : .secondary)
        }
        .padding(.vertical, 6).padding(.horizontal, 9)
        .opacity(dimmed ? 0.5 : 1)
        .background(RoundedRectangle(cornerRadius: 8).fill(isActive ? accent.opacity(0.15) : .clear))
        .overlay(alignment: .leading) {
            if isActive { Capsule().fill(accent).frame(width: 3).padding(.vertical, 7) }
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}

/// 디테일 패널: 헤더(아이콘·이름·대형 용량·배지) + 경로/명령/노트 스크롤 + 하단 정리 액션.
struct DetailPanel: View {
    let cat: CacheCategory
    let rank: Int?
    let engine: Engine
    @Environment(\.appLanguage) private var lang

    private var detail: CategoryDetail? { engine.detailCache[cat.name] }
    private var loading: Bool { engine.loadingDetails.contains(cat.name) }
    private var accent: Color {
        if cat.protected { return Theme.guardTone }
        if let r = rank { return Theme.segment(r) }
        return cat.heavy ? Theme.heavy : Theme.sweep
    }

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let d = detail {
                        if !d.paths.isEmpty { pathsSection(d) }
                        commandSection(d)
                        noteSection(d)
                        if !d.extra.isEmpty { extraSection(d) }
                    } else if loading {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text(tr("detail.analyzing", lang)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if cat.hasSize && !cat.protected {
                Divider()
                actionBar
            }
        }
        .task(id: cat.name) {
            if engine.detailCache[cat.name] == nil { await engine.loadDetail(cat.name) }
        }
    }

    private var panelHeader: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 13) {
                Icons.view(cat.iconName, size: 25)
                    .foregroundStyle(cat.protected ? AnyShapeStyle(Theme.guardTone) : AnyShapeStyle(accent))
                    .frame(width: 46, height: 46)
                    .background(RoundedRectangle(cornerRadius: 11).fill(accent.opacity(cat.hasSize ? 0.14 : 0.07)))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(cat.name).font(.system(.title2, design: .rounded).weight(.bold))
                        if cat.heavy { HeavyBadge() }
                        if cat.protected { ProtectedBadge() }
                    }
                    Text(tr(kindKey(cat.kind), lang)).font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(cat.sizeHuman)
                        .font(.system(size: 23, weight: .semibold, design: .monospaced))
                        .foregroundStyle(cat.hasSize ? accent : .secondary)
                    Text(tr("recoverable", lang)).font(.caption2).foregroundStyle(.secondary)
                }
            }
            if let d = detail { badgeRow(d) }
        }
        .padding(18)
    }

    private func badgeRow(_ d: CategoryDetail) -> some View {
        HStack(spacing: 6) {
            if d.protected { badge(tr("badge.protected", lang), icon: "hand.raised.fill", color: Theme.guardTone) }
            badge(tr(d.safety == "caution" ? "badge.caution" : "badge.safe", lang),
                  icon: d.safetyIcon, color: d.safety == "caution" ? Theme.heavy : Theme.sweep)
            badge(tr("cost.\(costKey(d.regenCost))", lang), icon: "arrow.clockwise",
                  color: d.regenCost == "high" ? Theme.heavy : (d.regenCost == "low" ? Theme.sweep : Theme.guardTone))
            if d.needsTCC { badge(tr("badge.tcc", lang), icon: "lock.fill", color: Theme.heavy) }
            if !d.nativeAvailable { badge(tr("badge.noTool", lang), icon: "wrench.adjustable", color: Theme.guardTone) }
            Spacer()
        }
    }

    private func badge(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9))
            Text(text).font(.system(size: 10, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7).padding(.vertical, 2.5)
        .background(color.opacity(0.14)).clipShape(Capsule())
    }

    private func pathsSection(_ d: CategoryDetail) -> some View {
        let maxPath = d.paths.map(\.sizeKB).max() ?? 1
        return VStack(alignment: .leading, spacing: 6) {
            sectionLabel(tr("detail.secPaths", lang), icon: "folder")
            ForEach(d.paths) { PathRow(entry: $0, maxKB: maxPath) }
        }
    }

    private func commandSection(_ d: CategoryDetail) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                sectionLabel(tr("detail.secCommand", lang), icon: "terminal")
                Spacer()
                Text(d.method == "native" ? tr("detail.methodNative", lang) : tr("detail.methodRm", lang))
                    .font(.system(size: 9, design: .rounded)).foregroundStyle(.secondary)
                Button { copy(d.command) } label: {
                    Image(systemName: "doc.on.doc").font(.system(size: 11))
                }
                .buttonStyle(.plain).foregroundStyle(Theme.sweep).help(tr("detail.copyHelp", lang))
            }
            Text(d.command)
                .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.sweep.opacity(0.18), lineWidth: 1))
            if let fb = d.fallback {
                Text("\(tr("detail.failPrefix", lang))  \(fb)")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
            }
        }
    }

    /// 정리 후 노트 — CLI 한국어 문장 대신 regen_cost·safety 코드로 번역 생성
    private func noteSection(_ d: CategoryDetail) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            sectionLabel(tr("detail.secAfter", lang), icon: "arrow.clockwise")
            Text(tr("regen.\(costKey(d.regenCost))", lang)).font(.callout).foregroundStyle(.secondary)
            Text(tr(d.safety == "caution" ? "safety.caution" : "safety.safe", lang)).font(.callout).foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func extraSection(_ d: CategoryDetail) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "info.circle.fill").font(.system(size: 11)).foregroundStyle(Theme.sweep)
            Text(d.extra).font(.callout).foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.sweep.opacity(0.06)))
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            Text(tr("detail.cleanThisInfoFmt", lang, cat.sizeHuman))
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button { Task { await engine.clean(targets: [cat.name]) } } label: {
                HStack(spacing: 5) { Icons.view("trash", size: 12); Text(tr("detail.cleanThis", lang)) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(engine.isCleaning || engine.isScanning)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private func sectionLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10)).foregroundStyle(Theme.sweep)
            Text(text).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
                .textCase(.uppercase).tracking(0.4)
        }
    }

    private func costKey(_ c: String) -> String { ["low", "med", "high"].contains(c) ? c : "med" }

    private func copy(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }
}

/// 디테일의 경로별 용량 한 줄.
struct PathRow: View {
    let entry: PathEntry
    let maxKB: Int
    @Environment(\.appLanguage) private var lang

    private var frac: Double { maxKB > 0 ? min(1.0, Double(entry.sizeKB) / Double(maxKB)) : 0 }

    var body: some View {
        HStack(spacing: 8) {
            Text(entry.path)
                .font(.system(.caption, design: .monospaced))
                .truncationMode(.middle).lineLimit(1)
                .frame(maxWidth: 240, alignment: .leading)
            Spacer(minLength: 4)
            if entry.needsPermission {
                Label(tr("path.perm", lang), systemImage: "lock.fill")
                    .font(.system(size: 9)).foregroundStyle(Theme.heavy)
            } else if !entry.exists {
                Text(tr("path.none", lang)).font(.caption).foregroundStyle(.tertiary)
            } else {
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08)).frame(width: 60, height: 4)
                    Capsule().fill(Theme.sweep).frame(width: max(1, 60 * frac), height: 4)
                }
                Text(entry.sizeHuman).font(.system(.caption, design: .monospaced))
                    .frame(width: 64, alignment: .trailing)
            }
        }
    }
}

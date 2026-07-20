import SwiftUI
import AppKit

/// 정리 확인 모달 요청. targets=nil 이면 선택 전체, 값 있으면 그 카테고리만.
struct CleanRequest: Identifiable, Equatable {
    let id = UUID()
    let targets: [String]?
    let title: String        // 단일이면 카테고리명
    let count: Int
    let sizeKB: Int
    let hasHeavy: Bool
    let isSingle: Bool
    var isProject = false     // true 면 프로젝트 폴더 정리(engine.cleanProjects)
}

struct ContentView: View {
    let engine: Engine
    @State private var selectedDetail: String?
    @State private var cleanRequest: CleanRequest?
    @Environment(\.openWindow) private var openWindow
    @Environment(\.appLanguage) private var lang
    @Environment(AppState.self) private var appState
    @AppStorage("autoScan") private var autoScan = true
    @AppStorage("olderThanDays") private var olderThanDays = 0
    @AppStorage("sortMode") private var sortMode = 0     // 0=크기순(기본) 1=이름순
    @AppStorage("deleteMode") private var deleteMode = 0 // 0=휴지통(기본·복구가능) 1=완전삭제
    @AppStorage("appMode") private var appMode = 0       // 0=캐시 1=프로젝트 폴더 스캐너
    @State private var scanRoot = ""                     // 프로젝트 스캔 위치(빈값=홈)
    @State private var projOldOnly = false               // 30일+ 미사용만 표시

    private var totalKB: Int { engine.categories.filter { !$0.protected }.reduce(0) { $0 + $1.sizeKB } }
    private var selectedKB: Int { engine.categories.filter(\.selected).reduce(0) { $0 + $1.sizeKB } }
    private var selectedCount: Int { engine.categories.filter(\.selected).count }
    private var selectedHasHeavy: Bool { engine.categories.contains { $0.selected && $0.heavy } }
    /// 정리 가능(용량 있음 + 보호 안 됨), 용량 내림차순 — 분포 바·색·자동선택의 기준
    private var ranked: [CacheCategory] { engine.categories.filter { $0.hasSize && !$0.protected }.sorted { $0.sizeKB > $1.sizeKB } }
    /// 마스터 리스트 표시 순서 — 정렬 토글(0=크기순=ranked, 1=이름순). 색상 rank 는 항상 크기 기준(ranked)이라
    /// 여기서 순서만 바꿔도 행 색·분포 바는 용량 의미를 유지한다.
    private var sortedActive: [CacheCategory] {
        sortMode == 1 ? ranked.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } : ranked
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if AppInfo.isTranslocated { translocationBanner }
            if let err = engine.errorMessage { errorBanner(err) }
            if appMode == 1 {
                projectScanView
            } else {
                HSplitView {
                    masterList
                        .frame(minWidth: 300, idealWidth: 332, maxWidth: 440)
                    detailPanel
                        .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
                }
                footer
            }
        }
        .frame(width: 900, height: 620)
        .overlay { cleanConfirmOverlay }
        .overlay { cleanProgressOverlay }
        .animation(.snappy(duration: 0.22), value: cleanRequest)
        .animation(.snappy(duration: 0.25), value: engine.showCleanProgress)
        .animation(.snappy(duration: 0.2), value: engine.cleanItems)
        .onChange(of: appState.requestCleanRecommended) { _, req in
            // 메뉴바 "안전셋 정리…" → 캐시 모드로 전환·추천셋 선택·확인창 표시
            guard req else { return }
            appState.requestCleanRecommended = false
            appMode = 0
            engine.setRecommended()
            let sel = engine.categories.filter(\.selected)
            guard !sel.isEmpty else { return }
            cleanRequest = CleanRequest(targets: nil, title: "", count: sel.count,
                                        sizeKB: sel.reduce(0) { $0 + $1.sizeKB },
                                        hasHeavy: sel.contains { $0.heavy }, isSingle: false)
        }
        .tint(Theme.sweep)
        .onAppear {
            // 매 실행 화면 중앙 (복원된 위치를 덮어씀). .background(NSView)는 윈도우 생성을 깨므로 onAppear 사용.
            DispatchQueue.main.async {
                NSApp.windows.first(where: { $0.isVisible })?.center()
            }
        }
        .task { if autoScan { await engine.scan() } }
        .task(id: appMode) {
            // 프로젝트 모드 첫 진입 시 홈을 자동 스캔 (기본 자동, 이후 폴더 지정 가능)
            if appMode == 1, engine.projectDirs.isEmpty, engine.projectScanRoot.isEmpty, !engine.isScanningProjects {
                await engine.scanProjects(root: "~")
            }
        }
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
                // 모드 전환 — 캐시 정리 / 프로젝트 폴더 스캐너
                Picker("", selection: $appMode) {
                    Text(tr("mode.cache", lang)).tag(0)
                    Text(tr("mode.projects", lang)).tag(1)
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize().controlSize(.regular)
                if appMode == 0 {
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
            }
            if appMode == 0 { distributionBar }
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
        let active = sortedActive
        let protectedItems = engine.categories.filter(\.protected)
        let empty = engine.categories.filter { !$0.hasSize && !$0.protected }
        return VStack(spacing: 0) {
            if !engine.categories.isEmpty { selectionBar(selectable: active) }
            ScrollViewReader { proxy in
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
    }

    /// 마스터 리스트 상단 바: 전체 선택/해제 토글 + 선택 카운트(선택수 / 정리가능 수).
    /// allOn 은 현재 정리가능 항목이 전부 선택됐는지에서 파생 — 별도 상태 없이 재스캔에도 정확.
    private func selectionBar(selectable: [CacheCategory]) -> some View {
        let allOn = !selectable.isEmpty && selectable.allSatisfy(\.selected)
        return HStack(spacing: 8) {
            Button { engine.setAllSelected(!allOn) } label: {
                HStack(spacing: 5) {
                    Image(systemName: allOn ? "checkmark.square.fill" : "square")
                        .foregroundStyle(allOn ? AnyShapeStyle(Theme.sweep) : AnyShapeStyle(.secondary))
                    Text(allOn ? tr("select.none", lang) : tr("select.all", lang))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
            }
            .buttonStyle(.plain)
            .disabled(selectable.isEmpty)

            // 추천 선택 — 안전셋(SAFE·!heavy·hasSize·!protected)만 한 방에. 액센트 칩(틴트+테두리+포인터
            // 커서)으로 '누르는 액션'임을 명확히 — 테두리 없는 HEAVY 뱃지/라벨과 혼동되지 않게.
            Button { withAnimation(.snappy(duration: 0.18)) { engine.setRecommended() } } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles").font(.system(size: 10))
                    Text(tr("select.recommended", lang))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Theme.sweep)
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(Capsule().fill(Theme.sweep.opacity(0.14)))
                .overlay(Capsule().strokeBorder(Theme.sweep.opacity(0.40), lineWidth: 1))
                .contentShape(Capsule())
                .opacity(selectable.isEmpty ? 0.45 : 1)
            }
            .buttonStyle(.plain)
            .disabled(selectable.isEmpty)
            .help(tr("select.recommendedHelp", lang))
            .onHover { inside in
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }

            Spacer()
            if !selectable.isEmpty {
                Text("\(selectedCount) / \(selectable.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            // 정렬 토글 — 크기순 ⇄ 이름순. 현재 모드를 표시하고 누르면 전환. 중립 칩(추천 액센트보다 조용)
            // + 포인터 커서로 클릭 가능함을 명확히.
            Button { withAnimation(.snappy(duration: 0.2)) { sortMode = sortMode == 0 ? 1 : 0 } } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.arrow.down").font(.system(size: 9))
                    Text(tr(sortMode == 0 ? "sort.bySize" : "sort.byName", lang))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Color.primary.opacity(0.05)))
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help(tr("sort.help", lang))
            .onHover { inside in
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) { Divider() }
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
                DetailPanel(cat: cat, rank: rank(of: name), engine: engine, onRequestClean: {
                    cleanRequest = CleanRequest(targets: [cat.name], title: cat.name, count: 1,
                                                sizeKB: cat.sizeKB, hasHeavy: cat.heavy, isSingle: true)
                }).id(name)
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
        .background(Theme.danger)
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
            Button {
                cleanRequest = CleanRequest(targets: nil, title: "", count: selectedCount,
                                            sizeKB: selectedKB, hasHeavy: selectedHasHeavy, isSingle: false)
            } label: {
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

    // ── 커스텀 정리 확인 모달 (시스템 다이얼로그 대체) ──

    @ViewBuilder private var cleanConfirmOverlay: some View {
        if let req = cleanRequest {
            ZStack {
                Rectangle().fill(.black.opacity(0.32)).ignoresSafeArea()
                    .onTapGesture { cleanRequest = nil }   // 바깥 탭 = 취소
                cleanCard(req)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
    }

    private func cleanCard(_ req: CleanRequest) -> some View {
        let accent = req.hasHeavy ? Theme.heavy : Theme.sweep
        return VStack(spacing: 0) {
            ZStack {
                Circle().fill(accent.opacity(0.15)).frame(width: 62, height: 62)
                Icons.view("trash", size: 27).foregroundStyle(accent)
            }
            .padding(.top, 26)
            Text(tr("confirm.title", lang))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .padding(.top, 14)
            Text(humanKB(req.sizeKB))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(req.hasHeavy ? Color.primary : accent)   // 앰버는 글자 대비가 약해 heavy 시 primary
                .contentTransition(.numericText())
                .padding(.top, 6)
            Text(req.isSingle ? tr("confirm.oneSubFmt", lang, req.title)
                              : tr("confirm.allSubFmt", lang, req.count))
                .font(.callout).foregroundStyle(.secondary).padding(.top, 1)
            if req.hasHeavy {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11))
                        .foregroundStyle(Theme.heavy)                      // 색 신호는 아이콘이 담당
                    Text(tr("confirm.heavyWarn", lang))
                        .font(.caption).foregroundStyle(.primary)          // 글자는 또렷하게
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 11).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 9).fill(Theme.heavy.opacity(0.15)))
                .padding(.horizontal, 22).padding(.top, 16)
            }
            // 삭제 방식 — 휴지통(복구가능, 기본) / 완전삭제(영구). 정리 전에 선택, 마지막 선택 기억.
            Picker("", selection: $deleteMode) {
                Label(tr("delete.trash", lang), systemImage: "trash").tag(0)
                Label(tr("delete.permanent", lang), systemImage: "trash.slash").tag(1)
            }
            .pickerStyle(.segmented).labelsHidden()
            .padding(.horizontal, 22).padding(.top, 18)
            Text(deleteMode == 0 ? tr("delete.trashDesc", lang) : tr("delete.permanentDesc", lang))
                .font(.caption)
                .foregroundStyle(deleteMode == 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(Theme.danger))
                .padding(.top, 5)

            HStack(spacing: 10) {
                Button { cleanRequest = nil } label: {
                    Text(tr("confirm.cancel", lang)).frame(maxWidth: .infinity)
                }
                .controlSize(.large).buttonStyle(.bordered).keyboardShortcut(.cancelAction)
                Button { runClean(req) } label: {
                    Text(tr("confirm.clean", lang)).frame(maxWidth: .infinity).fontWeight(.semibold)
                }
                .controlSize(.large).buttonStyle(.borderedProminent)
                .tint(deleteMode == 1 ? Theme.danger : accent)   // 완전삭제는 위험색으로 신호
            }
            .padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 22)
        }
        .frame(width: 340)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.28), radius: 28, y: 10)
    }

    private func runClean(_ req: CleanRequest) {
        cleanRequest = nil
        if req.isProject { Task { await engine.cleanProjects() } }
        else { Task { await engine.clean(targets: req.targets) } }
    }

    /// App Translocation 경고 — 임시 마운트에서 실행 중이면 자동 업데이트가 실패하므로
    /// /Applications 로 복사 후 재실행을 1클릭으로 제안한다.
    private var translocationBanner: some View {
        HStack(spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 1) {
                Text(tr("transloc.title", lang)).font(.callout.weight(.semibold)).foregroundStyle(.white)
                Text(tr("transloc.body", lang)).font(.caption).foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
            Button(tr("transloc.move", lang)) { moveToApplications() }
                .controlSize(.small)
        }
        .padding(.horizontal, 16).padding(.vertical, 9)
        .background(Theme.heavy)
    }

    /// /Applications 로 복사 → quarantine 제거 → 새 위치에서 재실행 후 종료.
    private func moveToApplications() {
        let fm = FileManager.default
        let src = Bundle.main.bundleURL
        let dest = URL(fileURLWithPath: "/Applications/\(src.lastPathComponent)")
        do {
            if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
            try fm.copyItem(at: src, to: dest)
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
            p.arguments = ["-dr", "com.apple.quarantine", dest.path]
            try? p.run(); p.waitUntilExit()
            NSWorkspace.shared.open(dest)
            NSApp.terminate(nil)
        } catch {
            engine.errorMessage = tr("transloc.failFmt", lang, error.localizedDescription)
        }
    }

    // ── 프로젝트 폴더 스캐너 뷰 ──

    private var filteredProjects: [ProjectDir] {
        projOldOnly ? engine.projectDirs.filter { $0.ageDays >= 30 } : engine.projectDirs
    }
    private var selectedProjects: [ProjectDir] { filteredProjects.filter(\.selected) }

    private func projDisplay(_ p: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return p.hasPrefix(home) ? "~" + p.dropFirst(home.count) : p
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = tr("proj.pickFolder", lang)
        if panel.runModal() == .OK, let url = panel.url {
            scanRoot = url.path
            Task { await engine.scanProjects(root: url.path) }
        }
    }

    private var projectScanView: some View {
        let allOn = !filteredProjects.isEmpty && filteredProjects.allSatisfy(\.selected)
        return VStack(spacing: 0) {
            // 툴바: 스캔 위치 · 폴더 선택 · 오래된 것만 · 스캔
            HStack(spacing: 8) {
                Image(systemName: "folder").foregroundStyle(Theme.sweep)
                Text(scanRoot.isEmpty ? "~/" : projDisplay(scanRoot))
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                Button(tr("proj.pickFolder", lang)) { pickFolder() }.controlSize(.small)
                Spacer()
                Toggle(isOn: $projOldOnly) { Text(tr("proj.oldOnly", lang)).font(.caption) }
                    .toggleStyle(.checkbox)
                Button { Task { await engine.scanProjects(root: scanRoot.isEmpty ? "~" : scanRoot) } } label: {
                    HStack(spacing: 5) {
                        if engine.isScanningProjects { ProgressView().controlSize(.small).scaleEffect(0.7) }
                        else { Image(systemName: "magnifyingglass") }
                        Text(tr("proj.scan", lang))
                    }
                }
                .buttonStyle(.borderedProminent).controlSize(.small).disabled(engine.isScanningProjects)
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(.regularMaterial).overlay(alignment: .bottom) { Divider() }

            // 본문
            if engine.isScanningProjects {
                Spacer()
                ProgressView(tr("proj.scanning", lang)).controlSize(.large)
                Spacer()
            } else if filteredProjects.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "folder.badge.questionmark").font(.system(size: 30)).foregroundStyle(.secondary)
                    Text(engine.projectScanRoot.isEmpty ? tr("proj.startHint", lang) : tr("proj.noneFound", lang))
                        .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(filteredProjects) { dir in
                            HStack(spacing: 10) {
                                Toggle("", isOn: Binding(get: { dir.selected },
                                                         set: { engine.setProjectSelected(dir.id, $0) }))
                                    .labelsHidden()
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(projDisplay(dir.path))
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .lineLimit(1).truncationMode(.middle)
                                    Text(tr("proj.agoFmt", lang, dir.ageDays))
                                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                                }
                                Spacer(minLength: 8)
                                Text(humanKB(dir.sizeKB))
                                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 11).padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                        }
                    }
                    .padding(10)
                }
            }

            // 하단 액션바 (결과 있을 때)
            if !filteredProjects.isEmpty {
                HStack(spacing: 10) {
                    Button { engine.setAllProjectsSelected(!allOn) } label: {
                        HStack(spacing: 5) {
                            Image(systemName: allOn ? "checkmark.square.fill" : "square")
                                .foregroundStyle(allOn ? AnyShapeStyle(Theme.sweep) : AnyShapeStyle(.secondary))
                            Text(allOn ? tr("select.none", lang) : tr("select.all", lang))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                    }.buttonStyle(.plain)
                    Spacer()
                    Text("\(selectedProjects.count) / \(filteredProjects.count)")
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    Button {
                        let kb = selectedProjects.reduce(0) { $0 + $1.sizeKB }
                        cleanRequest = CleanRequest(targets: nil, title: "", count: selectedProjects.count,
                                                    sizeKB: kb, hasHeavy: false, isSingle: false, isProject: true)
                    } label: {
                        HStack(spacing: 5) { Icons.view("trash", size: 12); Text(tr("footer.clean", lang)) }
                    }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(selectedProjects.isEmpty || engine.isCleaning)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.regularMaterial).overlay(alignment: .top) { Divider() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // ── 정리 진행 창 (실시간) ──

    @ViewBuilder private var cleanProgressOverlay: some View {
        if engine.showCleanProgress {
            ZStack {
                // 정리 중엔 바깥 탭으로 못 닫음(진행 보호). 완료 후 '닫기' 버튼으로만.
                Rectangle().fill(.black.opacity(0.32)).ignoresSafeArea()
                cleanProgressCard
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
    }

    /// 항목 상태 마크 — 대기(시계)/정리중(스피너)/완료(체크)/실패(엑스)
    @ViewBuilder private func statusMark(_ s: CleanStatus) -> some View {
        switch s {
        case .pending:  Image(systemName: "clock").font(.system(size: 12)).foregroundStyle(.tertiary).frame(width: 16)
        case .cleaning: ProgressView().controlSize(.small).scaleEffect(0.66).frame(width: 16)
        case .done:     Image(systemName: "checkmark.circle.fill").font(.system(size: 13)).foregroundStyle(Theme.sweep).frame(width: 16)
        case .failed:   Image(systemName: "xmark.circle.fill").font(.system(size: 13)).foregroundStyle(Theme.danger).frame(width: 16)
        }
    }

    private var cleanProgressCard: some View {
        let items = engine.cleanItems
        let total = items.count
        let ok = items.filter { $0.status == .done }.count
        let failed = items.filter { $0.status == .failed }.count
        let done = ok + failed
        let accent = failed > 0 ? Theme.heavy : Theme.sweep
        return VStack(spacing: 0) {
            // 헤더: 진행중=스피너 / 완료=체크 / 실패있음=경고
            ZStack {
                Circle().fill(accent.opacity(0.15)).frame(width: 56, height: 56)
                if !engine.cleanDone {
                    ProgressView().controlSize(.large)
                } else if failed > 0 {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 23)).foregroundStyle(Theme.heavy)
                } else {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 26)).foregroundStyle(Theme.sweep)
                }
            }
            .padding(.top, 22)
            Text(engine.cleanDone ? tr("progress.doneTitle", lang) : tr("footer.cleaning", lang))
                .font(.system(.title3, design: .rounded).weight(.bold)).padding(.top, 12)

            if engine.cleanDone {
                Text(humanKB(engine.cleanReclaimedKB))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.sweep).contentTransition(.numericText()).padding(.top, 4)
                Text(failed > 0 ? tr("progress.okFailFmt", lang, ok, failed) : tr("progress.cleanedFmt", lang, ok))
                    .font(.callout).foregroundStyle(.secondary).padding(.top, 1)
            } else {
                ProgressView(value: Double(done), total: Double(max(1, total)))
                    .tint(Theme.sweep).padding(.horizontal, 24).padding(.top, 14)
                Text("\(done) / \(total)")
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary).padding(.top, 5)
            }

            // 항목 리스트 (스크롤·고정 높이)
            ScrollView {
                VStack(spacing: 3) {
                    ForEach(items) { item in
                        HStack(spacing: 9) {
                            statusMark(item.status)
                            Text(item.name).font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(item.status == .pending ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                            Spacer(minLength: 6)
                            switch item.status {
                            case .done:
                                Text(humanKB(item.sizeKB)).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                            case .failed:
                                Text(tr("progress.rowFailed", lang)).font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Theme.danger).help(item.reason ?? "")
                            case .cleaning:
                                Text(tr("progress.rowCleaning", lang)).font(.system(size: 11)).foregroundStyle(Theme.sweep)
                            case .pending:
                                EmptyView()
                            }
                        }
                        .padding(.horizontal, 11).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 7)
                            .fill(item.status == .cleaning ? Theme.sweep.opacity(0.10) : .clear))
                    }
                }
                .padding(.horizontal, 14)
            }
            .frame(height: min(CGFloat(total) * 33 + 3, 224))
            .padding(.top, 14)

            // 휴지통 모드로 옮긴 게 있으면 — 비우기 전엔 실제 공간이 안 늘어남을 알리고 마감시킨다.
            if engine.cleanDone, !engine.trashedURLs.isEmpty {
                VStack(spacing: 7) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(Theme.heavy)
                        Text(tr("trash.pendingFmt", lang, humanKB(engine.cleanReclaimedKB)))
                            .font(.caption).foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack(spacing: 8) {
                        Button(tr("trash.open", lang)) { engine.openTrash() }
                            .controlSize(.small)
                        Button(tr("trash.purge", lang)) { engine.emptyTrashedItems() }
                            .controlSize(.small).tint(Theme.danger)
                    }
                }
                .padding(.horizontal, 11).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 9).fill(Theme.heavy.opacity(0.12)))
                .padding(.horizontal, 20).padding(.top, 14)
            }

            if engine.cleanDone {
                Button { engine.dismissCleanProgress() } label: {
                    Text(tr("progress.close", lang)).frame(maxWidth: .infinity).fontWeight(.semibold)
                }
                .controlSize(.large).buttonStyle(.borderedProminent).tint(Theme.sweep)
                .keyboardShortcut(.defaultAction)
                .padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 22)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle").font(.system(size: 11)).foregroundStyle(Theme.sweep)
                    Text(tr("progress.reclaiming", lang)).font(.caption).foregroundStyle(.secondary)
                    Text(humanKB(engine.cleanReclaimedKB))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.sweep).contentTransition(.numericText())
                }
                .padding(.top, 15).padding(.bottom, 22)
            }
        }
        .frame(width: 360)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.28), radius: 28, y: 10)
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
    let onRequestClean: () -> Void
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
        .task(id: "\(cat.name)#\(engine.detailRevision)") {
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
            // 위험도 신호등: 틸(안전·저) → 슬레이트(중립·중) → 빨강(주의·고). heavy(블루)는 위험도와 별개 속성.
            if d.protected { badge(tr("badge.protected", lang), icon: "hand.raised.fill", color: Theme.guardTone) }
            badge(tr(d.safety == "caution" ? "badge.caution" : "badge.safe", lang),
                  icon: d.safetyIcon, color: d.safety == "caution" ? Theme.danger : Theme.sweep)
            badge(tr("cost.\(costKey(d.regenCost))", lang), icon: "arrow.clockwise",
                  color: d.regenCost == "high" ? Theme.danger : (d.regenCost == "low" ? Theme.sweep : Theme.guardTone))
            if d.needsTCC { badge(tr("badge.tcc", lang), icon: "lock.fill", color: Theme.guardTone) }
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
            Button { onRequestClean() } label: {
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

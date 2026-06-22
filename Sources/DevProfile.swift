import Foundation

/// 재미 기능 — 캐시 분포로 "개발 성향"을 추정한다. 규칙 기반(LLM 호출 없음).
/// 페르소나·배지 문구는 L10n.table 의 profile.* / badge.* 키로 전 언어 번역.
enum DevProfile {
    struct Result {
        let emoji: String
        let title: String
        let summary: String
        init(_ e: String, _ t: String, _ s: String) { emoji = e; title = t; summary = s }
    }

    /// 생태계 → 카테고리 매핑
    private static let ecosystems: [(key: String, cats: Set<String>)] = [
        ("node",      ["npm", "yarn", "pnpm", "bun"]),
        ("python",    ["pip", "uv"]),
        ("rust",      ["cargo", "rustup-targets"]),
        ("go",        ["go"]),
        ("jvm",       ["gradle", "maven"]),
        ("apple",     ["cocoapods", "swiftpm", "xcode", "xcode-sim"]),
        ("php",       ["composer"]),
        ("dotnet",    ["nuget"]),
        ("deno",      ["deno"]),
        ("dart",      ["pub"]),
        ("container", ["docker", "colima"]),
        ("ml",        ["huggingface"]),
        ("webtest",   ["playwright"]),
        ("brew",      ["brew"]),
    ]

    static func analyze(_ cats: [CacheCategory], lang: AppLanguage) -> Result {
        var scores: [String: Int] = [:]
        for eco in ecosystems {
            let sum = cats.filter { eco.cats.contains($0.name) }.reduce(0) { $0 + $1.sizeKB }
            if sum > 0 { scores[eco.key] = sum }
        }
        guard let top = scores.max(by: { $0.value < $1.value }) else {
            return Result("🧹", tr("profile.title.clean", lang), tr("profile.sum.clean", lang))
        }
        let count = scores.count
        if count >= 6 {
            return Result("🧰", tr("profile.title.polyglot", lang), tr("profile.sum.polyglot", lang, count))
        }
        let m = meta(top.key)
        return Result(m.emoji, tr(m.titleKey, lang), tr(m.sumKey, lang, humanKB(top.value)))
    }

    /// 생태계 키 → (이모지, 별명 키, 멘트 키). 멘트는 %@ 에 용량이 들어감.
    private static func meta(_ key: String) -> (emoji: String, titleKey: String, sumKey: String) {
        switch key {
        case "node":      return ("🎨", "profile.title.node", "profile.sum.node")
        case "rust":      return ("🦀", "profile.title.rust", "profile.sum.rust")
        case "container": return ("🐳", "profile.title.container", "profile.sum.container")
        case "apple":     return ("🍎", "profile.title.apple", "profile.sum.apple")
        case "python":    return ("🐍", "profile.title.python", "profile.sum.python")
        case "ml":        return ("🤖", "profile.title.ml", "profile.sum.ml")
        case "jvm":       return ("☕", "profile.title.jvm", "profile.sum.jvm")
        case "go":        return ("🐹", "profile.title.go", "profile.sum.go")
        case "php":       return ("🐘", "profile.title.php", "profile.sum.php")
        case "dotnet":    return ("🟣", "profile.title.dotnet", "profile.sum.dotnet")
        case "deno":      return ("🦕", "profile.title.deno", "profile.sum.deno")
        case "dart":      return ("🎯", "profile.title.dart", "profile.sum.dart")
        case "webtest":   return ("🎭", "profile.title.webtest", "profile.sum.webtest")
        case "brew":      return ("🍺", "profile.title.brew", "profile.sum.brew")
        default:          return ("🧰", "profile.title.multi", "profile.sum.multi")
        }
    }

    /// 둘러보기용 페르소나 키 (실제 판정과 무관하게 모든 타입을 구경)
    static let galleryKeys = ["polyglot", "node", "rust", "container", "apple", "python",
                              "ml", "jvm", "go", "php", "dotnet", "deno", "dart", "webtest", "brew", "clean"]

    /// 둘러보기 항목 — 이모지 + 별명만 (설명은 실제로 그 성향이 됐을 때 보이는 "해금" 재미)
    static func galleryItem(_ key: String, lang: AppLanguage) -> (emoji: String, title: String) {
        switch key {
        case "clean":    return ("🧹", tr("profile.title.clean", lang))
        case "polyglot": return ("🧰", tr("profile.title.polyglot", lang))
        default:
            let m = meta(key)
            return (m.emoji, tr(m.titleKey, lang))
        }
    }

    // MARK: - 스택 분포

    struct EcoSlice: Identifiable { var id: String { name }; let name: String; let sizeKB: Int }

    /// 생태계별 용량(>0) 내림차순. 이름은 고유명사라 번역하지 않음.
    static func breakdown(_ cats: [CacheCategory]) -> [EcoSlice] {
        ecosystems.compactMap { eco in
            let sum = cats.filter { eco.cats.contains($0.name) }.reduce(0) { $0 + $1.sizeKB }
            return sum > 0 ? EcoSlice(name: ecoDisplayName(eco.key), sizeKB: sum) : nil
        }.sorted { $0.sizeKB > $1.sizeKB }
    }

    private static func ecoDisplayName(_ key: String) -> String {
        switch key {
        case "node":      return "Node"
        case "python":    return "Python"
        case "rust":      return "Rust"
        case "go":        return "Go"
        case "jvm":       return "JVM"
        case "apple":     return "Apple"
        case "php":       return "PHP"
        case "dotnet":    return ".NET"
        case "deno":      return "Deno"
        case "dart":      return "Dart"
        case "container": return "Containers"
        case "ml":        return "ML"
        case "webtest":   return "Web test"
        case "brew":      return "Homebrew"
        default:          return key
        }
    }

    // MARK: - 배지(업적)

    struct Badge: Identifiable { var id: String { title }; let emoji: String; let title: String }

    /// 캐시 구성·누적 회수량으로 획득한 배지
    struct BadgeDef { let key: String; let emoji: String; let test: ([CacheCategory], Int) -> Bool }

    private static func catSize(_ cats: [CacheCategory], _ ns: Set<String>) -> Int {
        cats.filter { ns.contains($0.name) }.reduce(0) { $0 + $1.sizeKB }
    }

    /// 전체 배지 정의 (조건 충족분만 표시). 총 개수 = allBadges.count
    static let allBadges: [BadgeDef] = [
        .init(key: "multimanager", emoji: "🧩", test: { c, _ in c.filter { ["npm","yarn","pnpm","bun"].contains($0.name) && $0.sizeKB > 0 }.count >= 2 }),
        .init(key: "container",    emoji: "🐳", test: { c, _ in catSize(c, ["docker","colima"]) > 0 }),
        .init(key: "compile",      emoji: "🦀", test: { c, _ in catSize(c, ["cargo","rustup-targets"]) > 200 * 1024 }),
        .init(key: "ml",           emoji: "🤖", test: { c, _ in catSize(c, ["huggingface"]) > 0 }),
        .init(key: "e2e",          emoji: "🎭", test: { c, _ in catSize(c, ["playwright"]) > 0 }),
        .init(key: "apple",        emoji: "🍎", test: { c, _ in catSize(c, ["xcode","swiftpm","cocoapods","xcode-sim"]) > 0 }),
        .init(key: "hoarder",      emoji: "📦", test: { c, _ in breakdown(c).count >= 5 }),
        .init(key: "cleanup",      emoji: "🧹", test: { _, r in r > 1024 * 1024 }),
        .init(key: "diskhog",      emoji: "🗄️", test: { c, _ in c.reduce(0) { $0 + $1.sizeKB } > 10 * 1024 * 1024 }),
        .init(key: "polymaster",   emoji: "🌐", test: { c, _ in breakdown(c).count >= 8 }),
        .init(key: "vmheavy",      emoji: "🏗️", test: { c, _ in catSize(c, ["docker","colima"]) > 3 * 1024 * 1024 }),
        .init(key: "datasci",      emoji: "📊", test: { c, _ in catSize(c, ["pip"]) > 0 && catSize(c, ["huggingface"]) > 0 }),
        .init(key: "early",        emoji: "🚀", test: { c, _ in catSize(c, ["deno","bun"]) > 0 }),
        .init(key: "builder",      emoji: "🔨", test: { c, _ in [Set(["cargo","rustup-targets"]), Set(["go"]), Set(["gradle","maven"])].filter { catSize(c, $0) > 0 }.count >= 2 }),
        .init(key: "crossplat",    emoji: "🎯", test: { c, _ in catSize(c, ["pub"]) > 0 }),
        .init(key: "cleanmaster",  emoji: "🏆", test: { _, r in r > 10 * 1024 * 1024 }),
    ]

    /// 시즌제 — 만료(획득 후 기간 경과)된 배지는 제거하고, 비활성 배지는 현재 조건으로 재판정.
    /// earned: [배지키: 획득 epoch초]. now/periodDays 기준으로 갱신된 맵을 반환.
    static func refreshEarned(_ earned: [String: Double], cats: [CacheCategory], reclaimedKB: Int,
                              now: Double, periodDays: Int) -> [String: Double] {
        let span = Double(periodDays) * 86_400
        var result = earned
        for def in allBadges {
            let active = result[def.key].map { now - $0 < span } ?? false
            if !active {                                   // 만료 or 미획득 → 재판정
                if def.test(cats, reclaimedKB) { result[def.key] = now }
                else { result[def.key] = nil }
            }                                              // active면 시각 유지(기간 내 보존)
        }
        return result
    }

    /// 기간 내(활성) 배지 키 목록 (언어 무관 — 표시 시점에 tr 적용)
    static func activeKeys(_ earned: [String: Double], now: Double, periodDays: Int) -> [String] {
        let span = Double(periodDays) * 86_400
        return allBadges.compactMap { def in
            guard let t = earned[def.key], now - t < span else { return nil }
            return def.key
        }
    }

    /// 배지 키 → 이모지
    static func emoji(forKey key: String) -> String {
        allBadges.first { $0.key == key }?.emoji ?? "🏅"
    }
}

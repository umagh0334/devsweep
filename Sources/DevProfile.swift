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
        ("python",    ["pip"]),
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
    static func badges(_ cats: [CacheCategory], reclaimedKB: Int, lang: AppLanguage) -> [Badge] {
        func size(_ ns: Set<String>) -> Int { cats.filter { ns.contains($0.name) }.reduce(0) { $0 + $1.sizeKB } }
        func has(_ ns: Set<String>) -> Bool { size(ns) > 0 }
        var out: [Badge] = []
        let nodeMgrs = cats.filter { ["npm", "yarn", "pnpm", "bun"].contains($0.name) && $0.sizeKB > 0 }.count
        if nodeMgrs >= 2 { out.append(Badge(emoji: "🧩", title: tr("badge.multimanager", lang))) }
        if has(["docker", "colima"]) { out.append(Badge(emoji: "🐳", title: tr("badge.container", lang))) }
        if size(["cargo", "rustup-targets"]) > 200 * 1024 { out.append(Badge(emoji: "🦀", title: tr("badge.compile", lang))) }
        if has(["huggingface"]) { out.append(Badge(emoji: "🤖", title: tr("badge.ml", lang))) }
        if has(["playwright"]) { out.append(Badge(emoji: "🎭", title: tr("badge.e2e", lang))) }
        if has(["xcode", "swiftpm", "cocoapods", "xcode-sim"]) { out.append(Badge(emoji: "🍎", title: tr("badge.apple", lang))) }
        if breakdown(cats).count >= 5 { out.append(Badge(emoji: "📦", title: tr("badge.hoarder", lang))) }
        if reclaimedKB > 1024 * 1024 { out.append(Badge(emoji: "🧹", title: tr("badge.cleanup", lang))) }
        return out
    }
}

import SwiftUI

/// KB → 사람이 읽는 단위. 여러 모델/뷰가 공유 (CacheCategory·PathEntry·ContentView).
func humanKB(_ kb: Int) -> String {
    let d = Double(kb)
    if d >= 1_048_576 { return String(format: "%.1f GB", d / 1_048_576) }
    if d >= 1024      { return String(format: "%.0f MB", d / 1024) }
    if kb <= 0        { return "—" }
    return "\(kb) KB"
}

/// devsweep `--json` 한 항목. 리스트 행에 대응.
struct CacheCategory: Identifiable, Decodable {
    let name: String
    let sizeKB: Int
    let kind: String
    let heavy: Bool
    /// 보호 목록(~/.config/devsweep/config) 소속 — 정리/관여 안 함
    let protected: Bool

    /// 사용자가 정리 대상으로 체크했는지 (UI 상태, JSON엔 없음)
    var selected: Bool = false

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, kind, heavy, protected
        case sizeKB = "size_kb"
    }

    var sizeHuman: String { humanKB(sizeKB) }

    /// 실제 용량 합산/막대에 잡히는 카테고리인지 (docker/rustup 등은 0이라 제외)
    var hasSize: Bool { sizeKB > 0 }

    /// 카테고리에 대응하는 Solar 아이콘 파일명 (Resources/icons/<name>.svg)
    var iconName: String {
        switch name {
        case "gradle", "cargo", "maven", "go": return "box"
        case "npm", "yarn", "pnpm", "bun", "pip", "cocoapods", "swiftpm", "composer", "nuget", "deno", "pub": return "package"
        case "brew":                          return "brew"
        case "docker", "colima":              return "server"
        case "xcode", "xcode-sim":            return "code"
        case "playwright":                    return "globe"
        case "huggingface":                   return "database"
        case "rustup-targets":                return "settings"
        default:                              return "folder"
        }
    }
}

/// 상세보기의 경로별 용량 한 줄 (devsweep detail의 paths[] 요소).
struct PathEntry: Decodable, Identifiable {
    let path: String
    let sizeKB: Int
    let exists: Bool
    let readable: Bool

    var id: String { path }

    /// 존재하는데 못 읽음 = TCC 권한 문제 (없는 경로와 구분)
    var needsPermission: Bool { exists && !readable }
    var sizeHuman: String { humanKB(sizeKB) }

    enum CodingKeys: String, CodingKey {
        case path, exists, readable
        case sizeKB = "size_kb"
    }
}

/// devsweep `detail <cat>` 단일 객체. 펼침 상세뷰에 대응.
struct CategoryDetail: Decodable {
    let name: String
    let sizeKB: Int
    let kind: String
    let heavy: Bool
    let protected: Bool         // 보호 목록 소속 여부
    let safety: String          // "safe" | "caution"
    let safetyNote: String
    let regenCost: String       // "low" | "med" | "high"
    let regenNote: String
    let method: String          // "native" | "rm"
    let command: String
    let fallback: String?
    let nativeAvailable: Bool
    let needsTCC: Bool
    let extra: String
    let paths: [PathEntry]

    enum CodingKeys: String, CodingKey {
        case name, kind, heavy, protected, safety, method, command, fallback, extra, paths
        case sizeKB = "size_kb"
        case safetyNote = "safety_note"
        case regenCost = "regen_cost"
        case regenNote = "regen_note"
        case nativeAvailable = "native_available"
        case needsTCC = "needs_tcc"
    }

    // ── 표시용 계산 속성 ──
    var safetyLabel: String { safety == "caution" ? "주의" : "안전" }
    var safetyColor: Color { safety == "caution" ? .orange : .green }
    var safetyIcon: String { safety == "caution" ? "exclamationmark.triangle.fill" : "checkmark.shield.fill" }

    var regenCostLabel: String {
        switch regenCost {
        case "low":  return "저비용"
        case "high": return "고비용"
        default:     return "중비용"
        }
    }
    var regenCostColor: Color {
        switch regenCost {
        case "low":  return .green
        case "high": return .orange
        default:     return .yellow
        }
    }
}

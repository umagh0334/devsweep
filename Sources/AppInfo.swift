import Foundation

/// 앱 메타 정보 — 버전·제작자·저작권·GitHub 저장소.
/// repoOwner/repoName 은 개인 비공개 repo. 공개 릴리스 전까지 releases/latest 는 404 →
/// UpdateChecker 가 .noRelease("릴리스 없음")로 분기. 공개 + 릴리스 생성 시 자동으로 정상 동작.
enum AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }
    static let author  = "umagh0334"
    static let license = "MIT License"

    static let repoOwner = "umagh0334"    // 개인 GitHub 계정
    static let repoName  = "devsweep"

    static var repoURL: URL { URL(string: "https://github.com/\(repoOwner)/\(repoName)")! }
    static var releasesURL: URL { URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases")! }
    static var latestReleaseAPI: URL { URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")! }
}

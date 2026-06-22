import Foundation

/// 앱 메타 정보 — 버전·제작자·저작권·GitHub 저장소.
/// ⚠️ repoOwner / repoName / author 는 추측값. 실제 값으로 확인·수정 필요.
enum AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }
    static let author  = "Wyatt"
    static let license = "MIT License"

    static let repoOwner = "umagh0334"    // 개인 GitHub 계정
    static let repoName  = "devsweep"

    static var repoURL: URL { URL(string: "https://github.com/\(repoOwner)/\(repoName)")! }
    static var releasesURL: URL { URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases")! }
    static var latestReleaseAPI: URL { URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")! }
}

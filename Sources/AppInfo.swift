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

    /// 자동 업데이트 신뢰 앵커 — 릴리스 zip 서명 검증용 Ed25519 공개키(base64, 32바이트 raw).
    /// 대응 개인키는 repo 밖(`~/.config/devsweep/update_ed25519.key`)에만 존재하며 `build.sh --release`
    /// 가 zip 을 서명해 `.app.zip.sig` asset 을 만든다. ad-hoc 서명은 누구나 재서명 가능하므로,
    /// **이 키 검증이 실제 신뢰경계**다 — 서명이 없거나 불일치면 설치를 거부한다.
    static let updatePublicKeyB64 = "IPa2UPf+xOmL5sjEzIqLpV/3IXf+BKL1WhxHp8iVnyE="

    static var repoURL: URL { URL(string: "https://github.com/\(repoOwner)/\(repoName)")! }
    static var releasesURL: URL { URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases")! }
    static var latestReleaseAPI: URL { URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")! }
}

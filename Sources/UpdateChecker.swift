import Foundation
import Observation

/// GitHub Releases 기반 업데이트 확인. releases/latest 의 tag_name 을 현재 버전과 비교.
/// 자동 다운로드/설치는 하지 않고, 새 버전이면 릴리스 페이지 URL 을 제공한다.
@MainActor
@Observable
final class UpdateChecker {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case noRelease   // releases/latest 404 — 아직 공개 릴리스 없음(또는 비공개 repo)
        case updateAvailable(tag: String, url: URL, asset: URL?)   // asset = .app.zip 직접 다운로드 URL
        case failed
    }
    var status: Status = .idle

    func check() async {
        status = .checking
        do {
            var req = URLRequest(url: AppInfo.latestReleaseAPI)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.timeoutInterval = 10
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { status = .failed; return }
            // 404 = 릴리스 미존재(또는 비공개). 일반 네트워크 실패와 구분해 별도 UX 로 안내.
            if http.statusCode == 404 { status = .noRelease; return }
            guard http.statusCode == 200 else { status = .failed; return }
            let rel = try JSONDecoder().decode(GHRelease.self, from: data)
            let latest = rel.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            let url = URL(string: rel.htmlURL) ?? AppInfo.releasesURL
            // .app.zip asset 의 직접 다운로드 URL (자동 설치용). 없으면 nil → 릴리스 페이지 링크만.
            let asset = rel.assets.first { $0.name.hasSuffix(".app.zip") }
                .flatMap { URL(string: $0.browserDownloadURL) }
            status = Self.isNewer(latest, than: AppInfo.version)
                ? .updateAvailable(tag: rel.tagName, url: url, asset: asset)
                : .upToDate
        } catch {
            status = .failed
        }
    }

    /// semver 비교 ("1.2.0" > "1.1.3"). 컴포넌트별 정수 비교, 길이 다르면 0 패딩.
    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0 ..< max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}

private struct GHRelease: Decodable {
    let tagName: String
    let htmlURL: String
    let assets: [Asset]
    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: String
        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }
}

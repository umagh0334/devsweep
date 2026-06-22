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
        case updateAvailable(tag: String, url: URL)
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
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                status = .failed; return
            }
            let rel = try JSONDecoder().decode(GHRelease.self, from: data)
            let latest = rel.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            let url = URL(string: rel.htmlURL) ?? AppInfo.releasesURL
            status = Self.isNewer(latest, than: AppInfo.version)
                ? .updateAvailable(tag: rel.tagName, url: url)
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
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}

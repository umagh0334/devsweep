import SwiftUI
import AppKit

/// 번들 Resources/icons/*.png (Iconify Solar 아이콘)을 SwiftUI Image로 로드.
/// PNG는 검은 실루엣 + 알파라서 isTemplate=true로 두면 foregroundStyle 틴팅이 먹는다.
enum Icons {
    /// 틴팅은 호출측에서 `.foregroundStyle(...)`로 지정.
    static func view(_ name: String, size: CGFloat) -> some View {
        image(name)
            .resizable().interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
    }

    /// NSImage 로드 + isTemplate 설정은 ViewBuilder 밖(일반 함수)에서 수행. 실패 시 SF Symbol 폴백.
    /// macOS 26의 NSImage는 SVG를 벡터로 렌더하지만 intrinsic size가 1×1(width="1em")이라
    /// resizable이 제대로 동작하도록 size를 명시적으로 키워준다.
    private static func image(_ name: String) -> Image {
        if let url = Bundle.main.url(forResource: name, withExtension: "svg", subdirectory: "icons"),
           let ns = NSImage(contentsOf: url) {
            ns.isTemplate = true
            ns.size = NSSize(width: 64, height: 64)
            return Image(nsImage: ns)
        }
        return Image(systemName: "square.dashed")
    }
}

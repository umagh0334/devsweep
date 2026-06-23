import SwiftUI

/// DevSweep 디자인 토큰 — "Sweep Console".
/// 색은 장식이 아니라 정보다: sweep(정리·회수 가능) / heavy(재설치 비쌈) / guard(보호 중).
enum Theme {
    // ── 시맨틱 액센트 (라이트·다크 양쪽에서 또렷한 채도) ──
    static let sweep = Color(red: 0.10, green: 0.72, blue: 0.66)     // 틸-아쿠아: 정리·회수·선택
    static let heavy = Color(red: 0.20, green: 0.48, blue: 0.92)     // 블루: 재다운로드 비쌈(heavy) — sweep 틸과 구분되는 남색기
    static let guardTone = Color(red: 0.56, green: 0.59, blue: 0.66) // 슬레이트: 보호
    static let danger = Color(red: 0.89, green: 0.32, blue: 0.30)    // 레드: 에러·실패 (heavy와 분리 — 에러는 경고색 유지)

    // ── 분포 스택 바 팔레트 (용량순 세그먼트에 순환 배정) ──
    static let palette: [Color] = [
        Color(red: 0.10, green: 0.72, blue: 0.66),  // teal
        Color(red: 0.31, green: 0.56, blue: 0.93),  // blue
        Color(red: 0.55, green: 0.46, blue: 0.92),  // indigo
        Color(red: 0.86, green: 0.42, blue: 0.66),  // pink
        Color(red: 0.96, green: 0.62, blue: 0.26),  // amber
        Color(red: 0.36, green: 0.74, blue: 0.49),  // green
        Color(red: 0.43, green: 0.69, blue: 0.85),  // sky
        Color(red: 0.79, green: 0.53, blue: 0.36),  // clay
    ]
    static func segment(_ i: Int) -> Color { palette[i % palette.count] }

    /// 카테고리 상태에 따른 용량 바/강조 색
    static func barColor(heavy: Bool, protected: Bool) -> Color {
        if protected { return guardTone }
        return heavy ? Theme.heavy : sweep
    }
}

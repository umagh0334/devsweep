#!/usr/bin/env bash
#
# build.sh — Sources/*.swift 를 컴파일해 DevSweep.app 번들을 생성한다.
#   요구: Xcode Command Line Tools (swiftc). Xcode 정식판 불필요.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
NAME="DevSweep"
APP="$ROOT/$NAME.app"

echo "▶ DevSweep 빌드"

# 1) 이전 번들 제거 후 골격 생성
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# 2) SwiftUI 소스 컴파일 (@main 이라 -parse-as-library 필요)
echo "  · swiftc 컴파일"
swiftc -O -parse-as-library \
    "$ROOT/Sources/"*.swift \
    -o "$APP/Contents/MacOS/$NAME"

# 3) Info.plist + 검증된 CLI 엔진 + Solar 아이콘을 번들에 동봉 (self-contained)
echo "  · Info.plist / devsweep 엔진 / 아이콘 동봉"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/devsweep" "$APP/Contents/Resources/devsweep"
chmod +x "$APP/Contents/Resources/devsweep"
cp -R "$ROOT/Resources/icons" "$APP/Contents/Resources/icons"

# 3b) 지원 언어 선언용 빈 .lproj — AppKit 표준 메뉴(File/Edit/Window/Help…)를 시스템 언어로 번역
echo "  · 로컬라이제이션 .lproj 생성"
for lang in en ko ja zh-Hans zh-Hant th vi it fr es pt hr; do
  mkdir -p "$APP/Contents/Resources/$lang.lproj"
  : > "$APP/Contents/Resources/$lang.lproj/Localizable.strings"
done

# 4) ad-hoc 코드사이닝 (개인용 — Gatekeeper 우회는 우클릭>열기)
echo "  · ad-hoc 코드사이닝"
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "    (사이닝 생략됨)"

echo "✓ 완료: $APP"
echo "  실행:  open '$APP'"

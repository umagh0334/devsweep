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

# 2) SwiftUI 소스 컴파일 — universal binary (arm64 + x86_64) 로 Apple Silicon·Intel Mac 모두 지원.
#    @main 이라 -parse-as-library 필요. -target 으로 minos 를 Info.plist(LSMinimumSystemVersion=14.0)와
#    일치(없으면 빌드머신 OS 가 minos 로 박혀 구형 macOS 에서 "손상됨" 거부됨). 각 아키텍처를 따로
#    컴파일한 뒤 lipo 로 fat binary 결합 — x86_64 는 arm64 머신에서도 크로스 컴파일된다(SDK가 universal).
echo "  · swiftc 컴파일 (arm64)"
swiftc -O -parse-as-library -target arm64-apple-macos14.0 \
    "$ROOT/Sources/"*.swift -o "$APP/Contents/MacOS/$NAME.arm64"
echo "  · swiftc 컴파일 (x86_64)"
swiftc -O -parse-as-library -target x86_64-apple-macos14.0 \
    "$ROOT/Sources/"*.swift -o "$APP/Contents/MacOS/$NAME.x86_64"
echo "  · lipo 결합 (universal)"
lipo -create -output "$APP/Contents/MacOS/$NAME" \
    "$APP/Contents/MacOS/$NAME.arm64" "$APP/Contents/MacOS/$NAME.x86_64"
rm -f "$APP/Contents/MacOS/$NAME.arm64" "$APP/Contents/MacOS/$NAME.x86_64"

# 3) Info.plist + 검증된 CLI 엔진 + Solar 아이콘을 번들에 동봉 (self-contained)
echo "  · Info.plist / devsweep 엔진 / 아이콘 동봉"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/devsweep" "$APP/Contents/Resources/devsweep"
chmod +x "$APP/Contents/Resources/devsweep"
# 아이콘은 .svg 만 골라 복사 — 폴더째(cp -R) 넣으면 .omc/.DS_Store 같은 잡파일이
# 번들에 섞여 들어가 ad-hoc 코드사이닝 무결성을 깬다.
mkdir -p "$APP/Contents/Resources/icons"
cp "$ROOT/Resources/icons/"*.svg "$APP/Contents/Resources/icons/"

# 3b) 지원 언어 선언용 빈 .lproj — AppKit 표준 메뉴(File/Edit/Window/Help…)를 시스템 언어로 번역
echo "  · 로컬라이제이션 .lproj 생성"
for lang in en ko ja zh-Hans zh-Hant th vi it fr es pt hr de pl id; do
  mkdir -p "$APP/Contents/Resources/$lang.lproj"
  : > "$APP/Contents/Resources/$lang.lproj/Localizable.strings"
done

# 4) ad-hoc 코드사이닝 (개인용 — Gatekeeper 우회는 우클릭>열기)
echo "  · ad-hoc 코드사이닝"
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "    (사이닝 생략됨)"

# 5) 릴리스용 zip (--zip / --release 플래그 시) — GitHub 릴리스 asset · 자체 업데이트 다운로드용.
#    ditto 로 앱 번들 심볼릭링크/서명 보존 압축 (일반 zip 으론 깨질 수 있음).
#    --norsrc --noextattr --noqtn: 확장속성(특히 Ventura+ 가 자동으로 붙이는 com.apple.provenance)을
#    아카이브에 넣지 않아 zip 안에 ._* AppleDouble 잡파일이 안 생긴다. ad-hoc 서명은 _CodeSignature/
#    바이너리에 저장돼 xattr 와 무관 → 라운드트립 후에도 codesign --verify 통과(실측 확인).
case " $* " in
  *" --zip "*|*" --release "*)
    VER=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist" 2>/dev/null || echo dev)
    ZIP="$ROOT/DevSweep-$VER.app.zip"
    echo "  · 릴리스 zip 생성 (v$VER)"
    rm -f "$ROOT"/DevSweep-*.app.zip
    ditto -c -k --keepParent --norsrc --noextattr --noqtn "$APP" "$ZIP"
    echo "✓ zip: $ZIP ($(du -h "$ZIP" | awk '{print $1}' | tr -d ' '))"

    # 6) Ed25519 서명 — 0.1.4+ 앱은 서명 없는/불일치 업데이트를 거부하므로 릴리스에 .sig 는 필수.
    #    개인키는 repo 밖(~/.config/devsweep)에만 존재. 서명 후 **앱에 박힌 공개키로 자체 검증**해
    #    키 불일치를 릴리스 전에 잡는다.
    KEY="$HOME/.config/devsweep/update_ed25519.key"
    rm -f "$ROOT"/DevSweep-*.app.zip.sig
    if [ ! -f "$KEY" ]; then
      echo "✗ 업데이트 서명 개인키 없음: $KEY" >&2
      echo "  (생성: swift tools/ed25519.swift keygen → PRIVATE 을 이 경로에 저장, chmod 600)" >&2
      exit 1
    fi
    echo "  · Ed25519 서명"
    swift "$ROOT/tools/ed25519.swift" sign "$KEY" "$ZIP" > "$ZIP.sig" || { echo "✗ 서명 실패" >&2; exit 1; }
    PUB=$(grep -oE 'updatePublicKeyB64 = "[^"]+"' "$ROOT/Sources/AppInfo.swift" | sed 's/.*"\(.*\)"/\1/')
    swift "$ROOT/tools/ed25519.swift" verify "$PUB" "$ZIP.sig" "$ZIP" >/dev/null 2>&1 \
      || { echo "✗ 서명이 앱 공개키(AppInfo.updatePublicKeyB64)와 불일치 — 릴리스 중단" >&2; exit 1; }
    echo "✓ sig: $ZIP.sig (앱 공개키로 검증됨)"
    ;;
esac

echo "✓ 완료: $APP"
echo "  실행:  open '$APP'"

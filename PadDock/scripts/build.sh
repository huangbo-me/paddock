#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
output_dir="${PADDOCK_DIST_DIR:-$project_dir/dist}"
mkdir -p "$output_dir"
mkdir -p .build/app .build/modules "$output_dir/PadDock.app/Contents/MacOS" "$output_dir/PadDock.app/Contents/Resources"
xcrun clang -fobjc-arc -Wall -Wextra -Werror -mmacosx-version-min=14.0 \
  -c Sources/Bridge/PadDockBridge.m -o .build/app/Bridge.o
xcrun swiftc -swift-version 5 -warnings-as-errors -parse-as-library -target arm64-apple-macosx14.0 \
  -module-cache-path .build/modules -import-objc-header Sources/Bridge/PadDockBridge.h \
  Sources/Core/*.swift Sources/Storage/*.swift Sources/App/*.swift .build/app/Bridge.o \
  -framework Foundation -framework AppKit -framework SwiftUI -framework ServiceManagement \
  -framework IOKit -framework CoreGraphics -framework Security -framework CryptoKit -framework LocalAuthentication -o "$output_dir/PadDock.app/Contents/MacOS/PadDock"
cp Resources/Info.plist "$output_dir/PadDock.app/Contents/Info.plist"
cp Resources/Commerce.json "$output_dir/PadDock.app/Contents/Resources/Commerce.json"
xcrun swiftc -swift-version 5 -module-cache-path .build/modules scripts/Icon.swift -o .build/app/make-icon
.build/app/make-icon .build/app/AppIcon.iconset
iconutil -c icns .build/app/AppIcon.iconset -o "$output_dir/PadDock.app/Contents/Resources/AppIcon.icns"
signing_identity="${PADDOCK_SIGN_IDENTITY:--}"
# The Documents file provider can add FinderInfo to freshly built .app directories.
# Strip only signing-incompatible metadata from our generated bundle, never quarantine.
xattr -dr com.apple.FinderInfo "$output_dir/PadDock.app" 2>/dev/null || true
xattr -dr com.apple.ResourceFork "$output_dir/PadDock.app" 2>/dev/null || true
codesign --force --options runtime --sign "$signing_identity" "$output_dir/PadDock.app"
codesign --verify --strict --verbose=2 "$output_dir/PadDock.app"
plutil -lint "$output_dir/PadDock.app/Contents/Info.plist"
ditto -c -k --sequesterRsrc --keepParent "$output_dir/PadDock.app" "$output_dir/PadDock-0.2.0-arm64.zip"
printf 'Built %s/PadDock.app\n' "$output_dir"

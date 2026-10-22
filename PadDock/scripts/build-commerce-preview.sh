#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
preview_dir="${PADDOCK_PREVIEW_PATH:-/private/tmp/PadDock Commerce Preview.app}"
mkdir -p "$preview_dir/Contents/MacOS" "$preview_dir/Contents/Resources"
xcrun clang -Wall -Wextra -Werror -mmacosx-version-min=14.0 -I Sources/KeychainSupport/include -c Sources/KeychainSupport/PadDockKeychainSupport.c -o .build/keychain-support.o
xcrun swiftc -swift-version 5 -warnings-as-errors -parse-as-library -module-cache-path .build/modules \
 -import-objc-header Sources/KeychainSupport/include/PadDockKeychainSupport.h .build/keychain-support.o \
 Sources/Core/Commerce*.swift Sources/Storage/*.swift Sources/App/CommerceStore.swift \
 Sources/App/CommerceView.swift Sources/App/PrimaryStyle.swift Tests/Preview/Main.swift \
 -framework AppKit -framework SwiftUI -framework Security -framework LocalAuthentication \
 -o "$preview_dir/Contents/MacOS/Preview"
cp Resources/Commerce.json "$preview_dir/Contents/Resources/Commerce.json"
cat > "$preview_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Preview</string>
<key>CFBundleIdentifier</key><string>app.paddock.commerce-preview</string>
<key>CFBundleName</key><string>PadDock Commerce Preview</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
xattr -dr com.apple.FinderInfo "$preview_dir" 2>/dev/null || true
xattr -dr com.apple.ResourceFork "$preview_dir" 2>/dev/null || true
codesign --force --sign - "$preview_dir"

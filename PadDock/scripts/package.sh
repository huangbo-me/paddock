#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
output_dir="${PADDOCK_DIST_DIR:-$project_dir/dist}"
mkdir -p "$output_dir"
staging_dir="$(mktemp -d /private/tmp/paddock-package.XXXXXX)"
trap 'rm -rf "$staging_dir"' EXIT
ditto "$output_dir/PadDock.app" "$staging_dir/PadDock.app"
# File-provider metadata is not signed content; preserve all security attributes.
xattr -dr com.apple.FinderInfo "$staging_dir/PadDock.app" 2>/dev/null || true
xattr -dr com.apple.ResourceFork "$staging_dir/PadDock.app" 2>/dev/null || true
codesign --verify --strict "$staging_dir/PadDock.app"
ditto -c -k --sequesterRsrc --keepParent "$staging_dir/PadDock.app" "$output_dir/PadDock-0.2.2-arm64.zip"
ln -s /Applications "$staging_dir/Applications"
hdiutil create -volname 'PadDock 0.2.2 Beta' -srcfolder "$staging_dir" -ov -format UDZO "$output_dir/PadDock-0.2.2-arm64.dmg"
hdiutil verify "$output_dir/PadDock-0.2.2-arm64.dmg"
(cd "$output_dir" && shasum -a 256 PadDock-0.2.2-arm64.dmg PadDock-0.2.2-arm64.zip > SHA256SUMS.txt)

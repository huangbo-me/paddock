#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="${PADDOCK_DIST_DIR:-$project_dir/dist}"
verification_dir="$(mktemp -d /private/tmp/paddock-verify.XXXXXX)"
mounted=0
cleanup() {
  if [ "$mounted" = 1 ]; then hdiutil detach "$verification_dir/mounted" >/dev/null; fi
  rm -rf "$verification_dir"
}
trap cleanup EXIT
mkdir -p "$verification_dir/zip" "$verification_dir/mounted"
(cd "$output_dir" && shasum -a 256 -c SHA256SUMS.txt)
ditto -x -k "$output_dir/PadDock-0.1.0-arm64.zip" "$verification_dir/zip"
codesign --verify --strict --verbose=2 "$verification_dir/zip/PadDock.app"
hdiutil attach -readonly -nobrowse -mountpoint "$verification_dir/mounted" "$output_dir/PadDock-0.1.0-arm64.dmg"
mounted=1
codesign --verify --strict --verbose=2 "$verification_dir/mounted/PadDock.app"
cmp "$verification_dir/zip/PadDock.app/Contents/MacOS/PadDock" "$verification_dir/mounted/PadDock.app/Contents/MacOS/PadDock"
test "$(readlink "$verification_dir/mounted/Applications")" = /Applications
test -s "$verification_dir/mounted/使用说明.md"
printf 'DMG and zip contents/signatures verified.\n'

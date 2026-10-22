#!/bin/bash
# Public release only: certificate and notary credentials remain in your Keychain.
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
output_dir="$(mktemp -d /private/tmp/paddock-release.XXXXXX)"
trap 'rm -rf "$output_dir"' EXIT
export PADDOCK_DIST_DIR="$output_dir"
: "${PADDOCK_SIGN_IDENTITY:?Set a Developer ID Application signing identity}"
: "${PADDOCK_NOTARY_PROFILE:?Set an existing notarytool Keychain profile name}"
case "$PADDOCK_SIGN_IDENTITY" in
  'Developer ID Application:'*) ;;
  *) printf 'Public releases require a Developer ID Application identity.\n' >&2; exit 1 ;;
esac
bash scripts/build.sh
xcrun notarytool submit "$output_dir/PadDock-0.2.1-arm64.zip" --keychain-profile "$PADDOCK_NOTARY_PROFILE" --wait
xcrun stapler staple "$output_dir/PadDock.app"
xcrun stapler validate "$output_dir/PadDock.app"
codesign --verify --strict "$output_dir/PadDock.app"
spctl --assess --type execute --verbose=2 "$output_dir/PadDock.app"
# Repackage the stapled app, then notarize/staple the disk image too.
ditto -c -k --sequesterRsrc --keepParent "$output_dir/PadDock.app" "$output_dir/PadDock-0.2.1-arm64.zip"
bash scripts/package.sh
codesign --sign "$PADDOCK_SIGN_IDENTITY" --timestamp "$output_dir/PadDock-0.2.1-arm64.dmg"
xcrun notarytool submit "$output_dir/PadDock-0.2.1-arm64.dmg" --keychain-profile "$PADDOCK_NOTARY_PROFILE" --wait
xcrun stapler staple "$output_dir/PadDock-0.2.1-arm64.dmg"
xcrun stapler validate "$output_dir/PadDock-0.2.1-arm64.dmg"
(cd "$output_dir" && shasum -a 256 PadDock-0.2.1-arm64.dmg PadDock-0.2.1-arm64.zip > SHA256SUMS.txt)

mkdir -p "$project_dir/dist"
ditto "$output_dir" "$project_dir/dist"

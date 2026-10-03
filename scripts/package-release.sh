#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

app="dist/Codex Usage Rings.app"
if [[ ! -d "$app" ]]; then
    printf '%s\n' 'Build the app first: bash scripts/build-app.sh' >&2
    exit 1
fi
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
architecture=$(/usr/bin/lipo -archs "$app/Contents/MacOS/CodexUsageRings")
case "$architecture" in
    arm64|x86_64) ;;
    'x86_64 arm64'|'arm64 x86_64') architecture=universal ;;
    *) printf 'Unsupported architecture: %s\n' "$architecture" >&2; exit 1 ;;
esac
codesign --verify --strict --verbose=2 "$app"

destination="dist/releases/v$version"
mkdir -p "$destination"
archive="Codex-Usage-Rings-v$version-macos-$architecture.zip"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app" "$destination/$archive"
(cd "$destination" && /usr/bin/shasum -a 256 "$archive" > SHA256SUMS.txt)
printf '%s\n' "$destination/$archive" "$destination/SHA256SUMS.txt"

#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
mkdir -p dist
work=$(mktemp -d "$(pwd)/dist/build.XXXXXX")
trap 'rm -rf "$work"' EXIT
app="$work/Codex Usage Rings.app"
framework=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Frameworks"
cp .build/release/CodexUsageRings "$app/Contents/MacOS/CodexUsageRings"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
# Preserve framework symlinks and the upstream signatures on Sparkle's helpers.
/usr/bin/ditto "$framework" "$app/Contents/Frameworks/Sparkle.framework"
cp .build/checkouts/Sparkle/LICENSE "$app/Contents/Resources/Sparkle-LICENSE.txt"
codesign --force --sign - "$app"
codesign --verify --deep --strict --verbose=2 "$app"
destination="$(pwd)/dist/Codex Usage Rings.app"
if [[ -d "$destination" ]]; then mv "$destination" "$work/previous.app"; fi
if ! mv "$app" "$destination"; then
    if [[ -d "$work/previous.app" ]]; then mv "$work/previous.app" "$destination"; fi
    exit 1
fi
printf '%s\n' "$destination"

#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
app="$(pwd)/dist/Codex Usage Rings.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/CodexUsageRings "$app/Contents/MacOS/CodexUsageRings"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$app"
printf '%s\n' "$app"

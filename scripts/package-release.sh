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
codesign --verify --deep --strict --verbose=2 "$app"
sparkle_bin="${SPARKLE_BIN:-.local/sparkle-tools/bin}"
if [[ ! -x "$sparkle_bin/generate_appcast" ]]; then
    printf '%s\n' 'Install signing tools first: bash scripts/setup-sparkle-tools.sh' >&2
    exit 1
fi
account=dev.local.codex-usage-rings
public_key=$("$sparkle_bin/generate_keys" --account "$account" -p)
embedded_key=$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$app/Contents/Info.plist")
if [[ "$public_key" != "$embedded_key" ]]; then
    printf '%s\n' 'The update signing key does not match the public key embedded in the app.' >&2
    exit 1
fi

destination="dist/releases/v$version"
mkdir -p "$destination"
basename="Codex-Usage-Rings-v$version-macos-$architecture"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/image" "$work/updates"
/usr/bin/ditto "$app" "$work/image/Codex Usage Rings.app"
ln -s /Applications "$work/image/Applications"
cp Resources/AppIcon.icns "$work/image/.VolumeIcon.icns"
touch "$work/image/.metadata_never_index"
if command -v SetFile >/dev/null; then
    SetFile -a C "$work/image"
fi

# hdiutil is available on the project's minimum supported macOS 13.
# Create away from the final path so a failure cannot replace a valid package.
/usr/bin/hdiutil create -volname "Codex Usage Rings" -srcfolder "$work/image" \
    -fs HFS+ -format UDZO -nospotlight "$work/$basename.dmg"
/usr/bin/hdiutil verify "$work/$basename.dmg"

# Use a ZIP for in-app updates; users can keep installing from the DMG.
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app" "$work/updates/$basename.zip"
if [[ -f appcast.xml ]]; then cp appcast.xml "$work/updates/appcast.xml"; fi
cp "docs/releases/v$version.md" "$work/updates/$basename.md"
"$sparkle_bin/generate_appcast" --account "$account" --maximum-deltas 0 \
    --download-url-prefix "https://github.com/yangbo-s/codex-usage-rings/releases/download/v$version/" \
    --link "https://github.com/yangbo-s/codex-usage-rings/releases/tag/v$version" \
    --embed-release-notes "$work/updates"
test -s "$work/updates/appcast.xml"
mv "$work/$basename.dmg" "$destination/$basename.dmg"
mv "$work/updates/$basename.zip" "$destination/$basename.zip"
cp "$work/updates/appcast.xml" "$destination/appcast.xml"
cp "$work/updates/appcast.xml" appcast.xml
(
    cd "$destination"
    /usr/bin/shasum -a 256 "$basename.dmg" "$basename.zip" appcast.xml > SHA256SUMS.txt
)
printf '%s\n' "$destination/$basename.dmg" "$destination/$basename.zip" "$destination/appcast.xml" "$destination/SHA256SUMS.txt"

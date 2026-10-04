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
basename="Codex-Usage-Rings-v$version-macos-$architecture"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/image"
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
mv "$work/$basename.dmg" "$destination/$basename.dmg"
(
    cd "$destination"
    /usr/bin/shasum -a 256 "$basename.dmg" > SHA256SUMS.txt
    # Keep the checksum for the previously published ZIP, without repacking it.
    if [[ -f "$basename.zip" ]]; then
        /usr/bin/shasum -a 256 "$basename.zip" >> SHA256SUMS.txt
    fi
)
printf '%s\n' "$destination/$basename.dmg" "$destination/SHA256SUMS.txt"

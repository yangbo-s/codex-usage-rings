#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Keep the generated master intact; only resize for macOS icon packaging.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
iconset="$work/AppIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Resources/Brand/usage-rings-logo.png \
        --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" Resources/Brand/usage-rings-logo.png \
        --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil --convert icns "$iconset" --output Resources/AppIcon.icns
printf '%s\n' 'Resources/AppIcon.icns'

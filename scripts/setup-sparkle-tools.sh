#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Matches the pinned SwiftPM dependency. Only public build tools are downloaded.
version=2.10.0
checksum=c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c
destination=".local/sparkle-tools"
mkdir -p "$destination"
archive="$destination/Sparkle-$version.tar.xz"
if [[ ! -f "$archive" ]] || ! printf '%s  %s\n' "$checksum" "$archive" | shasum -a 256 -c - >/dev/null 2>&1; then
    download=$(mktemp "$destination/download.XXXXXX")
    trap 'rm -f "$download"' EXIT
    curl --fail --location --retry 2 "https://github.com/sparkle-project/Sparkle/releases/download/$version/Sparkle-$version.tar.xz" -o "$download"
    printf '%s  %s\n' "$checksum" "$download" | shasum -a 256 -c -
    mv "$download" "$archive"
fi
printf '%s  %s\n' "$checksum" "$archive" | shasum -a 256 -c -
tar -xf "$archive" -C "$destination"
printf 'Sparkle tools: %s/bin\n' "$destination"

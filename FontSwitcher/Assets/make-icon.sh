#!/bin/zsh
# Regenerates FontSwitcher.png / .iconset / .icns from GenerateIcon.swift.
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/FontSwitcher-icon.XXXXXX)
trap 'rm -rf "$stage"' EXIT
CLANG_MODULE_CACHE_PATH="$stage/cache" xcrun swift GenerateIcon.swift .
rm -rf FontSwitcher.iconset; mkdir FontSwitcher.iconset
for size in 16 32 128 256 512; do
  sips -z $size $size FontSwitcher.png --out FontSwitcher.iconset/icon_${size}x${size}.png >/dev/null
  sips -z $((size * 2)) $((size * 2)) FontSwitcher.png --out FontSwitcher.iconset/icon_${size}x${size}@2x.png >/dev/null
done
iconutil -c icns FontSwitcher.iconset -o FontSwitcher.icns

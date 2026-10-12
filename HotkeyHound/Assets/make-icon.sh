#!/bin/zsh
# Regenerates HotkeyHound.png / .iconset / .icns from GenerateIcon.swift.
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/HotkeyHound-icon.XXXXXX)
trap 'rm -rf "$stage"' EXIT
CLANG_MODULE_CACHE_PATH="$stage/cache" xcrun swift GenerateIcon.swift .
rm -rf HotkeyHound.iconset; mkdir HotkeyHound.iconset
for size in 16 32 128 256 512; do
  sips -z $size $size HotkeyHound.png --out HotkeyHound.iconset/icon_${size}x${size}.png >/dev/null
  sips -z $((size * 2)) $((size * 2)) HotkeyHound.png --out HotkeyHound.iconset/icon_${size}x${size}@2x.png >/dev/null
done
iconutil -c icns HotkeyHound.iconset -o HotkeyHound.icns

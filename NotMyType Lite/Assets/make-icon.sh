#!/bin/zsh
# Regenerates NotMyTypeLite.png / .iconset / .icns from GenerateIcon.swift.
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/NotMyTypeLite-icon.XXXXXX)
trap 'rm -rf "$stage"' EXIT
CLANG_MODULE_CACHE_PATH="$stage/cache" xcrun swift GenerateIcon.swift .
rm -rf NotMyTypeLite.iconset; mkdir NotMyTypeLite.iconset
for size in 16 32 128 256 512; do
  sips -z $size $size NotMyTypeLite.png --out NotMyTypeLite.iconset/icon_${size}x${size}.png >/dev/null
  sips -z $((size * 2)) $((size * 2)) NotMyTypeLite.png --out NotMyTypeLite.iconset/icon_${size}x${size}@2x.png >/dev/null
done
iconutil -c icns NotMyTypeLite.iconset -o NotMyTypeLite.icns

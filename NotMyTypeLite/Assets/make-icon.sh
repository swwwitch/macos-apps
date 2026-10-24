#!/bin/zsh
# Regenerates NotMyType.png / .iconset / .icns from GenerateIcon.swift.
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/NotMyType-icon.XXXXXX)
trap 'rm -rf "$stage"' EXIT
CLANG_MODULE_CACHE_PATH="$stage/cache" xcrun swift GenerateIcon.swift .
rm -rf NotMyType.iconset; mkdir NotMyType.iconset
for size in 16 32 128 256 512; do
  sips -z $size $size NotMyType.png --out NotMyType.iconset/icon_${size}x${size}.png >/dev/null
  sips -z $((size * 2)) $((size * 2)) NotMyType.png --out NotMyType.iconset/icon_${size}x${size}@2x.png >/dev/null
done
iconutil -c icns NotMyType.iconset -o NotMyType.icns

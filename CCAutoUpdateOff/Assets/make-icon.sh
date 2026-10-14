#!/bin/zsh
# Regenerates CCAutoUpdateOff.png / .iconset / .icns from GenerateIcon.swift.
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/CCAutoUpdateOff-icon.XXXXXX)
trap 'rm -rf "$stage"' EXIT
CLANG_MODULE_CACHE_PATH="$stage/cache" xcrun swift GenerateIcon.swift .
rm -rf CCAutoUpdateOff.iconset; mkdir CCAutoUpdateOff.iconset
for size in 16 32 128 256 512; do
  sips -z $size $size CCAutoUpdateOff.png --out CCAutoUpdateOff.iconset/icon_${size}x${size}.png >/dev/null
  sips -z $((size * 2)) $((size * 2)) CCAutoUpdateOff.png --out CCAutoUpdateOff.iconset/icon_${size}x${size}@2x.png >/dev/null
done
iconutil -c icns CCAutoUpdateOff.iconset -o CCAutoUpdateOff.icns

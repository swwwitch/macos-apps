#!/bin/zsh
# Regenerates PrefsPreset.png / .iconset / .icns from GenerateIcon.swift.
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/PrefsPreset-icon.XXXXXX)
trap 'rm -rf "$stage"' EXIT
CLANG_MODULE_CACHE_PATH="$stage/cache" xcrun swift GenerateIcon.swift .
rm -rf PrefsPreset.iconset; mkdir PrefsPreset.iconset
for size in 16 32 128 256 512; do
  sips -z $size $size PrefsPreset.png --out PrefsPreset.iconset/icon_${size}x${size}.png >/dev/null
  sips -z $((size * 2)) $((size * 2)) PrefsPreset.png --out PrefsPreset.iconset/icon_${size}x${size}@2x.png >/dev/null
done
iconutil -c icns PrefsPreset.iconset -o PrefsPreset.icns

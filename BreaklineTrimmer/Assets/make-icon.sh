#!/bin/zsh
# Regenerates BreaklineTrimmer.png / .iconset / .icns from GenerateIcon.swift.
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/BreaklineTrimmer-icon.XXXXXX)
trap 'rm -rf "$stage"' EXIT
CLANG_MODULE_CACHE_PATH="$stage/cache" xcrun swift -module-cache-path "$stage/cache" GenerateIcon.swift BreaklineTrimmer.png
rm -rf BreaklineTrimmer.iconset; mkdir BreaklineTrimmer.iconset
for size in 16 32 128 256 512; do
  sips -z $size $size BreaklineTrimmer.png --out BreaklineTrimmer.iconset/icon_${size}x${size}.png >/dev/null
  sips -z $((size * 2)) $((size * 2)) BreaklineTrimmer.png --out BreaklineTrimmer.iconset/icon_${size}x${size}@2x.png >/dev/null
done
iconutil -c icns BreaklineTrimmer.iconset -o BreaklineTrimmer.icns

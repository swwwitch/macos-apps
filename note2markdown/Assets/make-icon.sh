#!/bin/zsh
# Regenerates note2markdown.png / .iconset / .icns from GenerateIcon.swift.
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/note2markdown-icon.XXXXXX)
trap 'rm -rf "$stage"' EXIT
CLANG_MODULE_CACHE_PATH="$stage/cache" xcrun swift GenerateIcon.swift .
rm -rf note2markdown.iconset; mkdir note2markdown.iconset
for size in 16 32 128 256 512; do
  sips -z $size $size note2markdown.png --out note2markdown.iconset/icon_${size}x${size}.png >/dev/null
  sips -z $((size * 2)) $((size * 2)) note2markdown.png --out note2markdown.iconset/icon_${size}x${size}@2x.png >/dev/null
done
iconutil -c icns note2markdown.iconset -o note2markdown.icns

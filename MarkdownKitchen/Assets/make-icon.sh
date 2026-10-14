#!/bin/zsh
# Regenerates MarkdownKitchen.png / .iconset / .icns from GenerateIcon.swift.
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/MarkdownKitchen-icon.XXXXXX)
trap 'rm -rf "$stage"' EXIT
CLANG_MODULE_CACHE_PATH="$stage/cache" xcrun swift GenerateIcon.swift .
rm -rf MarkdownKitchen.iconset; mkdir MarkdownKitchen.iconset
for size in 16 32 128 256 512; do
  sips -z $size $size MarkdownKitchen.png --out MarkdownKitchen.iconset/icon_${size}x${size}.png >/dev/null
  sips -z $((size * 2)) $((size * 2)) MarkdownKitchen.png --out MarkdownKitchen.iconset/icon_${size}x${size}@2x.png >/dev/null
done
iconutil -c icns MarkdownKitchen.iconset -o MarkdownKitchen.icns

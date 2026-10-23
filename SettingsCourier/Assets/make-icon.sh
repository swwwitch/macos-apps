#!/bin/zsh
# Regenerates SettingsCourier.png / .iconset / .icns from GenerateIcon.swift.
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/SettingsCourier-icon.XXXXXX)
trap 'rm -rf "$stage"' EXIT
CLANG_MODULE_CACHE_PATH="$stage/cache" xcrun swift GenerateIcon.swift .
rm -rf SettingsCourier.iconset; mkdir SettingsCourier.iconset
for size in 16 32 128 256 512; do
  sips -z $size $size SettingsCourier.png --out SettingsCourier.iconset/icon_${size}x${size}.png >/dev/null
  sips -z $((size * 2)) $((size * 2)) SettingsCourier.png --out SettingsCourier.iconset/icon_${size}x${size}@2x.png >/dev/null
done
iconutil -c icns SettingsCourier.iconset -o SettingsCourier.icns

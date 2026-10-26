#!/bin/zsh
# Assets/make-icon.sh  regenerate <App>.png, the iconset and <App>.icns from GenerateIcon.swift
set -euo pipefail
cd "${0:A:h}"
name="${PWD:h:t}"
stage=$(mktemp -d /private/tmp/$name-icon.XXXXXX); trap 'rm -rf "$stage"' EXIT
xcrun swiftc -module-cache-path "$stage/cache" GenerateIcon.swift -o "$stage/gen" && "$stage/gen" "$PWD"
rm -rf "$name.iconset"; mkdir "$name.iconset"
for s in 16 32 128 256 512; do
  sips -z $s $s "$name.png" --out "$name.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$name.png" --out "$name.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$name.iconset" -o "$name.icns"
print "Made $name.icns"

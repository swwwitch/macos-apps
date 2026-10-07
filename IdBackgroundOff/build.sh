#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/IdBackgroundOff-build.XXXXXX)
trap 'rm -rf "$stage"' EXIT
app="$stage/IdBackgroundOff.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Info.plist "$app/Contents/Info.plist"
cp -R Resources/*.lproj "$app/Contents/Resources/"
cp Resources/PrivacyInfo.xcprivacy README.md Assets/IdBackgroundOff.icns "$app/Contents/Resources/"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx13.0 -module-cache-path "$stage/cache" -framework AppKit -framework SwiftUI ../Shared/AppStandards/AppHeader.swift ../Shared/AppStandards/AppSurface.swift Source/AsyncExports.swift Source/main.swift -o "$app/Contents/MacOS/IdBackgroundOff"
xattr -cr "$app"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
mkdir -p build
if [[ -d build/IdBackgroundOff.app ]]; then
  backup="Backups/build-$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p "$backup"
  mv build/IdBackgroundOff.app "$backup/"
fi
ditto "$app" build/IdBackgroundOff.app
codesign --verify --deep --strict build/IdBackgroundOff.app
printf 'Built: %s\n' build/IdBackgroundOff.app

#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
python3 ../Shared/MenuBarPresence/sync.py
UPDATER_ROOT="$PWD/../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
stage=$(mktemp -d /private/tmp/IdBackgroundOff-build.XXXXXX)
trap 'rm -rf "$stage"' EXIT
app="$stage/IdBackgroundOff.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Info.plist "$app/Contents/Info.plist"
cp -R Resources/*.lproj "$app/Contents/Resources/"
cp Resources/PrivacyInfo.xcprivacy README.md Assets/IdBackgroundOff.icns "$app/Contents/Resources/"
xcrun swiftc "${UPDATE_SWIFT_FLAGS[@]}" -swift-version 5 -O -target arm64-apple-macosx13.0 -module-cache-path "$stage/cache" -framework AppKit -framework SwiftUI -framework Carbon ../Shared/AppStandards/AppHeader.swift ../Shared/AppStandards/AppSurface.swift ../Shared/AppStandards/StartupWindow.swift ../Shared/AppStandards/HelpDocument.swift Source/AsyncExports.swift Source/MenuBarPresence.swift Source/UpdateSupport.swift Source/main.swift -o "$app/Contents/MacOS/IdBackgroundOff"
embed_updates "$app"
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

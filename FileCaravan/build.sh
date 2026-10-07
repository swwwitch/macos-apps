#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
python3 ../Shared/MenuBarPresence/sync.py
UPDATER_ROOT="$PWD/../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
stage=$(mktemp -d /private/tmp/FileCaravan-build.XXXXXX)
trap 'rm -rf "$stage"' EXIT
app="$stage/FileCaravan.app"
output=build
if [[ "${APP_STORE_BUILD:-0}" == 1 ]]; then
  output=StoreBuild
fi
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Info.plist "$app/Contents/Info.plist"
cp -R Resources/*.lproj "$app/Contents/Resources/"
cp Resources/PrivacyInfo.xcprivacy "$app/Contents/Resources/"
cp README.md "$app/Contents/Resources/"
cp Assets/FileCaravan.icns "$app/Contents/Resources/"
xcrun swiftc "${UPDATE_SWIFT_FLAGS[@]}" -swift-version 5 -O -target arm64-apple-macosx13.0 -module-cache-path "$stage/cache" -framework AppKit -framework SwiftUI -framework ServiceManagement -framework Carbon ../Shared/AppStandards/SettingsSection.swift ../Shared/AppStandards/LaunchPresenceSection.swift ../Shared/AppStandards/AppHeader.swift ../Shared/AppStandards/AppSurface.swift ../Shared/AppStandards/StartupWindow.swift ../Shared/AppStandards/HelpDocument.swift Source/LaunchPolicy.swift Source/LoginAtLaunch.swift Source/MoveEngine.swift Source/FolderAccess.swift Source/FolderIcon.swift Source/PathDisplay.swift Source/MenuBarPresence.swift Source/UpdateSupport.swift Source/main.swift -o "$app/Contents/MacOS/FileCaravan"
embed_updates "$app"
xattr -cr "$app"
if [[ "${APP_STORE_BUILD:-0}" == 1 ]]; then
  codesign --force --sign - --entitlements AppStore/FileCaravan.entitlements "$app"
else
  codesign --force --sign - "$app"
fi
codesign --verify --deep --strict "$app"
mkdir -p "$output"
if [[ -d "$output/FileCaravan.app" ]]; then
  backup="Backups/build-$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p "$backup"
  mv "$output/FileCaravan.app" "$backup/"
fi
ditto "$app" "$output/FileCaravan.app"

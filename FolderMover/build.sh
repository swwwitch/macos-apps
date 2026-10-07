#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/FolderMover-build.XXXXXX)
trap 'rm -rf "$stage"' EXIT
app="$stage/FolderMover.app"
output=build
flags=()
if [[ "${APP_STORE_BUILD:-0}" == 1 ]]; then
  output=StoreBuild
  flags=(-D APP_STORE)
fi
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Info.plist "$app/Contents/Info.plist"
cp -R Resources/*.lproj "$app/Contents/Resources/"
cp Resources/PrivacyInfo.xcprivacy "$app/Contents/Resources/"
cp README.md "$app/Contents/Resources/"
cp Assets/FolderMover.icns "$app/Contents/Resources/"
xcrun swiftc "${flags[@]}" -swift-version 5 -O -target arm64-apple-macosx13.0 -module-cache-path "$stage/cache" -framework AppKit -framework SwiftUI -framework ServiceManagement -framework Carbon ../Shared/AppStandards/SettingsSection.swift ../Shared/AppStandards/LaunchPresenceSection.swift ../Shared/AppStandards/AppHeader.swift ../Shared/AppStandards/AppSurface.swift ../Shared/AppStandards/StartupWindow.swift ../Shared/AppStandards/HelpDocument.swift Source/LaunchPolicy.swift Source/LoginAtLaunch.swift Source/MoveEngine.swift Source/FolderAccess.swift Source/FolderIcon.swift Source/PathDisplay.swift Source/main.swift -o "$app/Contents/MacOS/FolderMover"
xattr -cr "$app"
if [[ "${APP_STORE_BUILD:-0}" == 1 ]]; then
  codesign --force --sign - --entitlements AppStore/FolderMover.entitlements "$app"
else
  codesign --force --sign - "$app"
fi
codesign --verify --deep --strict "$app"
mkdir -p "$output"
if [[ -d "$output/FolderMover.app" ]]; then
  backup="Backups/build-$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p "$backup"
  mv "$output/FolderMover.app" "$backup/"
fi
ditto "$app" "$output/FolderMover.app"

#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/FolderMover-build.XXXXXX)
trap 'rm -rf "$stage"' EXIT
app="$stage/FolderMover.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Info.plist "$app/Contents/Info.plist"
cp -R Resources/*.lproj "$app/Contents/Resources/"
cp Assets/FolderMover.icns "$app/Contents/Resources/"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx13.0 -module-cache-path "$stage/cache" -framework AppKit -framework SwiftUI -framework ServiceManagement -framework Carbon ../Shared/AppStandards/LaunchPresenceSection.swift ../Shared/AppStandards/AppHeader.swift ../Shared/AppStandards/AppSurface.swift Source/LaunchPolicy.swift Source/LoginAtLaunch.swift Source/MoveEngine.swift Source/PathDisplay.swift Source/main.swift -o "$app/Contents/MacOS/FolderMover"
xattr -cr "$app"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
mkdir -p build
if [[ -d build/FolderMover.app ]]; then
  backup="Backups/build-$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p "$backup"
  mv build/FolderMover.app "$backup/"
fi
ditto "$app" build/FolderMover.app

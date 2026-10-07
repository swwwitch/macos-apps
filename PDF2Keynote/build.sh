#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/PDF2Keynote-build.XXXXXX)
trap 'rm -rf "$stage"' EXIT
python3 make-resources.py
app="$stage/PDF2Keynote.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Info.plist "$app/Contents/Info.plist"
cp -R Resources/*.lproj "$app/Contents/Resources/"
osacompile -o "$app/Contents/Resources/Keynote.scpt" ../Shared/KeynoteExport/Keynote.applescript
cp Assets/PDF2Keynote.icns README.md "$app/Contents/Resources/"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx13.0 -module-cache-path "$stage/cache" \
  -framework AppKit -framework SwiftUI -framework ServiceManagement -framework Carbon -framework PDFKit \
  ../Shared/AppStandards/{SettingsSection,LaunchPresenceSection,AppHeader,AppSurface,StartupWindow,HelpDocument}.swift ../Shared/MenuBarPresence/MenuBarPresence.swift ../Shared/KeynoteExport/KeynoteExport.swift \
  Source/{ConversionRunner,LaunchPolicy,LoginAtLaunch,main}.swift -o "$app/Contents/MacOS/PDF2Keynote"
xattr -cr "$app"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
mkdir -p build
if [[ -d build/PDF2Keynote.app ]]; then
  backup="Backups/build-$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p "$backup"
  mv build/PDF2Keynote.app "$backup/"
fi
ditto "$app" build/PDF2Keynote.app
print "Built build/PDF2Keynote.app"

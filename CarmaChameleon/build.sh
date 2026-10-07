#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/CarmaChameleon-build.XXXXXX)
trap 'rm -rf "$stage"' EXIT
app="$stage/CarmaChameleon.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/bin"
cp Info.plist "$app/Contents/Info.plist"
cp -R Resources/* "$app/Contents/Resources/"
cp Assets/CarmaChameleon.icns "$app/Contents/Resources/"
cp Vendor/pandoc "$app/Contents/Resources/bin/"
osacompile -o "$app/Contents/Resources/Keynote.scpt" ../Shared/KeynoteExport/Keynote.applescript
cp README.md "$app/Contents/Resources/"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx13.0 -module-cache-path "$stage/cache" -framework AppKit -framework SwiftUI -framework ServiceManagement -framework Carbon -framework PDFKit -framework Vision ../Shared/AppStandards/{SettingsSection,LaunchPresenceSection,AppHeader,AppSurface,StartupWindow,HelpDocument}.swift ../Shared/KeynoteExport/KeynoteExport.swift Source/{LaunchPolicy,LoginAtLaunch,IDMLImporter,PDFImporter,IDMLExporter,HTMLFormatting,MarkdownToText,XLSXImporter,AIImporter,IllustratorBridge,Conversion,EngineManager,PDFEngineManager,main}.swift -o "$app/Contents/MacOS/CarmaChameleon"
xattr -cr "$app"
codesign --force --sign - "$app/Contents/Resources/bin/pandoc"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
mkdir -p build
if [[ -d build/CarmaChameleon.app ]]; then
  backup="Backups/build-$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p "$backup"
  mv build/CarmaChameleon.app "$backup/"
fi
ditto "$app" build/CarmaChameleon.app

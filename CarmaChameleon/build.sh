#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
UPDATER_ROOT="$PWD/../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
stage=$(mktemp -d /private/tmp/CarmaChameleon-build.XXXXXX)
trap 'rm -rf "$stage"' EXIT
app="$stage/CarmaChameleon.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/bin"
cp Info.plist "$app/Contents/Info.plist"
cp -R Resources/* "$app/Contents/Resources/"
cp Assets/CarmaChameleon.icns "$app/Contents/Resources/"
cp Vendor/pandoc "$app/Contents/Resources/bin/"
python3 ../Shared/KeynoteExport/compile.py "$app/Contents/Resources/Keynote.scpt"
cp README.md "$app/Contents/Resources/"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx13.0 -module-cache-path "$stage/cache" -framework AppKit -framework SwiftUI -framework ServiceManagement -framework Carbon -framework PDFKit -framework Vision "${UPDATE_SWIFT_FLAGS[@]}" ../Shared/AppStandards/{SettingsSection,LaunchPresenceSection,AppHeader,AppSurface,StartupWindow,HelpDocument,AboutSection}.swift ../Shared/KeynoteExport/KeynoteExport.swift ../Shared/KeynoteExport/PDFBackground.swift Source/{MenuBarPresence,UpdateSupport,LaunchPolicy,LoginAtLaunch,IDMLImporter,PDFImporter,IDMLExporter,HTMLFormatting,MarkdownToText,XLSXImporter,AIImporter,IllustratorBridge,Conversion,ImageExport,ImageConversion,ImageOptionsViews,SRTConverter,TextEncodingConverter,FileNameConverter,EngineManager,PDFEngineManager,main}.swift -o "$app/Contents/MacOS/CarmaChameleon"
embed_updates "$app"
"$UPDATER_ROOT/../AppIcon/apply-app-icon.sh" "$app"
xattr -cr "$app"
# Local builds sign with the team certificate so the designated requirement stays stable across rebuilds
# (Accessibility and other permissions carry over). CARMACHAMELEON_SIGNING_IDENTITY overrides it.
SIGNING_IDENTITY="${CARMACHAMELEON_SIGNING_IDENTITY:-301A41C0A37B6B578B7477229015992E8AA34E44}"
SIGNING_OPTIONS=(--timestamp=none)
codesign --force --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" "$app/Contents/Resources/bin/pandoc"
codesign --force --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" "$app"
codesign --verify --deep --strict "$app"
mkdir -p build
if [[ -d build/CarmaChameleon.app ]]; then
  backup="Backups/build-$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p "$backup"
  mv build/CarmaChameleon.app "$backup/"
fi
ditto --noextattr --norsrc "$app" build/CarmaChameleon.app
codesign --verify --deep --strict build/CarmaChameleon.app

if [[ "${APP_STORE_BUILD:-0}" != 1 ]]; then
    python3 ../Shared/BuildTools/publish_latest.py "$app"
fi

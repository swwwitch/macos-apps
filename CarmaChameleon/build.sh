#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
UPDATER_ROOT="$PWD/../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
if [[ "${APP_STORE_BUILD:-0}" == 1 && "${CARMACHAMELEON_STORE_QA:-0}" != 1 && -z "${CARMACHAMELEON_STORE_PROFILE:-}" ]]; then
    print -u2 "Store distribution requires CARMACHAMELEON_STORE_PROFILE. For local QA only, set CARMACHAMELEON_STORE_QA=1."
    exit 2
fi
stage=$(mktemp -d /private/tmp/CarmaChameleon-build.XXXXXX)
trap 'rm -rf "$stage"' EXIT
app="$stage/CarmaChameleon.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/bin"
cp Info.plist "$app/Contents/Info.plist"
cp -R Resources/* "$app/Contents/Resources/"
cp Assets/CarmaChameleon.icns "$app/Contents/Resources/"
cp Vendor/pandoc "$app/Contents/Resources/bin/"
if [[ "${APP_STORE_BUILD:-0}" == 1 ]]; then
    test -x Vendor/typst
    cp Vendor/typst "$app/Contents/Resources/bin/"
fi
python3 ../Shared/KeynoteExport/compile.py "$app/Contents/Resources/Keynote.scpt"
cp README.md "$app/Contents/Resources/"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx13.0 -module-cache-path "$stage/cache" -framework AppKit -framework SwiftUI -framework ServiceManagement -framework Carbon -framework PDFKit -framework Vision "${UPDATE_SWIFT_FLAGS[@]}" ../Shared/AppStandards/{SettingsSection,LaunchPresenceSection,AppHeader,AppSurface,StartupWindow,HelpDocument,AboutSection}.swift ../Shared/SettingsSync/SettingsSync.swift ../Shared/KeynoteExport/KeynoteExport.swift ../Shared/KeynoteExport/PDFBackground.swift Source/{MenuBarPresence,UpdateSupport,LaunchPolicy,LoginAtLaunch,IDMLImporter,PDFImporter,IDMLExporter,HTMLFormatting,MarkdownToText,XLSXImporter,AIImporter,IllustratorBridge,Conversion,ImageExport,ImageConversion,ImageOptionsViews,SRTConverter,TextEncodingConverter,FileNameConverter,MarginTrimmer,ShadowTrimmer,StoreFolderAccess,EngineManager,PDFEngineManager,main}.swift -o "$app/Contents/MacOS/CarmaChameleon"
embed_updates "$app"
"$UPDATER_ROOT/../AppIcon/apply-app-icon.sh" "$app"
xattr -cr "$app"
# Local builds sign with the team certificate so the designated requirement stays stable across rebuilds
# (Accessibility and other permissions carry over). CARMACHAMELEON_SIGNING_IDENTITY overrides it.
DEFAULT_IDENTITY=301A41C0A37B6B578B7477229015992E8AA34E44
if [[ "${APP_STORE_BUILD:-0}" == 1 && "${CARMACHAMELEON_STORE_QA:-0}" == 1 ]]; then DEFAULT_IDENTITY=7A1E563ACDF18A58946DC4305A27467A63B24318; fi
SIGNING_IDENTITY="${CARMACHAMELEON_SIGNING_IDENTITY:-$DEFAULT_IDENTITY}"
SIGNING_OPTIONS=(--timestamp=none)
if [[ "${APP_STORE_BUILD:-0}" == 1 ]]; then
    python3 Store/prepare-signing.py "$app" "$stage/App.entitlements"
    for engine in pandoc typst; do
        codesign --force --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" --entitlements Store/Helper.entitlements "$app/Contents/Resources/bin/$engine"
    done
    codesign --force --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" --entitlements "$stage/App.entitlements" "$app"
else
    codesign --force --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" "$app/Contents/Resources/bin/pandoc"
    codesign --force --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" "$app"
fi
codesign --verify --deep --strict "$app"
output=build
if [[ "${APP_STORE_BUILD:-0}" == 1 ]]; then output=StoreBuild; fi
mkdir -p "$output"
if [[ -d "$output/CarmaChameleon.app" ]]; then
  backup="Backups/build-$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p "$backup"
  mv "$output/CarmaChameleon.app" "$backup/"
fi
ditto --noextattr --norsrc "$app" "$output/CarmaChameleon.app"
codesign --verify --deep --strict "$output/CarmaChameleon.app"

if [[ "${APP_STORE_BUILD:-0}" != 1 ]]; then
    python3 ../Shared/BuildTools/publish_latest.py "$app"
fi

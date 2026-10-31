#!/bin/zsh
set -eu
cd "${0:A:h}"
UPDATER_ROOT="$PWD/../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
STAGING=$(mktemp -d "${TMPDIR:-/tmp/}pastemaestro.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/PasteMaestro.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
SOURCES=(Sources/*.swift)
xcrun swiftc -O -target "$(uname -m)-apple-macos13.0" -module-cache-path "$STAGING/ModuleCache" -framework AppKit -framework SwiftUI -framework ApplicationServices -framework Carbon -framework ServiceManagement -framework UniformTypeIdentifiers "${UPDATE_SWIFT_FLAGS[@]}" "${SOURCES[@]}" -o "$APP/Contents/MacOS/PasteMaestro"
cp Info.plist "$APP/Contents/Info.plist"
cp -R Resources/. "$APP/Contents/Resources/"
# The committed .icns is the source of truth; file dates after a clone or checkout say nothing about which is newer.
# Redraw only when it is missing or on request: REGENERATE_ICON=1 ./build.sh
if [[ ! -f Assets/PasteMaestro.icns || "${REGENERATE_ICON:-0}" == 1 ]]; then
    xcrun swift -module-cache-path "$STAGING/ModuleCache" Assets/draw-icon.swift Assets/PasteMaestro.png
    python3 Assets/package-icon.py
fi
cp Assets/PasteMaestro.icns "$APP/Contents/Resources/"
embed_updates "$APP"
# macOS 26: Assets.car avoids the gray frame; the original .icns stays for the in-window header.
"$UPDATER_ROOT/../AppIcon/apply-app-icon.sh" "$APP"
xattr -cr "$APP"
# Same certificate as SpreadsheetHelper/KakkoReplace (team PL9S9PXX96, login keychain) so the Accessibility grant
# survives rebuilds. PASTEMAESTRO_DISTRIBUTION=developer-id signs for distribution and never falls back.
SIGNING_IDENTITY="${PASTEMAESTRO_SIGNING_IDENTITY:-301A41C0A37B6B578B7477229015992E8AA34E44}"
SIGNING_OPTIONS=(--timestamp=none)
if [[ "${PASTEMAESTRO_DISTRIBUTION:-local}" == "developer-id" ]]; then
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning | awk '/"Developer ID Application:.*\(PL9S9PXX96\)"/ {print $2; exit}')
    [[ -n "$SIGNING_IDENTITY" ]] || { print -u2 "Developer ID Application certificate with private key is required for team PL9S9PXX96."; exit 1; }
    SIGNING_OPTIONS=(--options runtime --timestamp)
    [[ -d "$APP/Contents/Frameworks/Sparkle.framework" ]] && codesign --force --deep --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" "$APP/Contents/Frameworks/Sparkle.framework"
fi
if [[ -d "$APP/Contents/Frameworks/Sparkle.framework" ]]; then
    codesign --force --deep --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" "$APP/Contents/Frameworks/Sparkle.framework"
fi
codesign --force --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" "$APP"
codesign --verify --deep --strict "$APP"
if [[ -e PasteMaestro.app ]]; then
    mkdir -p Backups
    mv PasteMaestro.app "Backups/PasteMaestro-$(date +%Y%m%d-%H%M%S)-$$.app"
fi
ditto "$APP" PasteMaestro.app
printf '%s\n' "$PWD/PasteMaestro.app"

# Development builds stay in this workspace. Distribution is performed on the notarization Mac.
if [[ "${NO_DEPLOY:-1}" == 0 && "${SKIP_PUBLISH:-1}" == 0 ]]; then
    python3 ../Shared/BuildTools/publish_latest.py "$APP"
fi

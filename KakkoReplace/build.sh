#!/bin/zsh
set -eu
cd "${0:A:h}"
python3 ../Shared/MenuBarPresence/sync.py
python3 ../Shared/AppStandards/sync-surface.py
UPDATER_ROOT="$PWD/../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
STAGING=$(mktemp -d "${TMPDIR:-/tmp/}superkakko.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/KakkoReplace.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc -O -target "$(uname -m)-apple-macos13.0" -module-cache-path "$STAGING/ModuleCache" -framework AppKit -framework SwiftUI -framework ApplicationServices -framework Carbon -framework ServiceManagement "${UPDATE_SWIFT_FLAGS[@]}" Sources/AppSurface.swift Sources/StartupWindow.swift Sources/HelpDocument.swift Sources/SettingsSection.swift Sources/AccessibilityPermission.swift Sources/LaunchPolicy.swift Sources/Transform.swift Sources/Editor.swift Sources/HotKey.swift Sources/PaletteTargetSession.swift Sources/Palette.swift Sources/OperationPicker.swift Sources/MenuBarPresence.swift Sources/UpdateSupport.swift Sources/WindowActivationPolicy.swift Sources/AboutSection.swift Sources/main.swift -o "$APP/Contents/MacOS/KakkoReplace"
cp Info.plist "$APP/Contents/Info.plist"
cp -R Resources/. "$APP/Contents/Resources/"
if [[ ! -f Assets/KakkoReplace.icns || Assets/draw-icon.swift -nt Assets/KakkoReplace.icns || Assets/package-icon.py -nt Assets/KakkoReplace.icns ]]; then
    xcrun swift -module-cache-path "$STAGING/ModuleCache" Assets/draw-icon.swift Assets/KakkoReplace.png
    python3 Assets/package-icon.py
fi
cp Assets/KakkoReplace.icns "$APP/Contents/Resources/"
embed_updates "$APP"
"$UPDATER_ROOT/../AppIcon/apply-app-icon.sh" "$APP"
xattr -cr "$APP"
# Same as MightyEdit: a certificate-backed identity (team PL9S9PXX96) so Accessibility grants follow the app
# rather than a changing ad-hoc hash. KAKKOREPLACE_DISTRIBUTION=developer-id signs for distribution and never falls back.
SIGNING_IDENTITY="${SUPERKAKKOREPLACE_SIGNING_IDENTITY:-301A41C0A37B6B578B7477229015992E8AA34E44}"
SIGNING_OPTIONS=(--timestamp=none)
if [[ "${KAKKOREPLACE_DISTRIBUTION:-local}" == "developer-id" ]]; then
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning | awk '/"Developer ID Application:.*\(PL9S9PXX96\)"/ {print $2; exit}')
    [[ -n "$SIGNING_IDENTITY" ]] || { print -u2 "Developer ID Application certificate with private key is required for team PL9S9PXX96."; exit 1; }
    SIGNING_OPTIONS=(--options runtime --timestamp)
    [[ -d "$APP/Contents/Frameworks/Sparkle.framework" ]] && codesign --force --deep --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" "$APP/Contents/Frameworks/Sparkle.framework"
fi
codesign --force --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" "$APP"
codesign --verify --deep --strict "$APP"
if [[ -e KakkoReplace.app ]]; then
    mkdir -p Backups
    mv KakkoReplace.app "Backups/KakkoReplace-$(date +%Y%m%d-%H%M%S)-$$.app"
fi
ditto "$APP" KakkoReplace.app
printf '%s\n' "$PWD/KakkoReplace.app"

if [[ "${APP_STORE_BUILD:-0}" != 1 ]]; then
    python3 ../Shared/BuildTools/publish_latest.py "$APP"
fi

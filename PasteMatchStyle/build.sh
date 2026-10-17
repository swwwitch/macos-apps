#!/bin/zsh
set -eu
cd "${0:A:h}"
python3 ../Shared/MenuBarPresence/sync.py
python3 ../Shared/HotkeyManifest/sync.py
python3 ../Shared/AppStandards/sync-surface.py
python3 ../Shared/SettingsSync/sync.py
python3 ../Shared/ExcludedApps/sync.py
python3 ../Shared/LoginAtLaunch/sync.py
python3 ../Shared/HotkeyRecorder/sync.py
UPDATER_ROOT="$PWD/../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
STAGING=$(mktemp -d "${TMPDIR:-/tmp/}pastematchstyle.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/PasteMatchStyle.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
SOURCES=(Sources/AppSurface.swift Sources/AppHeader.swift Sources/StartupWindow.swift Sources/HelpDocument.swift Sources/SettingsSection.swift Sources/SettingsSync.swift
         Sources/AccessibilityPermission.swift Sources/LaunchPolicy.swift Sources/MenuTitles.swift Sources/PlainPaster.swift Sources/ExcludedApps.swift Sources/HotKey.swift Sources/ShortcutCombo.swift Sources/HotkeyRecorder.swift
         Sources/MenuBarPresence.swift Sources/UpdateSupport.swift Sources/WindowActivationPolicy.swift Sources/AboutSection.swift
         Sources/HotkeyManifest.swift Sources/main.swift)
xcrun swiftc -O -target "$(uname -m)-apple-macos13.0" -module-cache-path "$STAGING/ModuleCache" -framework AppKit -framework SwiftUI -framework ApplicationServices -framework Carbon -framework ServiceManagement -framework UniformTypeIdentifiers "${UPDATE_SWIFT_FLAGS[@]}" "${SOURCES[@]}" -o "$APP/Contents/MacOS/PasteMatchStyle"
cp Info.plist "$APP/Contents/Info.plist"
cp -R Resources/. "$APP/Contents/Resources/"
if [[ ! -f Assets/PasteMatchStyle.icns || Assets/draw-icon.swift -nt Assets/PasteMatchStyle.icns || Assets/package-icon.py -nt Assets/PasteMatchStyle.icns ]]; then
    xcrun swift -module-cache-path "$STAGING/ModuleCache" Assets/draw-icon.swift Assets/PasteMatchStyle.png
    python3 Assets/package-icon.py
fi
cp Assets/PasteMatchStyle.icns "$APP/Contents/Resources/"
embed_updates "$APP"
# macOS 26: Assets.car avoids the gray frame; the original .icns stays for the in-window header.
"$UPDATER_ROOT/../AppIcon/apply-app-icon.sh" "$APP"
xattr -cr "$APP"
# Same certificate as PasteInARow/SpreadsheetHelper/KakkoReplace (team PL9S9PXX96, login keychain) so the Accessibility grant
# survives rebuilds. PASTEMATCHSTYLE_DISTRIBUTION=developer-id signs for distribution and never falls back.
SIGNING_IDENTITY="${PASTEMATCHSTYLE_SIGNING_IDENTITY:-301A41C0A37B6B578B7477229015992E8AA34E44}"
SIGNING_OPTIONS=(--timestamp=none)
if [[ "${PASTEMATCHSTYLE_DISTRIBUTION:-local}" == "developer-id" ]]; then
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning | awk '/"Developer ID Application:.*\(PL9S9PXX96\)"/ {print $2; exit}')
    [[ -n "$SIGNING_IDENTITY" ]] || { print -u2 "Developer ID Application certificate with private key is required for team PL9S9PXX96."; exit 1; }
    SIGNING_OPTIONS=(--options runtime --timestamp)
    [[ -d "$APP/Contents/Frameworks/Sparkle.framework" ]] && codesign --force --deep --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" "$APP/Contents/Frameworks/Sparkle.framework"
fi
codesign --force --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" "$APP"
codesign --verify --deep --strict "$APP"
if [[ -e PasteMatchStyle.app ]]; then
    mkdir -p Backups
    mv PasteMatchStyle.app "Backups/PasteMatchStyle-$(date +%Y%m%d-%H%M%S)-$$.app"
fi
ditto "$APP" PasteMatchStyle.app
printf '%s\n' "$PWD/PasteMatchStyle.app"

# SKIP_PUBLISH=1 builds without deploying (for checks before the final build).
if [[ "${APP_STORE_BUILD:-0}" != 1 && "${SKIP_PUBLISH:-0}" != 1 ]]; then
    python3 ../Shared/BuildTools/publish_latest.py "$APP"
fi

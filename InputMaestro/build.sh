#!/bin/zsh
set -eu
cd "${0:A:h}"
UPDATER_ROOT="$PWD/../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
STAGING=$(mktemp -d "${TMPDIR:-/tmp/}inputmaestro.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/InputMaestro.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
python3 make-resources.py
# Shared parts are compiled from Shared directly (no local copies to sync).
SOURCES=(../Shared/AppStandards/AppSurface.swift ../Shared/AppStandards/AppHeader.swift ../Shared/AppStandards/StartupWindow.swift
         ../Shared/AppStandards/HelpDocument.swift ../Shared/AppStandards/SettingsSection.swift ../Shared/AppStandards/AboutSection.swift
         ../Shared/AppStandards/WindowActivationPolicy.swift ../Shared/SettingsSync/SettingsSync.swift ../Shared/LoginAtLaunch/LoginAtLaunch.swift
         ../Shared/Accessibility/AccessibilityPermission.swift ../Shared/ExcludedApps/ExcludedApps.swift ../Shared/MenuBarPresence/MenuBarPresence.swift
         ../Shared/HotkeyRecorder/HotkeyRecorder.swift ../Shared/HotkeyManifest/HotkeyManifest.swift ../Shared/Updater/UpdateSupport.swift
         Sources/NumpadTap.swift Sources/KeyMap.swift Sources/CommaTyper.swift Sources/Integration.swift Sources/OCR.swift Sources/OCRServices.swift Sources/OCRText.swift Sources/LaunchPolicy.swift Sources/Commands.swift Sources/TextRanges.swift Sources/KeyTap.swift Sources/TextActions.swift
         Sources/CapsLockGuard.swift Sources/KeyboardLayout.swift Sources/KeyboardView.swift Sources/main.swift)
xcrun swiftc -O -target "$(uname -m)-apple-macos13.0" -module-cache-path "$STAGING/ModuleCache" -framework AppKit -framework SwiftUI -framework ApplicationServices -framework Carbon -framework ServiceManagement -framework UniformTypeIdentifiers -framework IOKit -framework Vision -framework ImageIO "${UPDATE_SWIFT_FLAGS[@]}" "${SOURCES[@]}" -o "$APP/Contents/MacOS/InputMaestro"
cp Info.plist "$APP/Contents/Info.plist"
cp -R Resources/. "$APP/Contents/Resources/"
# The committed .icns is the source of truth. Redraw only when it is missing or on request: REGENERATE_ICON=1 ./build.sh
if [[ ! -f Assets/InputMaestro.icns || "${REGENERATE_ICON:-0}" == 1 ]]; then
    xcrun swift -module-cache-path "$STAGING/ModuleCache" Assets/draw-icon.swift Assets/InputMaestro.png
    python3 Assets/package-icon.py
fi
cp Assets/InputMaestro.icns "$APP/Contents/Resources/"
embed_updates "$APP"
# macOS 26: Assets.car avoids the gray frame; the original .icns stays for the in-window header.
"$UPDATER_ROOT/../AppIcon/apply-app-icon.sh" "$APP"
xattr -cr "$APP"
# Team certificate (PL9S9PXX96, login keychain) so the Accessibility grant survives rebuilds.
# INPUTMAESTRO_DISTRIBUTION=developer-id signs for distribution and never falls back.
SIGNING_IDENTITY="${INPUTMAESTRO_SIGNING_IDENTITY:-301A41C0A37B6B578B7477229015992E8AA34E44}"
SIGNING_OPTIONS=(--timestamp=none)
if [[ "${INPUTMAESTRO_DISTRIBUTION:-local}" == "developer-id" ]]; then
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning | awk '/"Developer ID Application:.*\(PL9S9PXX96\)"/ {print $2; exit}')
    [[ -n "$SIGNING_IDENTITY" ]] || { print -u2 "Developer ID Application certificate with private key is required for team PL9S9PXX96."; exit 1; }
    SIGNING_OPTIONS=(--options runtime --timestamp --entitlements Entitlements.plist)
    [[ -d "$APP/Contents/Frameworks/Sparkle.framework" ]] && codesign --force --deep --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" "$APP/Contents/Frameworks/Sparkle.framework"
fi
codesign --force --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" "$APP"
codesign --verify --deep --strict "$APP"
if [[ -e InputMaestro.app ]]; then
    mkdir -p Backups
    mv InputMaestro.app "Backups/InputMaestro-$(date +%Y%m%d-%H%M%S)-$$.app"
fi
ditto "$APP" InputMaestro.app
printf '%s\n' "$PWD/InputMaestro.app"

# Development build only. Distribution is owned by the notarization Mac.

#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
UPDATER_ROOT="$PWD/../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
stage=$(mktemp -d /private/tmp/VectorMate-build.XXXXXX)
trap 'rm -rf "$stage"' EXIT
app="$stage/VectorMate.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Info.plist "$app/Contents/Info.plist"
# Localizable.strings are generated from make-resources.py.
python3 make-resources.py >/dev/null
cp -R Resources/*.lproj "$app/Contents/Resources/"
cp Resources/PrivacyInfo.xcprivacy README.md Assets/VectorMate.icns "$app/Contents/Resources/"
# Shared parts are compiled straight from Shared (no local copies to keep in sync).
SHARED=(../Shared/AppStandards/AppHeader.swift ../Shared/AppStandards/AppSurface.swift ../Shared/AppStandards/StartupWindow.swift
        ../Shared/AppStandards/HelpDocument.swift ../Shared/AppStandards/SettingsSection.swift ../Shared/AppStandards/AboutSection.swift
        ../Shared/LoginAtLaunch/LoginAtLaunch.swift
        ../Shared/Accessibility/AccessibilityPermission.swift ../Shared/MenuBarPresence/MenuBarPresence.swift ../Shared/Updater/UpdateSupport.swift ../Shared/HotkeyRecorder/HotkeyRecorder.swift ../Shared/HotkeyManifest/HotkeyManifest.swift ../Shared/SettingsSync/SettingsSync.swift)
for arch in arm64 x86_64; do
  xcrun swiftc "${UPDATE_SWIFT_FLAGS[@]}" -swift-version 5 -O -target "$arch-apple-macosx13.0" -module-cache-path "$stage/cache" \
    -framework AppKit -framework SwiftUI -framework Carbon -framework ServiceManagement -framework ApplicationServices \
    "${SHARED[@]}" Source/MetricsScript.swift Source/Illustrator.swift Source/IllustratorSettings.swift Source/Units.swift Source/UnitPalette.swift Source/UnitSetsEditor.swift Source/PrefPresets.swift Source/PrefPresetsUI.swift Source/QuickPrefs.swift Source/TransformPalette.swift Source/ToolWatch.swift Source/VersionPinning.swift Source/Links.swift Source/ShortcutSet.swift Source/FactoryReset.swift Source/LaunchPolicy.swift Source/main.swift -o "$stage/VectorMate-$arch"
done
xcrun lipo -create "$stage/VectorMate-arm64" "$stage/VectorMate-x86_64" -output "$app/Contents/MacOS/VectorMate"
xcrun lipo -verify_arch arm64 "$app/Contents/MacOS/VectorMate"
xcrun lipo -verify_arch x86_64 "$app/Contents/MacOS/VectorMate"
embed_updates "$app"
"$UPDATER_ROOT/../AppIcon/apply-app-icon.sh" "$app"
xattr -cr "$app"
# Team certificate (PL9S9PXX96, login keychain) so the Accessibility and Automation grants survive rebuilds.
SIGNING_IDENTITY="${VECTORMATE_SIGNING_IDENTITY:-301A41C0A37B6B578B7477229015992E8AA34E44}"
SIGNING_OPTIONS=(--timestamp=none)
if [[ "${VECTORMATE_DISTRIBUTION:-local}" == "developer-id" ]]; then
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning | awk '/"Developer ID Application:.*\(PL9S9PXX96\)"/ {print $2; exit}')
    [[ -n "$SIGNING_IDENTITY" ]] || { print -u2 "Developer ID Application certificate with private key is required for team PL9S9PXX96."; exit 1; }
    # Hardened runtime blocks Apple events to Illustrator without this entitlement.
    SIGNING_OPTIONS=(--options runtime --timestamp --entitlements Entitlements.plist)
    [[ -d "$app/Contents/Frameworks/Sparkle.framework" ]] && codesign --force --deep --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" "$app/Contents/Frameworks/Sparkle.framework"
fi
codesign --force --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" "$app"
codesign --verify --deep --strict "$app"
mkdir -p build
if [[ -d build/VectorMate.app ]]; then
  backup="Backups/build-$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p "$backup"
  mv build/VectorMate.app "$backup/"
fi
ditto "$app" build/VectorMate.app
codesign --verify --deep --strict build/VectorMate.app
printf 'Built: %s\n' build/VectorMate.app

if [[ "${APP_STORE_BUILD:-0}" != 1 && "${SKIP_DEPLOY:-0}" != 1 ]]; then
    python3 ../Shared/BuildTools/publish_latest.py "$app"
fi

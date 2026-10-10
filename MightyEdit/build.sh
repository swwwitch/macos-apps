#!/bin/zsh
set -eu
cd "${0:A:h}"
python3 ../Shared/MenuBarPresence/sync.py
python3 "../Shared/AppStandards/sync-surface.py"
# B15: regenerate ja/en/zh-Hans/ko resources from the single table (validates keys and placeholders).
python3 make-resources.py
# Shared updater (Sparkle): unconfigured builds show 準備中 and make no network access.
UPDATER_ROOT="$PWD/../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
# Keep a certificate-backed identity across builds so Accessibility grants can
# track the app rather than a changing ad-hoc code hash. Do not silently fall back.
SIGNING_IDENTITY="${MIGHTYEDIT_SIGNING_IDENTITY:-301A41C0A37B6B578B7477229015992E8AA34E44}"
# Developer ID releases must never fall back to an App Store or ad-hoc identity.
DISTRIBUTION_MODE="${MIGHTYEDIT_DISTRIBUTION:-local}"
SIGNING_OPTIONS=(--timestamp=none)
if [[ "$DISTRIBUTION_MODE" == "developer-id" ]]; then
    IDENTITIES=$(security find-identity -v -p codesigning)
    DEVELOPER_ID=$(printf '%s\n' "$IDENTITIES" | awk '/"Developer ID Application:.*\(PL9S9PXX96\)"/ {print $2; exit}')
    if [[ -z "$DEVELOPER_ID" ]]; then
        print -u2 "Developer ID Application certificate with private key is required for team PL9S9PXX96."
        exit 1
    fi
    SIGNING_IDENTITY="$DEVELOPER_ID"
    SIGNING_OPTIONS=(--options runtime --timestamp)
elif [[ "$DISTRIBUTION_MODE" != "local" ]]; then
    print -u2 "Unknown MIGHTYEDIT_DISTRIBUTION: $DISTRIBUTION_MODE"
    exit 1
fi
STAGING=$(mktemp -d "${TMPDIR:-/tmp/}textpalette.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/MightyEdit.app"
mkdir -p "$APP/Contents/MacOS"
xcrun swiftc Source/AppSurface.swift Source/StartupWindow.swift Source/HelpDocument.swift Source/SettingsSection.swift Source/MenuBarPresence.swift "${UPDATE_SWIFT_FLAGS[@]}" Source/UpdateSupport.swift -O -target "$(uname -m)-apple-macos13.0" -module-cache-path "$STAGING/ModuleCache" -framework AppKit -framework ApplicationServices -framework Carbon Source/Localization.swift Source/LocalizationFallback.swift Source/LineTools.swift Source/LineToolsPanel.swift Source/HTMLMinifier.swift Source/TextTransform.swift Source/AccessibilityPermission.swift Source/TypographyOption.swift Source/TypographyPanel.swift Source/PaletteConfiguration.swift Source/AppAutoShow.swift Source/PaletteTargetSession.swift Source/DateTransform.swift Source/LocalHelp.swift Source/PaletteButton.swift Source/ResponsiveButtonGrid.swift Source/HotkeyEditor.swift Source/HotkeyReleaseGate.swift Source/HotkeyScope.swift Source/GlobalShortcuts.swift Source/PaletteShortcut.swift Source/ExcludedAppList.swift Source/ExcludedApps.swift ../Shared/LoginAtLaunch/LoginAtLaunch.swift Source/WrapPanel.swift Source/SpecialListPanel.swift Source/ContinuationSelection.swift Source/SettingsSync.swift Source/WindowActivationPolicy.swift Source/AboutSection.swift Source/main.swift -o "$APP/Contents/MacOS/MightyEdit"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MightyEdit</string>
<key>CFBundleIdentifier</key><string>jp.local.TextPalette</string>
<key>CFBundleName</key><string>MightyEdit</string>
<key>CFBundleIconFile</key><string>MightyEdit</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>ja</string><string>en</string><string>zh-Hans</string><string>ko</string></array>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.2.14</string>
<key>CFBundleVersion</key><string>88</string>
<key>SWNoteArticleURL</key><string>https://note.com/swwwitch/n/n08be828d4393</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>LSMultipleInstancesProhibited</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>© 2026 swwwitch</string>
<key>SWAppFamily</key><string>swwwitch</string>
</dict></plist>
PLIST
mkdir -p "$APP/Contents/Resources"
cp Assets/MightyEdit.icns "$APP/Contents/Resources/MightyEdit.icns"
for lproj in Resources/*.lproj; do ditto "$lproj" "$APP/Contents/Resources/${lproj:t}"; done
embed_updates "$APP"
"$UPDATER_ROOT/../AppIcon/apply-app-icon.sh" "$APP"
xattr -cr "$APP"
# configure.py signs the embedded Sparkle ad hoc; a Developer ID (hardened runtime) build
# must sign it with the same identity so library validation accepts it.
if [[ "$DISTRIBUTION_MODE" == "developer-id" && -d "$APP/Contents/Frameworks/Sparkle.framework" ]]; then
    codesign --force --deep --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" "$APP/Contents/Frameworks/Sparkle.framework"
fi
codesign --force --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" "$APP"
codesign --verify --deep --strict "$APP"
if [[ -e MightyEdit.app ]]; then
    mkdir -p Backups
    mv MightyEdit.app "Backups/MightyEdit-$(date +%Y%m%d-%H%M%S).app"
fi
ditto "$APP" MightyEdit.app
printf '%s\n' "$PWD/MightyEdit.app"

if [[ "${APP_STORE_BUILD:-0}" != 1 ]]; then
    python3 ../Shared/BuildTools/publish_latest.py "$APP"
fi

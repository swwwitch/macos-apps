#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h}"
python3 "$ROOT/../../Shared/MenuBarPresence/sync.py"
python3 "$ROOT/../../Shared/HotkeyManifest/sync.py"
python3 "$ROOT/../../Shared/AppStandards/sync-surface.py"
python3 "$ROOT/../../Shared/SettingsSync/sync.py"
python3 "$ROOT/../../Shared/HotkeyRecorder/sync.py"
UPDATER_ROOT="$ROOT/../../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
BUILD=$(mktemp -d /private/tmp/yohakutrimmer-build.XXXXXX)
trap 'rm -rf "$BUILD"' EXIT
APP="$BUILD/YohakuTrimmer.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc "$ROOT/Sources/AppSurface.swift" "$ROOT/Sources/StartupWindow.swift" "$ROOT/Sources/SettingsSection.swift" "$ROOT/Sources/AboutSection.swift" "$ROOT/Sources/MenuBarPresence.swift" "${UPDATE_SWIFT_FLAGS[@]}" "$ROOT/Sources/UpdateSupport.swift" "$ROOT/Sources/AccessibilityPermission.swift" "$ROOT/Sources/WindowActivationPolicy.swift" -parse-as-library -O -target arm64-apple-macos14.0 \
  -module-cache-path "$BUILD/ModuleCache" \
  -framework Carbon -framework AppKit -framework ImageIO -framework UniformTypeIdentifiers \
  "$ROOT/Sources/HelpDocument.swift" "$ROOT/Sources/LocalHelp.swift" "$ROOT/Sources/YohakuTrimmerApp.swift" "$ROOT/Sources/MarginProcessor.swift" "$ROOT/Sources/Localization.swift" "$ROOT/Sources/LoginAtLaunch.swift" "$ROOT/Sources/HotkeyManifest.swift" "$ROOT/Sources/SettingsSync.swift" "$ROOT/Sources/HotkeyRecorder.swift" \
  -o "$APP/Contents/MacOS/YohakuTrimmer"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/PkgInfo" "$APP/Contents/PkgInfo"
cp "$ROOT/Resources/AppIcon-source.png" "$APP/Contents/Resources/AppIcon.png"
cp "$ROOT/Resources/YohakuTrimmer-Mustard.icns" "$APP/Contents/Resources/YohakuTrimmer-Mustard.icns"
cp -R "$ROOT/Localizations/"*.lproj "$APP/Contents/Resources/"
python3 "$ROOT/Tests/check-localization.py" --app "$APP"
embed_updates "$APP"
"$UPDATER_ROOT/../AppIcon/apply-app-icon.sh" "$APP"
xattr -cr "$APP"
# Sign with the team certificate so the designated requirement stays stable across rebuilds
# (Accessibility and other permissions carry over). YOHAKUTRIMMER_SIGNING_IDENTITY overrides it;
# Shared/AppStore/TestFlight/package.py re-signs App Store builds with the entitlements.
SIGNING_IDENTITY="${YOHAKUTRIMMER_SIGNING_IDENTITY:-301A41C0A37B6B578B7477229015992E8AA34E44}"
SIGNING_OPTIONS=(--timestamp=none)
codesign --force --deep --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" "$APP"
codesign --verify --deep --strict "$APP"
if [[ "${APP_STORE_BUILD:-0}" != 1 ]]; then
    python3 "$ROOT/../../Shared/BuildTools/publish_latest.py" "$APP"
fi
mkdir -p "$ROOT/build"
if [[ -e "$ROOT/build/YohakuTrimmer.app" ]]; then
    mv "$ROOT/build/YohakuTrimmer.app" "$BUILD/previous.app"
fi
ditto --norsrc --noextattr "$APP" "$ROOT/build/YohakuTrimmer.app"
xattr -cr "$ROOT/build/YohakuTrimmer.app"
codesign --verify --deep --strict "$ROOT/build/YohakuTrimmer.app"
echo "$ROOT/build/YohakuTrimmer.app"

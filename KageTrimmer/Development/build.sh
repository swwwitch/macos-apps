#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h}"
python3 "$ROOT/../../Shared/MenuBarPresence/sync.py"
python3 "$ROOT/../../Shared/AppStandards/sync-surface.py"
UPDATER_ROOT="$ROOT/../../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
BUILD=$(mktemp -d /private/tmp/kagetrimmer-build.XXXXXX)
trap 'rm -rf "$BUILD"' EXIT
APP="$BUILD/KageTrimmer.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc "$ROOT/Sources/AppSurface.swift" "$ROOT/Sources/StartupWindow.swift" "$ROOT/Sources/SettingsSection.swift" "$ROOT/Sources/AboutSection.swift" "$ROOT/Sources/MenuBarPresence.swift" "${UPDATE_SWIFT_FLAGS[@]}" "$ROOT/Sources/UpdateSupport.swift" "$ROOT/Sources/AccessibilityPermission.swift" -parse-as-library -O -target arm64-apple-macos14.0 \
  -module-cache-path "$BUILD/ModuleCache" \
  -framework Carbon -framework AppKit -framework CoreImage -framework ImageIO -framework UniformTypeIdentifiers \
  "$ROOT/Sources/HelpDocument.swift" "$ROOT/Sources/LocalHelp.swift" "$ROOT/Sources/SoftShadowApp.swift" "$ROOT/Sources/ShadowProcessor.swift" "$ROOT/Sources/Localization.swift" "$ROOT/Sources/LoginAtLaunch.swift" \
  -o "$APP/Contents/MacOS/KageTrimmer"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/PkgInfo" "$APP/Contents/PkgInfo"
cp "$ROOT/Resources/AppIcon-source.png" "$APP/Contents/Resources/AppIcon.png"
cp "$ROOT/Resources/KageTrimmer-Mustard.icns" "$APP/Contents/Resources/KageTrimmer-Mustard.icns"
cp -R "$ROOT/Localizations/"*.lproj "$APP/Contents/Resources/"
python3 "$ROOT/Tests/check-localization.py" --app "$APP"
embed_updates "$APP"
"$UPDATER_ROOT/../AppIcon/apply-app-icon.sh" "$APP"
xattr -cr "$APP"
# Sign with the team certificate so the designated requirement stays stable across rebuilds
# (Accessibility and other permissions carry over). KAGETRIMMER_SIGNING_IDENTITY overrides it;
# Shared/AppStore/TestFlight/package.py re-signs App Store builds with the entitlements.
SIGNING_IDENTITY="${KAGETRIMMER_SIGNING_IDENTITY:-301A41C0A37B6B578B7477229015992E8AA34E44}"
SIGNING_OPTIONS=(--timestamp=none)
codesign --force --deep --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" "$APP"
codesign --verify --deep --strict "$APP"
if [[ "${APP_STORE_BUILD:-0}" != 1 ]]; then
    python3 "$ROOT/../../Shared/BuildTools/publish_latest.py" "$APP"
fi
mkdir -p "$ROOT/build"
if [[ -e "$ROOT/build/KageTrimmer.app" ]]; then
    mv "$ROOT/build/KageTrimmer.app" "$BUILD/previous.app"
fi
ditto --norsrc --noextattr "$APP" "$ROOT/build/KageTrimmer.app"
xattr -cr "$ROOT/build/KageTrimmer.app"
codesign --verify --deep --strict "$ROOT/build/KageTrimmer.app"
echo "$ROOT/build/KageTrimmer.app"

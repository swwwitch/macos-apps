#!/bin/zsh
# ./build.sh           build build/ScreenTake.app
# ./build.sh --deploy  also place the verified build in /Applications and Latest Builds
set -euo pipefail
cd "${0:A:h}"
UPDATER_ROOT="$PWD/../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
stage=$(mktemp -d /private/tmp/ScreenTake-build.XXXXXX)
trap 'rm -rf "$stage"' EXIT
python3 make-resources.py
app="$stage/ScreenTake.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Info.plist "$app/Contents/Info.plist"
cp -R Resources/*.lproj "$app/Contents/Resources/"
cp Assets/ScreenTake.icns README.md "$app/Contents/Resources/"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx15.0 -module-cache-path "$stage/cache" \
  -framework AppKit -framework SwiftUI -framework ServiceManagement -framework Carbon -framework ApplicationServices -framework ScreenCaptureKit -framework AVFoundation -framework AVKit -framework CoreImage -framework CoreMedia "${UPDATE_SWIFT_FLAGS[@]}" \
  ../Shared/AppStandards/{SettingsSection,LaunchPresenceSection,AppHeader,AppSurface,StartupWindow,HelpDocument,AboutSection}.swift ../Shared/MenuBarPresence/MenuBarPresence.swift ../Shared/HotkeyRecorder/HotkeyRecorder.swift \
  ../Shared/LoginAtLaunch/LoginAtLaunch.swift ../Shared/Updater/UpdateSupport.swift ../Shared/SettingsSync/SettingsSync.swift \
  ../Shared/HotkeyManifest/HotkeyManifest.swift Source/{Project,Recorder,Compositor,Exporter,Editor,Support,LaunchPolicy,main}.swift -o "$app/Contents/MacOS/ScreenTake"
embed_updates "$app"
"$UPDATER_ROOT/../AppIcon/apply-app-icon.sh" "$app"
xattr -cr "$app"
# Local builds sign with the team certificate so the designated requirement stays stable across rebuilds
# (Accessibility and other permissions carry over). SCREENTAKE_SIGNING_IDENTITY overrides it.
SIGNING_IDENTITY="${SCREENTAKE_SIGNING_IDENTITY:-301A41C0A37B6B578B7477229015992E8AA34E44}"
SIGNING_OPTIONS=(--timestamp=none)
codesign --force --sign "$SIGNING_IDENTITY" --entitlements ScreenTake.entitlements "${SIGNING_OPTIONS[@]}" "$app"
codesign --verify --deep --strict "$app"
mkdir -p build
if [[ -d build/ScreenTake.app ]]; then
  backup="Backups/build-$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p "$backup"
  mv build/ScreenTake.app "$backup/"
fi
ditto "$app" build/ScreenTake.app
print "Built build/ScreenTake.app"

if [[ "${1:-}" == "--deploy" && "${APP_STORE_BUILD:-0}" != 1 ]]; then
    python3 ../Shared/BuildTools/publish_latest.py "$PWD/build/ScreenTake.app"
fi

#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
python3 ../Shared/MenuBarPresence/sync.py
UPDATER_ROOT="$PWD/../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
stage=$(mktemp -d /private/tmp/CCAutoUpdateOff-build.XXXXXX)
trap 'rm -rf "$stage"' EXIT
app="$stage/CCAutoUpdateOff.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Info.plist "$app/Contents/Info.plist"
cp -R Resources/*.lproj "$app/Contents/Resources/"
cp Resources/PrivacyInfo.xcprivacy README.md Assets/CCAutoUpdateOff.icns "$app/Contents/Resources/"
for arch in arm64 x86_64; do
  xcrun swiftc "${UPDATE_SWIFT_FLAGS[@]}" -swift-version 5 -O -target "$arch-apple-macosx13.0" -module-cache-path "$stage/cache" -framework AppKit -framework SwiftUI -framework Carbon -framework ServiceManagement -framework UserNotifications ../Shared/AppStandards/AppHeader.swift ../Shared/AppStandards/AppSurface.swift ../Shared/AppStandards/StartupWindow.swift ../Shared/AppStandards/HelpDocument.swift ../Shared/AppStandards/SettingsSection.swift ../Shared/AppStandards/AboutSection.swift ../Shared/AppStandards/WindowActivationPolicy.swift ../Shared/LoginAtLaunch/LoginAtLaunch.swift Source/CCAutoUpdate.swift Source/Watcher.swift Source/LaunchPolicy.swift Source/MenuBarPresence.swift Source/UpdateSupport.swift Source/main.swift -o "$stage/CCAutoUpdateOff-$arch"
done
xcrun lipo -create "$stage/CCAutoUpdateOff-arm64" "$stage/CCAutoUpdateOff-x86_64" -output "$app/Contents/MacOS/CCAutoUpdateOff"
xcrun lipo -verify_arch arm64 "$app/Contents/MacOS/CCAutoUpdateOff"
xcrun lipo -verify_arch x86_64 "$app/Contents/MacOS/CCAutoUpdateOff"
embed_updates "$app"
"$UPDATER_ROOT/../AppIcon/apply-app-icon.sh" "$app"
xattr -cr "$app"
# Local builds sign with the team certificate so the designated requirement stays stable across rebuilds
# (Accessibility and other permissions carry over). CCAUTOUPDATEOFF_SIGNING_IDENTITY overrides it.
SIGNING_IDENTITY="${CCAUTOUPDATEOFF_SIGNING_IDENTITY:-301A41C0A37B6B578B7477229015992E8AA34E44}"
SIGNING_OPTIONS=(--timestamp=none)
codesign --force --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" "$app"
codesign --verify --deep --strict "$app"
mkdir -p build
if [[ -d build/CCAutoUpdateOff.app ]]; then
  backup="Backups/build-$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p "$backup"
  mv build/CCAutoUpdateOff.app "$backup/"
fi
ditto "$app" build/CCAutoUpdateOff.app
codesign --verify --deep --strict build/CCAutoUpdateOff.app
printf 'Built: %s\n' build/CCAutoUpdateOff.app

if [[ "${APP_STORE_BUILD:-0}" != 1 && "${SKIP_DEPLOY:-0}" != 1 ]]; then
    python3 ../Shared/BuildTools/publish_latest.py "$app"
fi

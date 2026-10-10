#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
python3 ../Shared/MenuBarPresence/sync.py
UPDATER_ROOT="$PWD/../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
stage=$(mktemp -d /private/tmp/IdBackgroundOff-build.XXXXXX)
trap 'rm -rf "$stage"' EXIT
app="$stage/IdBackgroundOff.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Info.plist "$app/Contents/Info.plist"
cp -R Resources/*.lproj "$app/Contents/Resources/"
cp Resources/PrivacyInfo.xcprivacy README.md Assets/IdBackgroundOff.icns "$app/Contents/Resources/"
for arch in arm64 x86_64; do
  xcrun swiftc "${UPDATE_SWIFT_FLAGS[@]}" -swift-version 5 -O -target "$arch-apple-macosx13.0" -module-cache-path "$stage/cache" -framework AppKit -framework SwiftUI -framework Carbon ../Shared/AppStandards/AppHeader.swift ../Shared/AppStandards/AppSurface.swift ../Shared/AppStandards/StartupWindow.swift ../Shared/AppStandards/HelpDocument.swift Source/AsyncExports.swift Source/MenuBarPresence.swift Source/UpdateSupport.swift Source/main.swift -o "$stage/IdBackgroundOff-$arch"
done
xcrun lipo -create "$stage/IdBackgroundOff-arm64" "$stage/IdBackgroundOff-x86_64" -output "$app/Contents/MacOS/IdBackgroundOff"
xcrun lipo -verify_arch arm64 "$app/Contents/MacOS/IdBackgroundOff"
xcrun lipo -verify_arch x86_64 "$app/Contents/MacOS/IdBackgroundOff"
embed_updates "$app"
"$UPDATER_ROOT/../AppIcon/apply-app-icon.sh" "$app"
xattr -cr "$app"
# Local builds sign with the team certificate so the designated requirement stays stable across rebuilds
# (Accessibility and other permissions carry over). IDBACKGROUNDOFF_SIGNING_IDENTITY overrides it.
SIGNING_IDENTITY="${IDBACKGROUNDOFF_SIGNING_IDENTITY:-301A41C0A37B6B578B7477229015992E8AA34E44}"
SIGNING_OPTIONS=(--timestamp=none)
codesign --force --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" "$app"
codesign --verify --deep --strict "$app"
mkdir -p build
if [[ -d build/IdBackgroundOff.app ]]; then
  backup="Backups/build-$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p "$backup"
  mv build/IdBackgroundOff.app "$backup/"
fi
ditto "$app" build/IdBackgroundOff.app
codesign --verify --deep --strict build/IdBackgroundOff.app
printf 'Built: %s\n' build/IdBackgroundOff.app

if [[ "${APP_STORE_BUILD:-0}" != 1 && "${SKIP_DEPLOY:-0}" != 1 ]]; then
    python3 ../Shared/BuildTools/publish_latest.py "$app"
fi

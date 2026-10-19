#!/bin/zsh
# Builds BreaklineTrimmer.app (arm64 + x86_64), signs it with the team certificate and, unless SKIP_DEPLOY=1,
# places it in /Applications and Latest Builds (Shared/BuildTools/deploy_both.py).
set -euo pipefail
cd "${0:A:h}"
UPDATER_ROOT="$PWD/../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
stage=$(mktemp -d /private/tmp/BreaklineTrimmer-build.XXXXXX)
trap 'rm -rf "$stage"' EXIT
app="$stage/BreaklineTrimmer.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Info.plist "$app/Contents/Info.plist"
cp -R Resources/*.lproj "$app/Contents/Resources/"
cp README.md Assets/BreaklineTrimmer.icns "$app/Contents/Resources/"
# Shared parts are compiled from Shared directly (no copies to keep in sync).
shared=(../Shared/AppStandards/AppHeader.swift ../Shared/AppStandards/AppSurface.swift ../Shared/AppStandards/StartupWindow.swift
        ../Shared/AppStandards/HelpDocument.swift ../Shared/AppStandards/SettingsSection.swift ../Shared/AppStandards/AboutSection.swift
        ../Shared/LoginAtLaunch/LoginAtLaunch.swift ../Shared/SettingsSync/SettingsSync.swift
        ../Shared/MenuBarPresence/MenuBarPresence.swift ../Shared/Updater/UpdateSupport.swift)
for arch in arm64 x86_64; do
  xcrun swiftc "${UPDATE_SWIFT_FLAGS[@]}" -swift-version 5 -O -target "$arch-apple-macosx14.0" -module-cache-path "$stage/cache" \
    -framework AppKit -framework SwiftUI -framework Carbon -framework ServiceManagement -framework UniformTypeIdentifiers -framework ImageIO \
    "${shared[@]}" Source/TrimGeometry.swift Source/main.swift -o "$stage/BreaklineTrimmer-$arch"
done
xcrun lipo -create "$stage/BreaklineTrimmer-arm64" "$stage/BreaklineTrimmer-x86_64" -output "$app/Contents/MacOS/BreaklineTrimmer"
xcrun lipo -verify_arch arm64 "$app/Contents/MacOS/BreaklineTrimmer"
xcrun lipo -verify_arch x86_64 "$app/Contents/MacOS/BreaklineTrimmer"
python3 Tests/check-localization.py --app "$app"
embed_updates "$app"
"$UPDATER_ROOT/../AppIcon/apply-app-icon.sh" "$app"
xattr -cr "$app"
# Local builds sign with the team certificate so the designated requirement stays stable across rebuilds.
# BREAKLINETRIMMER_SIGNING_IDENTITY overrides it.
SIGNING_IDENTITY="${BREAKLINETRIMMER_SIGNING_IDENTITY:-301A41C0A37B6B578B7477229015992E8AA34E44}"
SIGNING_OPTIONS=(--timestamp=none)
codesign --force --deep --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" "$app"
codesign --verify --deep --strict "$app"
mkdir -p build
if [[ -d build/BreaklineTrimmer.app ]]; then
  backup="Backups/build-$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p "$backup"
  mv build/BreaklineTrimmer.app "$backup/"
fi
ditto "$app" build/BreaklineTrimmer.app
codesign --verify --deep --strict build/BreaklineTrimmer.app
printf 'Built: %s\n' build/BreaklineTrimmer.app

if [[ "${APP_STORE_BUILD:-0}" != 1 && "${SKIP_DEPLOY:-0}" != 1 ]]; then
    python3 ../Shared/BuildTools/publish_latest.py "$app"
fi

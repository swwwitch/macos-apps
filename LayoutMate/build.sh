#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
UPDATER_ROOT="$PWD/../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
stage=$(mktemp -d /private/tmp/LayoutMate-build.XXXXXX)
trap 'rm -rf "$stage"' EXIT
app="$stage/LayoutMate.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
# Localizable.strings, Help.txt, InfoPlist.strings and Info.plist are generated from make-resources.py.
python3 make-resources.py >/dev/null
cp Info.plist "$app/Contents/Info.plist"
cp -R Resources/*.lproj "$app/Contents/Resources/"
cp Resources/PrivacyInfo.xcprivacy README.md Assets/LayoutMate.icns "$app/Contents/Resources/"
# Shared parts are compiled straight from Shared (no local copies to keep in sync).
SHARED=(../Shared/AppStandards/AppHeader.swift ../Shared/AppStandards/AppSurface.swift ../Shared/AppStandards/StartupWindow.swift
        ../Shared/AppStandards/HelpDocument.swift ../Shared/AppStandards/SettingsSection.swift ../Shared/AppStandards/AboutSection.swift
        ../Shared/LoginAtLaunch/LoginAtLaunch.swift ../Shared/Accessibility/AccessibilityPermission.swift ../Shared/MenuBarPresence/MenuBarPresence.swift
        ../Shared/Updater/UpdateSupport.swift ../Shared/HotkeyRecorder/HotkeyRecorder.swift
        ../Shared/DragPan/DragPanMachine.swift ../Shared/DragPan/DragPan.swift)
for arch in arm64 x86_64; do
  xcrun swiftc "${UPDATE_SWIFT_FLAGS[@]}" -swift-version 5 -O -target "$arch-apple-macosx13.0" -module-cache-path "$stage/cache" \
    -framework AppKit -framework SwiftUI -framework Carbon -framework ServiceManagement -framework ApplicationServices \
    "${SHARED[@]}" Source/InDesignScript.swift Source/DoubleTap.swift Source/VersionPinning.swift Source/InDesignUI.swift Source/AsyncExports.swift Source/ApplicationBar.swift Source/main.swift -o "$stage/LayoutMate-$arch"
done
xcrun lipo -create "$stage/LayoutMate-arm64" "$stage/LayoutMate-x86_64" -output "$app/Contents/MacOS/LayoutMate"
xcrun lipo -verify_arch arm64 "$app/Contents/MacOS/LayoutMate"
xcrun lipo -verify_arch x86_64 "$app/Contents/MacOS/LayoutMate"
embed_updates "$app"
"$UPDATER_ROOT/../AppIcon/apply-app-icon.sh" "$app"
xattr -cr "$app"
# Local builds sign with the team certificate (PL9S9PXX96, login keychain) so the designated requirement stays stable across
# rebuilds (Accessibility and Automation grants carry over). LAYOUTMATE_SIGNING_IDENTITY overrides it.
SIGNING_IDENTITY="${LAYOUTMATE_SIGNING_IDENTITY:-301A41C0A37B6B578B7477229015992E8AA34E44}"
SIGNING_OPTIONS=(--timestamp=none)
codesign --force --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" "$app"
codesign --verify --deep --strict "$app"
mkdir -p build
if [[ -d build/LayoutMate.app ]]; then
  backup="Backups/build-$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p "$backup"
  mv build/LayoutMate.app "$backup/"
fi
ditto "$app" build/LayoutMate.app
codesign --verify --deep --strict build/LayoutMate.app
printf 'Built: %s\n' build/LayoutMate.app

if [[ "${APP_STORE_BUILD:-0}" != 1 && "${SKIP_DEPLOY:-0}" != 1 ]]; then
    python3 ../Shared/BuildTools/publish_latest.py "$app"
fi

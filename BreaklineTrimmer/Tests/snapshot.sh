#!/bin/zsh
# Renders the main window (several states, light and dark) and the settings to PNG files offscreen.
# usage: Tests/snapshot.sh <output folder> <image> [language]   (language: ja, en, zh-Hans, ko; default ja)
# The settings are read from and written to a separate defaults domain, so the app's own settings are not touched.
set -euo pipefail
cd "${0:A:h}/.."
out="${1:?output folder}"; image="${2:?image}"; lang="${3:-ja}"
mkdir -p "$out"
stage=$(mktemp -d /private/tmp/BreaklineTrimmer-snapshot.XXXXXX)
trap 'rm -rf "$stage"' EXIT
app="$stage/BreaklineTrimmerSnapshot.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp -R Resources/*.lproj Assets/BreaklineTrimmer.icns "$app/Contents/Resources/"
plutil -convert xml1 -o "$app/Contents/Info.plist" Info.plist
plutil -replace CFBundleExecutable -string BreaklineTrimmerSnapshot "$app/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string jp.dtp-transit.breaklinetrimmer.snapshot "$app/Contents/Info.plist"
# Top-level statements are not allowed outside main.swift (even in an inactive #if), so drop the launch block.
sed '/^#if !SNAPSHOT/,/^#endif/d' Source/main.swift > "$stage/App.swift"
xcrun swiftc -D SNAPSHOT -D APP_STORE -swift-version 5 -O -module-cache-path "$stage/cache" \
  ../Shared/AppStandards/AppHeader.swift ../Shared/AppStandards/AppSurface.swift ../Shared/AppStandards/StartupWindow.swift \
  ../Shared/AppStandards/HelpDocument.swift ../Shared/AppStandards/SettingsSection.swift ../Shared/AppStandards/AboutSection.swift \
  ../Shared/LoginAtLaunch/LoginAtLaunch.swift ../Shared/SettingsSync/SettingsSync.swift ../Shared/MenuBarPresence/MenuBarPresence.swift \
  ../Shared/Updater/UpdateSupport.swift Source/TrimGeometry.swift "$stage/App.swift" Tests/Snapshot.swift \
  -o "$app/Contents/MacOS/BreaklineTrimmerSnapshot" 2>&1 | grep -E "error" || true
"$app/Contents/MacOS/BreaklineTrimmerSnapshot" "$out" "$image" -AppleLanguages "($lang)"
defaults delete jp.dtp-transit.breaklinetrimmer.snapshot >/dev/null 2>&1 || true

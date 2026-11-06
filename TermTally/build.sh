#!/bin/zsh
# ./build.sh           build build/TermTally.app
# ./build.sh --deploy  also place the verified build in /Applications and Latest Builds
set -euo pipefail
cd "${0:A:h}"
UPDATER_ROOT="$PWD/../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
stage=$(mktemp -d /private/tmp/TermTally-build.XXXXXX)
trap 'rm -rf "$stage"' EXIT
python3 make-resources.py
app="$stage/TermTally.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Info.plist "$app/Contents/Info.plist"
cp -R Resources/*.lproj "$app/Contents/Resources/"
cp Assets/TermTally.icns README.md "$app/Contents/Resources/"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx13.0 -module-cache-path "$stage/cache" \
  -framework PDFKit -framework AppKit -framework SwiftUI -framework ServiceManagement -framework Carbon "${UPDATE_SWIFT_FLAGS[@]}" \
  ../Shared/AppStandards/{SettingsSection,LaunchPresenceSection,AppHeader,AppSurface,StartupWindow,HelpDocument,AboutSection}.swift ../Shared/MenuBarPresence/MenuBarPresence.swift ../Shared/HotkeyRecorder/HotkeyRecorder.swift ../Shared/Accessibility/AccessibilityPermission.swift \
  ../Shared/LoginAtLaunch/LoginAtLaunch.swift ../Shared/Updater/UpdateSupport.swift ../Shared/SettingsSync/SettingsSync.swift \
  Source/{Matching,VariantDictionary,DictionaryData,PDFText,Targets,AppModel,Views,LaunchPolicy,main}.swift -o "$app/Contents/MacOS/TermTally"
embed_updates "$app"
"$UPDATER_ROOT/../AppIcon/apply-app-icon.sh" "$app"
xattr -cr "$app"
# Local builds sign with the team certificate so the designated requirement stays stable across rebuilds
# (Accessibility and other permissions carry over). TERMTALLY_SIGNING_IDENTITY overrides it.
SIGNING_IDENTITY="${TERMTALLY_SIGNING_IDENTITY:-301A41C0A37B6B578B7477229015992E8AA34E44}"
SIGNING_OPTIONS=(--timestamp=none)
codesign --force --sign "$SIGNING_IDENTITY" "${SIGNING_OPTIONS[@]}" "$app"
codesign --verify --deep --strict "$app"
mkdir -p build
if [[ -d build/TermTally.app ]]; then
  backup="Backups/build-$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p "$backup"
  mv build/TermTally.app "$backup/"
fi
ditto "$app" build/TermTally.app
print "Built build/TermTally.app"

if [[ "${1:-}" == "--deploy" && "${APP_STORE_BUILD:-0}" != 1 ]]; then
    python3 ../Shared/BuildTools/publish_latest.py "$PWD/build/TermTally.app"
fi

#!/bin/zsh
set -eu
cd "${0:A:h}"
python3 ../Shared/MenuBarPresence/sync.py
python3 "../Shared/AppStandards/sync-surface.py"
python3 make-resources.py
UPDATER_ROOT="$PWD/../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
STAGING=$(mktemp -d "${TMPDIR:-/tmp}/commanddee-build.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/CommandDee.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc -O -target arm64-apple-macos13.0 -module-cache-path "$STAGING/cache" -framework AppKit -framework ApplicationServices -framework ServiceManagement "${UPDATE_SWIFT_FLAGS[@]}" Sources/*.swift -o "$APP/Contents/MacOS/CommandDee"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>ja</string><string>en</string><string>zh-Hans</string><string>ko</string></array>
<key>CFBundleExecutable</key><string>CommandDee</string>
<key>CFBundleIdentifier</key><string>jp.local.CommandDee</string>
<key>CFBundleIconFile</key><string>CommandDee</string>
<key>CFBundleName</key><string>CommandDee</string>
<key>CFBundleDisplayName</key><string>CommandDee</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.8.20</string>
<key>CFBundleVersion</key><string>47</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>LSMultipleInstancesProhibited</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>© 2026 swwwitch</string>
<key>SWAppFamily</key><string>swwwitch</string>
<key>SWNoteArticleURL</key><string>https://note.com/swwwitch/n/n6913d7c34467</string>
<key>NSAppleEventsUsageDescription</key><string>Finder／Path Finderで選択したファイルやフォルダを取得し、複製または名前変更します。</string>
</dict></plist>
PLIST
cp Assets/CommandDee.icns "$APP/Contents/Resources/CommandDee.icns"
for lproj in Resources/*.lproj; do ditto "$lproj" "$APP/Contents/Resources/${lproj:t}"; done
embed_updates "$APP"
"$UPDATER_ROOT/../AppIcon/apply-app-icon.sh" "$APP"
xattr -cr "$APP"
# A certificate-backed identity (team PL9S9PXX96) so Accessibility grants follow the app
# rather than a changing ad-hoc hash (same as KakkoReplace / MightyEdit).
SIGNING_IDENTITY="${COMMANDDEE_SIGNING_IDENTITY:-301A41C0A37B6B578B7477229015992E8AA34E44}"
codesign --force --sign "$SIGNING_IDENTITY" --timestamp=none "$APP"
codesign --verify --deep --strict "$APP"
if [[ -e CommandDee.app ]]; then
    mkdir -p Backups
    mv CommandDee.app "Backups/CommandDee-$(date +%Y%m%d-%H%M%S).app"
fi
ditto --noextattr --norsrc "$APP" CommandDee.app
codesign --verify --deep --strict CommandDee.app
printf '%s\n' "$PWD/CommandDee.app"

if [[ "${APP_STORE_BUILD:-0}" != 1 ]]; then
    python3 ../Shared/BuildTools/publish_latest.py "$APP"
fi

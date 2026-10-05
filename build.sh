#!/bin/zsh
set -eu
cd "${0:A:h}"
STAGING=$(mktemp -d "${TMPDIR:-/tmp}/commanddee-build.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/CommandDee.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc -O -target arm64-apple-macos13.0 -module-cache-path "$STAGING/cache" -framework AppKit -framework ApplicationServices -framework ServiceManagement Sources/*.swift -o "$APP/Contents/MacOS/CommandDee"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>CommandDee</string>
<key>CFBundleIdentifier</key><string>jp.local.CommandDee</string>
<key>CFBundleIconFile</key><string>CommandDee</string>
<key>CFBundleName</key><string>CommandDee</string>
<key>CFBundleDisplayName</key><string>CommandDee</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.5.1</string>
<key>CFBundleVersion</key><string>10</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>LSMultipleInstancesProhibited</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppleEventsUsageDescription</key><string>Finder／Path Finderで選択したファイルやフォルダーを取得し、複製または名前変更します。</string>
</dict></plist>
PLIST
cp Assets/CommandDee.icns "$APP/Contents/Resources/CommandDee.icns"
xattr -cr "$APP"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
if [[ -e CommandDee.app ]]; then
    mkdir -p Backups
    mv CommandDee.app "Backups/CommandDee-$(date +%Y%m%d-%H%M%S).app"
fi
ditto --noextattr --norsrc "$APP" CommandDee.app
codesign --verify --deep --strict CommandDee.app
printf '%s\n' "$PWD/CommandDee.app"

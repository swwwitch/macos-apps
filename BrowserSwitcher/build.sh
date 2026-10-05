#!/bin/zsh
set -eu
cd "${0:A:h}"
UPDATER_ROOT="$PWD/../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
DEST="$PWD/BrowserSwitcher.app"
STAGING=$(mktemp -d "${TMPDIR%/}/browser-switcher.XXXXXX")
APP="$STAGING/BrowserSwitcher.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc "${UPDATE_SWIFT_FLAGS[@]}" Source/UpdateSupport.swift -O -target arm64-apple-macos13.0 -module-cache-path "$TMPDIR/browser-switcher-module-cache" -framework AppKit -framework CoreServices -framework Carbon Source/main.swift Source/Localization.swift Source/LoginAtLaunch.swift -o "$APP/Contents/MacOS/BrowserSwitcher"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>ja</string><string>en</string><string>zh-Hans</string><string>ko</string></array>
<key>CFBundleExecutable</key><string>BrowserSwitcher</string>
<key>CFBundleIdentifier</key><string>jp.local.BrowserSwitcher</string>
<key>CFBundleIconFile</key><string>BrowserSwitcher</string>
<key>CFBundleName</key><string>Browser Switcher</string>
<key>CFBundleDisplayName</key><string>ブラウザー切り換え</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.6.8</string>
<key>CFBundleVersion</key><string>19</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSMultipleInstancesProhibited</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
cp Assets/BrowserSwitcher.icns "$APP/Contents/Resources/BrowserSwitcher.icns"
cp -R Localizations/*.lproj "$APP/Contents/Resources/"
embed_updates "$APP"
xattr -cr "$APP"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
if [[ -e "$DEST" ]]; then
    BACKUP="../Shared/BuildBackups/$(date +%Y%m%d-%H%M%S)-native-switch"
    mkdir -p "$BACKUP"
    mv "$DEST" "$BACKUP/"
fi
ditto --norsrc --noextattr "$APP" "$DEST"
xattr -cr "$DEST"
printf '%s\n' "$DEST"

python3 ../Shared/BuildTools/publish_latest.py "$APP"

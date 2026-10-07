#!/bin/zsh
set -eu
cd "${0:A:h}"
python3 ../Shared/MenuBarPresence/sync.py
python3 "../Shared/AppStandards/sync-surface.py"
python3 check-localization.py
UPDATER_ROOT="$PWD/../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
DEST="$PWD/BrowserSwitcher.app"
TMP_ROOT="${TMPDIR:-/tmp}"; TMP_ROOT="${TMP_ROOT%/}"
STAGING=$(mktemp -d "$TMP_ROOT/browser-switcher.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/BrowserSwitcher.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc Source/AppSurface.swift Source/StartupWindow.swift Source/SettingsSection.swift Source/MenuBarPresence.swift "${UPDATE_SWIFT_FLAGS[@]}" Source/UpdateSupport.swift Source/AccessibilityPermission.swift -O -target arm64-apple-macos13.0 -module-cache-path "$TMP_ROOT/browser-switcher-module-cache" -framework AppKit -framework CoreServices -framework Carbon Source/ShortcutDoubleTap.swift Source/HelpDocument.swift Source/LocalHelp.swift Source/main.swift Source/Localization.swift Source/LoginAtLaunch.swift -o "$APP/Contents/MacOS/BrowserSwitcher"
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
<key>CFBundleDisplayName</key><string>ブラウザー切り替え</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.6.22</string>
<key>CFBundleVersion</key><string>42</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSMultipleInstancesProhibited</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>SWNoteArticleURL</key><string>https://note.com/swwwitch/m/m057948d2fbeb</string>
</dict></plist>
PLIST
cp Assets/BrowserSwitcher.icns "$APP/Contents/Resources/BrowserSwitcher.icns"
cp -R Localizations/*.lproj "$APP/Contents/Resources/"
python3 check-localization.py "$APP"
embed_updates "$APP"
xattr -cr "$APP"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
if [[ -e "$DEST" ]]; then
    BACKUP="../Shared/Backups/Build/$(date +%Y%m%d-%H%M%S)-native-switch"
    mkdir -p "$BACKUP"
    mv "$DEST" "$BACKUP/"
fi
ditto --norsrc --noextattr "$APP" "$DEST"
xattr -cr "$DEST"
printf '%s\n' "$DEST"

python3 ../Shared/BuildTools/publish_latest.py "$APP"

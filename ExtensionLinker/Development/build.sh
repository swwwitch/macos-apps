#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
python3 ../../Shared/MenuBarPresence/sync.py
python3 "../../Shared/AppStandards/sync-surface.py"
python3 check-localization.py
UPDATER_ROOT="$PWD/../../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
STAGING=$(mktemp -d "${TMPDIR:-/tmp}/dutigui-build.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
export CLANG_MODULE_CACHE_PATH="$STAGING/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$STAGING/module-cache"
swift build "${UPDATE_SPM_FLAGS[@]}" --build-system native --disable-sandbox --scratch-path "$STAGING/build" --cache-path "$STAGING/cache" -c release
APP="$STAGING/ExtensionLinker.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$STAGING/build/release/DutiGUI" "$APP/Contents/MacOS/DutiGUI"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>ja</string><string>en</string><string>zh-Hans</string><string>ko</string></array>
<key>CFBundleExecutable</key><string>DutiGUI</string>
<key>CFBundleIdentifier</key><string>local.takano.DutiGUI</string>
<key>CFBundleName</key><string>ExtensionLinker</string>
<key>CFBundleDisplayName</key><string>ExtensionLinker</string>
<key>CFBundleVersion</key><string>38</string>
<key>CFBundleShortVersionString</key><string>0.2.24</string>
<key>CFBundleIconFile</key><string>ExtensionLinker-Mustard</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSMultipleInstancesProhibited</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHumanReadableCopyright</key><string>© 2026 swwwitch</string>
<key>SWAppFamily</key><string>swwwitch</string>
<key>SWNoteArticleURL</key><string>https://note.com/swwwitch/m/m057948d2fbeb</string>
</dict></plist>
PLIST
# All required resources are versioned; a previously built app is unnecessary.
cp ../Assets/ExtensionLinker-Mustard.icns "$APP/Contents/Resources/ExtensionLinker-Mustard.icns"
cp -R Localizations/*.lproj "$APP/Contents/Resources/"
python3 check-localization.py "$APP"
embed_updates "$APP"
"$UPDATER_ROOT/../AppIcon/apply-app-icon.sh" "$APP"
xattr -cr "$APP"
# A certificate-backed identity (team PL9S9PXX96) so permission grants follow the app
# rather than a changing ad-hoc hash (same as KakkoReplace / MightyEdit).
SIGNING_IDENTITY="${EXTENSIONLINKER_SIGNING_IDENTITY:-301A41C0A37B6B578B7477229015992E8AA34E44}"
codesign --force --deep --sign "$SIGNING_IDENTITY" --timestamp=none "$APP"
codesign --verify --deep --strict "$APP"
backup="../Backups/before-help-build-$(date +%Y%m%d-%H%M%S)-$$"
if [[ -d ../ExtensionLinker.app ]]; then
    mkdir -p "$backup"
    mv ../ExtensionLinker.app "$backup/"
fi
ditto --noextattr --norsrc "$APP" ../ExtensionLinker.app
python3 ../../Shared/BuildTools/publish_latest.py "$APP"
codesign --verify --deep --strict ../ExtensionLinker.app
codesign --verify --deep --strict "../../Latest Builds/ExtensionLinker.app"
printf 'Built: %s\n' "../ExtensionLinker.app"

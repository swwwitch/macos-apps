#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
UPDATER_ROOT="$PWD/../../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
STAGING=$(mktemp -d "${TMPDIR:-/tmp}/dutigui-build.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
export CLANG_MODULE_CACHE_PATH="$STAGING/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$STAGING/module-cache"
swift build "${UPDATE_SPM_FLAGS[@]}" --build-system native --disable-sandbox --scratch-path "$STAGING/build" --cache-path "$STAGING/cache" -c release
APP="$STAGING/ExtLink.app"
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
<key>CFBundleName</key><string>ExtLink</string>
<key>CFBundleDisplayName</key><string>ExtLink</string>
<key>CFBundleVersion</key><string>7</string>
<key>CFBundleShortVersionString</key><string>0.2.2</string>
<key>CFBundleIconFile</key><string>ExtLink-Mustard</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSMultipleInstancesProhibited</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
# All required resources are versioned; a previously built app is unnecessary.
cp ../Assets/ExtLink-Mustard.icns "$APP/Contents/Resources/ExtLink-Mustard.icns"
cp -R Localizations/*.lproj "$APP/Contents/Resources/"
embed_updates "$APP"
xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
ditto --noextattr --norsrc "$APP" ../ExtLink.app
xattr -cr ../ExtLink.app
python3 ../../Shared/BuildTools/publish_latest.py "$APP"
codesign --verify --deep --strict ../ExtLink.app
codesign --verify --deep --strict "../../Latest Builds/ExtLink.app"
printf 'Built: %s\n' "../ExtLink.app"

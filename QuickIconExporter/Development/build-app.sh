#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h}"
# The App Store variant builds into its own folder so it never replaces the regular app or ZIP.
if [[ "${APP_STORE_BUILD:-0}" == 1 ]]; then
    output_dir="$project_dir/outputs/AppStore/build"
else
    output_dir="$project_dir/outputs"
fi
app_dir="$output_dir/QuickIconExporter.app"
contents_dir="$app_dir/Contents"

cd "$project_dir"
python3 ../../Shared/MenuBarPresence/sync.py
python3 "../../Shared/AppStandards/sync-surface.py"
UPDATER_ROOT="$project_dir/../../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
build_stage=$(mktemp -d /private/tmp/quickicon-build.XXXXXX)
trap 'rm -rf "$build_stage"' EXIT
mkdir -p "$build_stage/module-cache" "$build_stage/swiftpm-cache"
compatible_sdk="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
if [[ ! -d "$compatible_sdk" ]]; then
    compatible_sdk="$(xcrun --sdk macosx --show-sdk-path)"
fi

SDKROOT="$compatible_sdk" \
CLANG_MODULE_CACHE_PATH="$build_stage/module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$build_stage/module-cache" \
swift build "${UPDATE_SPM_FLAGS[@]}" -c release --scratch-path "$build_stage/build" \
    --disable-sandbox \
    --cache-path "$build_stage/swiftpm-cache" \
    -debug-info-format none

rm -rf "$app_dir"
mkdir -p "$output_dir"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
python3 "$project_dir/scripts/make_icns.py" \
    "$project_dir/Resources/Assets.xcassets/AppIcon.appiconset" \
    "$project_dir/Resources/IconDrop.icns"
cp "$build_stage/build/release/QuickIconExporter" "$contents_dir/MacOS/QuickIconExporter"
cp "Resources/Info.plist" "$contents_dir/Info.plist"
cp "Resources/IconDrop.icns" "$contents_dir/Resources/IconDrop.icns"
chmod +x "$contents_dir/MacOS/QuickIconExporter"

cp "$project_dir/../Assets/QuickIconExporter-Mustard.icns" "$contents_dir/Resources/QuickIconExporter-Mustard.icns"
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile QuickIconExporter-Mustard" "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName QuickIconExporter" "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName QuickIconExporter" "$contents_dir/Info.plist"
cp -R "$project_dir/Localizations/"*.lproj "$contents_dir/Resources/"
python3 "$project_dir/Tests/check-localization.py" --app "$app_dir"
embed_updates "$app_dir"
"$UPDATER_ROOT/../AppIcon/apply-app-icon.sh" "$app_dir"
xattr -cr "$app_dir"
# Sign with the team certificate (PL9S9PXX96) instead of ad hoc, as in KakkoReplace, so permission grants survive rebuilds.
# build-app-store.sh re-signs the App Store copy with its own identity afterwards.
signing_identity="${QUICKICONEXPORTER_SIGNING_IDENTITY:-301A41C0A37B6B578B7477229015992E8AA34E44}"
codesign --force --sign "$signing_identity" --timestamp=none "$app_dir"
# Never package an app whose signature does not verify.
codesign --verify --deep --strict "$app_dir"
rm -f "$output_dir/QuickIconExporter.zip"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$output_dir/QuickIconExporter.zip"
if [[ "${APP_STORE_BUILD:-0}" != 1 ]]; then
    python3 "$project_dir/../../Shared/BuildTools/publish_latest.py" "$app_dir"
fi
echo "$app_dir"

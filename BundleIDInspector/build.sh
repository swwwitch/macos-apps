#!/bin/zsh
# BundleIDInspector.app をビルドし、検証後に /Applications と Latest Builds へ配置する
set -euo pipefail

project_dir="${0:A:h}"
output_dir="$project_dir/build"
app_dir="$output_dir/BundleIDInspector.app"
contents_dir="$app_dir/Contents"

cd "$project_dir"
python3 ../Shared/MenuBarPresence/sync.py
python3 ../Shared/AppStandards/sync-surface.py
python3 ../Shared/LoginAtLaunch/sync.py
UPDATER_ROOT="$project_dir/../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
build_stage=$(mktemp -d /private/tmp/bundleidinspector-build.XXXXXX)
trap 'rm -rf "$build_stage"' EXIT
mkdir -p "$build_stage/module-cache" "$build_stage/swiftpm-cache"

CLANG_MODULE_CACHE_PATH="$build_stage/module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$build_stage/module-cache" \
swift build "${UPDATE_SPM_FLAGS[@]}" -c release --scratch-path "$build_stage/build" \
    --disable-sandbox \
    --cache-path "$build_stage/swiftpm-cache" \
    -debug-info-format none

rm -rf "$app_dir"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$build_stage/build/release/BundleIDInspector" "$contents_dir/MacOS/BundleIDInspector"
cp Info.plist "$contents_dir/Info.plist"
cp Assets/BundleIDInspector.icns "$contents_dir/Resources/BundleIDInspector.icns"
cp -R Localizations/*.lproj "$contents_dir/Resources/"
printf 'APPL????' > "$contents_dir/PkgInfo"
python3 Tests/check-localization.py --app "$app_dir"
embed_updates "$app_dir"
"$UPDATER_ROOT/../AppIcon/apply-app-icon.sh" "$app_dir"
xattr -cr "$app_dir"
# Sign with the team certificate (PL9S9PXX96) instead of ad hoc, as in KakkoReplace, so permission grants survive rebuilds.
signing_identity="${BUNDLEIDINSPECTOR_SIGNING_IDENTITY:-301A41C0A37B6B578B7477229015992E8AA34E44}"
codesign --force --sign "$signing_identity" --timestamp=none "$app_dir"
# Never deploy an app whose signature does not verify.
codesign --verify --deep --strict "$app_dir"
if [[ "${NO_DEPLOY:-0}" != 1 ]]; then
    python3 ../Shared/BuildTools/publish_latest.py "$app_dir"
fi
echo "$app_dir"

#!/bin/zsh
# NotMyType.app をビルドし、検証後に /Applications と Latest Builds へ配置する
set -euo pipefail

project_dir="${0:A:h}"
output_dir="$project_dir/build"
app_dir="$output_dir/NotMyType.app"
contents_dir="$app_dir/Contents"

cd "$project_dir"
python3 Tools/sync-shared.py
UPDATER_ROOT="$project_dir/../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
build_stage=$(mktemp -d /private/tmp/notmytype-build.XXXXXX)
trap 'rm -rf "$build_stage"' EXIT
mkdir -p "$build_stage/module-cache" "$build_stage/swiftpm-cache"

# Universal (Apple Silicon + Intel).
CLANG_MODULE_CACHE_PATH="$build_stage/module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$build_stage/module-cache" \
swift build "${UPDATE_SPM_FLAGS[@]}" -c release --arch arm64 --arch x86_64 --scratch-path "$build_stage/build" \
    --disable-sandbox \
    --cache-path "$build_stage/swiftpm-cache" \
    -debug-info-format none

rm -rf "$app_dir"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
# The universal product folder differs between SwiftPM versions; ask SwiftPM for it.
bin_path=$(swift build -c release --arch arm64 --arch x86_64 --scratch-path "$build_stage/build" --show-bin-path)
cp "$bin_path/NotMyType" "$contents_dir/MacOS/NotMyType"
xcrun lipo "$contents_dir/MacOS/NotMyType" -verify_arch arm64
xcrun lipo "$contents_dir/MacOS/NotMyType" -verify_arch x86_64
cp Info.plist "$contents_dir/Info.plist"
cp Assets/NotMyType.icns "$contents_dir/Resources/NotMyType.icns"
cp -R Localizations/*.lproj "$contents_dir/Resources/"
printf 'APPL????' > "$contents_dir/PkgInfo"
python3 Tests/check-localization.py --app "$app_dir"
embed_updates "$app_dir"
"$UPDATER_ROOT/../AppIcon/apply-app-icon.sh" "$app_dir"
xattr -cr "$app_dir"
# Sign with the team certificate (PL9S9PXX96) instead of ad hoc, as in KakkoReplace, so permission grants survive rebuilds.
signing_identity="${NOTMYTYPE_SIGNING_IDENTITY:-301A41C0A37B6B578B7477229015992E8AA34E44}"
codesign --force --sign "$signing_identity" --timestamp=none "$app_dir"
# Never deploy an app whose signature does not verify.
codesign --verify --deep --strict "$app_dir"
if [[ "${NO_DEPLOY:-0}" != 1 ]]; then
    python3 ../Shared/BuildTools/publish_latest.py "$app_dir"
fi
echo "$app_dir"

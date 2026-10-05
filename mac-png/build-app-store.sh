#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h}"
export_dir="$project_dir/outputs/AppStore"
app_path="$export_dir/QuickIconExporter.app"
package_path="$export_dir/QuickIconExporter.pkg"

: "${APP_BUNDLE_ID:?APP_BUNDLE_IDを指定してください}"
: "${APP_SIGNING_IDENTITY:?APP_SIGNING_IDENTITYを指定してください}"
: "${INSTALLER_SIGNING_IDENTITY:?INSTALLER_SIGNING_IDENTITYを指定してください}"

cd "$project_dir"
APP_STORE_BUILD=1 ./build-app.sh

mkdir -p "$export_dir"
ditto "$project_dir/outputs/QuickIconExporter.app" "$app_path"

/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $APP_BUNDLE_ID" "$app_path/Contents/Info.plist"

codesign \
    --force \
    --deep \
    --sign "$APP_SIGNING_IDENTITY" \
    --entitlements "$project_dir/Resources/QuickIconExporter-AppStore.entitlements" \
    "$app_path"

codesign --verify --deep --strict --verbose=2 "$app_path"

productbuild \
    --component "$app_path" /Applications \
    --sign "$INSTALLER_SIGNING_IDENTITY" \
    "$package_path"

pkgutil --check-signature "$package_path"
echo "$package_path"

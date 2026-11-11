#!/bin/zsh
# ./build.sh  build build/MenuDiff.app（個人用。配置・公証はしない）
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/MenuDiff-build.XXXXXX)
trap 'rm -rf "$stage"' EXIT
[[ -f Assets/MenuDiff.icns ]] || Assets/make-icon.sh
app="$stage/MenuDiff.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Info.plist "$app/Contents/Info.plist"
cp Assets/MenuDiff.icns "$app/Contents/Resources/"
cp -R Resources/ja.lproj "$app/Contents/Resources/"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx13.0 -module-cache-path "$stage/cache" \
  -framework AppKit -framework SwiftUI -framework ApplicationServices \
  ../Shared/AppStandards/{AppHeader,AppSurface}.swift \
  Source/{Model,MenuReader,MenuDiff,Views,main}.swift -o "$app/Contents/MacOS/MenuDiff"
"../Shared/AppIcon/apply-app-icon.sh" "$app"
xattr -cr "$app"
# アクセシビリティの許可が再ビルド後も引き継がれるよう、チームの証明書で署名する（MENUDIFF_SIGNING_IDENTITY で上書き可）
SIGNING_IDENTITY="${MENUDIFF_SIGNING_IDENTITY:-301A41C0A37B6B578B7477229015992E8AA34E44}"
codesign --force --sign "$SIGNING_IDENTITY" --timestamp=none "$app"
codesign --verify --deep --strict "$app"
mkdir -p build
if [[ -d build/MenuDiff.app ]]; then
  backup="Backups/build-$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p "$backup"
  mv build/MenuDiff.app "$backup/"
fi
ditto "$app" build/MenuDiff.app
print "Built build/MenuDiff.app"

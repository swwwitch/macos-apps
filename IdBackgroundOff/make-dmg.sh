#!/bin/zsh
# Packages build/IdBackgroundOff.app as Release/IdBackgroundOff-<version>-build<build>-arm64.dmg (same layout as the other sw_app DMGs).
set -euo pipefail
cd "${0:A:h}"
app=build/IdBackgroundOff.app
codesign --verify --deep --strict "$app"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
build=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$app/Contents/Info.plist")
stage=$(mktemp -d /private/tmp/IdBackgroundOff-dmg.XXXXXX)
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/IdBackgroundOff.app"
ln -s /Applications "$stage/Applications"
cat > "$stage/はじめに.txt" <<TXT
IdBackgroundOff $version (build $build)

Appleシリコン搭載Mac／macOS 13以降
アプリを終了してから、Applicationsにコピーしてください。

InDesignのアプリ内（Contents/MacOS）に DisableAsyncExports.txt を配置・削除し、「バックグラウンド書き出し／保存」をオフ／元に戻します。変更時に管理者パスワードが必要です。

日本語・英語・簡体字中国語・韓国語に対応。macOSの優先言語に応じて自動的に切り替わります。
TXT
mkdir -p Release
out="Release/IdBackgroundOff-$version-build$build-arm64.dmg"
[[ -e "$out" ]] && { mkdir -p Backups; mv "$out" "Backups/$(basename "$out" .dmg)-$(date +%Y%m%d-%H%M%S).dmg"; }
hdiutil create -volname "IdBackgroundOff $version" -srcfolder "$stage" -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$out" >/dev/null
hdiutil verify "$out" >/dev/null
printf 'DMG: %s\n' "$out"

#!/bin/zsh
# Packages build/CCAutoUpdateOff.app as Release/CCAutoUpdateOff-<version>-build<build>-universal.dmg (same layout as the other sw_app DMGs).
set -euo pipefail
cd "${0:A:h}"
app=build/CCAutoUpdateOff.app
codesign --verify --deep --strict "$app"
xcrun lipo -verify_arch arm64 "$app/Contents/MacOS/CCAutoUpdateOff"
xcrun lipo -verify_arch x86_64 "$app/Contents/MacOS/CCAutoUpdateOff"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
build=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$app/Contents/Info.plist")
stage=$(mktemp -d /private/tmp/CCAutoUpdateOff-dmg.XXXXXX)
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/CCAutoUpdateOff.app"
ln -s /Applications "$stage/Applications"
cat > "$stage/はじめに.txt" <<TXT
CCAutoUpdateOff $version (build $build)

Intel・Appleシリコン搭載Mac／macOS 13以降
アプリを終了してから、Applicationsにコピーしてください。

Creative Cloudの［環境設定］→［アプリ］の自動更新と「以前のバージョンを削除」を見張り、オンになっていたら通知やメールで知らせます。Creative Cloudの設定は変更しません。

メール送信は「メール」アプリに設定したアカウントから送ります（初回に「メール」の制御の許可を求められます）。

日本語・英語・簡体字中国語・韓国語に対応。macOSの優先言語に応じて自動的に切り替わります。
TXT
mkdir -p Release
out="Release/CCAutoUpdateOff-$version-build$build-universal.dmg"
[[ -e "$out" ]] && { mkdir -p Backups; mv "$out" "Backups/$(basename "$out" .dmg)-$(date +%Y%m%d-%H%M%S).dmg"; }
hdiutil create -volname "CCAutoUpdateOff $version" -srcfolder "$stage" -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$out" >/dev/null
hdiutil verify "$out" >/dev/null
printf 'DMG: %s\n' "$out"

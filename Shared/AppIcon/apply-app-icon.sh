#!/bin/zsh
# アプリのアイコンをIcon Composer形式（Assets.car）に差し替える。
# macOS 26は.icnsだけのアイコンをグレーの枠に入れて表示するため、これで枠を出さない。
# 使い方: apply-app-icon.sh <アプリ.app>
# 署名の前に呼ぶ。Info.plistのCFBundleIconFileが指す.icnsを元にする。
set -euo pipefail

app="${1:?アプリのパスを指定してください}"
script_dir="${0:A:h}"
plist="$app/Contents/Info.plist"
resources="$app/Contents/Resources"

icon_name="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$plist")"
icon_name="${icon_name%.icns}"
source_icns="$resources/$icon_name.icns"
[[ -f "$source_icns" ]] || { echo "apply-app-icon: $source_icns がありません" >&2; exit 1; }

work="$(mktemp -d /private/tmp/apply-app-icon.XXXXXX)"
trap 'rm -rf "$work"' EXIT

# 変換ツールはソースが新しいときだけコンパイルし直す。
tool="/private/tmp/apply-app-icon-tool/make-icon-document"
if [[ ! -x "$tool" || "$script_dir/make-icon-document.swift" -nt "$tool" ]]; then
    mkdir -p "${tool:h}"
    xcrun --sdk macosx swiftc -O "$script_dir/make-icon-document.swift" -o "$tool"
fi

"$tool" "$source_icns" "$work/$icon_name.icon"
mkdir -p "$work/out"
xcrun actool "$work/$icon_name.icon" --compile "$work/out" \
    --app-icon "$icon_name" --platform macosx --target-device mac \
    --minimum-deployment-target 14.0 \
    --output-partial-info-plist "$work/out/partial.plist" \
    --errors --warnings > "$work/actool.log"
[[ -f "$work/out/Assets.car" ]] || { cat "$work/actool.log" >&2; exit 1; }

cp "$work/out/Assets.car" "$resources/Assets.car"
# actoolの.icnsは256pxまでなので、画面ヘッダーが読む元の.icnsはそのまま残す。
/usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleIconName string $icon_name" "$plist"

#!/bin/zsh
# MarkdownKitchen の見出し抽出とローカライズを検査する
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/markdownkitchen-test.XXXXXX)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/main"
cp Tests/HeadingParserCheck.swift "$stage/main/main.swift"
CLANG_MODULE_CACHE_PATH="$stage/cache" xcrun swiftc -Onone Sources/MarkdownKitchen/HeadingParser.swift Sources/MarkdownKitchen/HTMLToMarkdown.swift Sources/MarkdownKitchen/DoorkeeperHTML.swift Sources/MarkdownKitchen/MarkdownHTML.swift Sources/MarkdownKitchen/MarkdownTidy.swift Sources/MarkdownKitchen/MarkdownFormat.swift Sources/MarkdownKitchen/MarkdownSyntax.swift Sources/MarkdownKitchen/TextStats.swift "$stage/main/main.swift" -o "$stage/check"
"$stage/check"
# MenuShortcut ⇄ KeyCombo（共通の記録欄）の往復
mkdir -p "$stage/combo"
awk '/^struct KeyCombo/{p=1} /^\/\/\/ Wording shared/{p=0} p' Sources/MarkdownKitchen/HotkeyRecorder.swift > "$stage/combo/KeyCombo.swift"
{ echo 'import AppKit'; echo 'import SwiftUI'; awk '/^struct MenuShortcut/{p=1} /^\/\/\/ 書式などのキーの割り当て/{p=0} p' Sources/MarkdownKitchen/ShortcutSettings.swift; } > "$stage/combo/MenuShortcut.swift"
sed -i '' '1s/^/import AppKit\
import Carbon\
/' "$stage/combo/KeyCombo.swift"
cp Tests/MenuShortcutComboCheck.swift "$stage/combo/main.swift"
CLANG_MODULE_CACHE_PATH="$stage/cache" xcrun swiftc -Onone "$stage/combo/KeyCombo.swift" "$stage/combo/MenuShortcut.swift" Sources/MarkdownKitchen/MenuShortcutCombo.swift "$stage/combo/main.swift" -o "$stage/combo-check"
"$stage/combo-check"
python3 Tests/check-localization.py

# The bundled offline Markdown-to-text converter.
node Tests/MarkdownTextCheck.js

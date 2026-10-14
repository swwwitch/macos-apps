#!/bin/zsh
# MarkdownKitchen の見出し抽出とローカライズを検査する
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/markdownkitchen-test.XXXXXX)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/main"
cp Tests/HeadingParserCheck.swift "$stage/main/main.swift"
CLANG_MODULE_CACHE_PATH="$stage/cache" xcrun swiftc -Onone Sources/MarkdownKitchen/HeadingParser.swift Sources/MarkdownKitchen/HTMLToMarkdown.swift Sources/MarkdownKitchen/DoorkeeperHTML.swift Sources/MarkdownKitchen/MarkdownHTML.swift Sources/MarkdownKitchen/MarkdownTidy.swift Sources/MarkdownKitchen/MarkdownFormat.swift "$stage/main/main.swift" -o "$stage/check"
"$stage/check"
python3 Tests/check-localization.py

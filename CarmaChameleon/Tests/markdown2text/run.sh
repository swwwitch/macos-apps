#!/bin/zsh
# Compares the Swift port with the original JavaScript for every option set in options.json.
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/md2text.XXXXXX); trap 'rm -rf "$stage"' EXIT
xcrun swiftc -swift-version 5 -module-cache-path "$stage/cache" ../../Source/MarkdownToText.swift main.swift -o "$stage/swift" 2>&1 | grep -v warning || true
failures=0
for md in *.md; do
  python3 -c 'import json,sys; [print(json.dumps(o, ensure_ascii=False)) for o in json.load(open("options.json"))]' | while read -r opts; do
    name=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["name"])' "$opts")
    node reference.mjs reference-markdown2text.html "$md" "$opts" > "$stage/js.txt"
    "$stage/swift" "$md" "$opts" > "$stage/swift.txt"
    if cmp -s "$stage/js.txt" "$stage/swift.txt"; then print "PASS: $md [$name]"; else print "FAIL: $md [$name]"; diff "$stage/js.txt" "$stage/swift.txt" | head -20; touch "$stage/failed"; fi
  done
done
[[ ! -e "$stage/failed" ]]

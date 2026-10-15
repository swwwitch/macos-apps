#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/ListMatch-test.XXXXXX)
trap 'rm -rf "$stage"' EXIT
xcrun swiftc -swift-version 5 -O -module-cache-path "$stage/cache" Source/ListComparison.swift Source/ListEditor.swift Tests/main.swift -o "$stage/tests"
"$stage/tests"

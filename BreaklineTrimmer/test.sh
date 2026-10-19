#!/bin/zsh
# Checks the trimming layout and rendering (Tests/main.swift) and the four-language resources.
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/BreaklineTrimmer-test.XXXXXX)
trap 'rm -rf "$stage"' EXIT
xcrun swiftc -swift-version 5 -O -module-cache-path "$stage/cache" Source/TrimGeometry.swift Tests/main.swift -o "$stage/tests"
"$stage/tests"
python3 Tests/check-localization.py

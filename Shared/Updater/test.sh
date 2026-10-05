#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
python3 -m unittest -v test_configure.py
sdk=$(python3 prepare.py)
stage=$(mktemp -d /private/tmp/updater-tests.XXXXXX)
trap 'rm -rf "$stage"' EXIT
xcrun swiftc -parse-as-library -D DIRECT_UPDATES -F "$sdk" -framework Sparkle \
    -module-cache-path "$stage/modules" -Xlinker -rpath -Xlinker "$sdk" \
    UpdateSupport.swift SmokeTests.swift -o "$stage/smoke"
"$stage/smoke"

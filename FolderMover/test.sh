#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/FolderMover-test.XXXXXX)
trap 'rm -rf "$stage"' EXIT
xcrun swiftc -swift-version 5 -module-cache-path "$stage/cache" Source/MoveEngine.swift Tests/main.swift -o "$stage/tests"
"$stage/tests"

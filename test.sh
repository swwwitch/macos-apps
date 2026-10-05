#!/bin/zsh
set -eu
cd "${0:A:h}"
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/commanddee-tests.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun swiftc -module-cache-path "$TEST_DIR/cache" Sources/Duplicator.swift Sources/Shortcut.swift Tests/main.swift -o "$TEST_DIR/tests"
"$TEST_DIR/tests"

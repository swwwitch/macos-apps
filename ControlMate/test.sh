#!/bin/zsh
set -eu
cd "${0:A:h}"
STAGING=$(mktemp -d "${TMPDIR:-/tmp/}controlmate-tests.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" Sources/Commands.swift Sources/TextRanges.swift Tests/CommandTests/main.swift -o "$STAGING/command-tests"
"$STAGING/command-tests"
python3 make-resources.py >/dev/null
python3 Tests/check_resources.py

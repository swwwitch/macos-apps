#!/bin/zsh
set -eu
cd "${0:A:h}"
STAGING=$(mktemp -d "${TMPDIR:-/tmp/}pastemaestro-tests.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" Sources/Incrementer.swift Tests/Increment/main.swift -o "$STAGING/increment"
"$STAGING/increment"
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" Sources/LineRules.swift Tests/Lines/main.swift -o "$STAGING/lines"
"$STAGING/lines"
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" Sources/MenuTitles.swift Tests/MenuTitlesTests.swift -o "$STAGING/titles"
"$STAGING/titles"
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" Sources/ClipboardGate.swift Tests/Gate/main.swift -o "$STAGING/gate"
"$STAGING/gate"
python3 Tests/check_resources.py

#!/bin/zsh
set -eu
cd "${0:A:h}"
STAGING=$(mktemp -d "${TMPDIR:-/tmp/}superkakko-tests.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" Sources/Transform.swift Tests/main.swift -o "$STAGING/tests"
"$STAGING/tests"
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" Sources/LaunchPolicy.swift Tests/LaunchTests.swift -o "$STAGING/launch-tests"
"$STAGING/launch-tests"
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" Sources/Transform.swift Sources/HotKey.swift Tests/ShortcutTests.swift -o "$STAGING/shortcut-tests"
"$STAGING/shortcut-tests"
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" Sources/PaletteTargetSession.swift Tests/PaletteTargetSessionTests.swift -o "$STAGING/palette-target-tests"
"$STAGING/palette-target-tests"
python3 Tests/check_resources.py

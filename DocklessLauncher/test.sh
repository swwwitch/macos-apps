#!/bin/zsh
set -eu
cd "${0:A:h}"
STAGING=$(mktemp -d "${TMPDIR:-/tmp/}applauncher-tests.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" Sources/LaunchEntry.swift Sources/KeyboardLayout.swift Tests/Rules/main.swift -o "$STAGING/rules-tests"
"$STAGING/rules-tests"
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" Sources/LaunchPolicy.swift Tests/LaunchTests.swift -o "$STAGING/launch-tests"
"$STAGING/launch-tests"
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" Sources/LaunchEntry.swift Sources/HotKey.swift Tests/ShortcutTests.swift -o "$STAGING/shortcut-tests"
"$STAGING/shortcut-tests"
python3 Tests/check_resources.py

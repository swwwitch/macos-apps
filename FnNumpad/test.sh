#!/bin/zsh
set -eu
cd "${0:A:h}"
STAGING=$(mktemp -d "${TMPDIR:-/tmp/}fnnumpad-tests.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" Sources/KeyMap.swift Sources/NumpadTap.swift Tests/KeyMapTests.swift -o "$STAGING/keymap-tests"
"$STAGING/keymap-tests"
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" Sources/LaunchPolicy.swift Tests/LaunchTests.swift -o "$STAGING/launch-tests"
"$STAGING/launch-tests"
python3 Tests/check_resources.py
python3 Tests/check_karabiner.py

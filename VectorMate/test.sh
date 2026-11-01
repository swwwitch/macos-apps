#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/VectorMate-test.XXXXXX)
trap 'rm -rf "$stage"' EXIT
xcrun swiftc -swift-version 5 -module-cache-path "$stage/cache" Source/SignInversion.swift Source/MetricsScript.swift Source/PrefPresets.swift Source/Links.swift Tests/main.swift -o "$stage/tests"
"$stage/tests"
python3 Tests/check_resources.py

xcrun swiftc -swift-version 5 -module-cache-path "$stage/cache" -framework JavaScriptCore Source/Appearance/AppearanceCommands.swift Source/Appearance/AppearanceScripts.swift Source/Appearance/AppearanceLogic.swift Tests/Appearance/main.swift -o "$stage/appearance-tests"
"$stage/appearance-tests"

#!/bin/zsh
set -eu
cd "${0:A:h}"
STAGING=$(mktemp -d "${TMPDIR:-/tmp/}keynotehelper-tests.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" Sources/LaunchPolicy.swift Tests/LaunchTests.swift -o "$STAGING/launch-tests"
"$STAGING/launch-tests"
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" Sources/HotKey.swift Sources/ShortcutCombo.swift Sources/HotkeyRecorder.swift Sources/StartupWindow.swift Sources/SettingsSection.swift \
    Sources/KeynoteCommands.swift Sources/CommandRunner.swift Tests/CommandTests.swift -o "$STAGING/command-tests"
"$STAGING/command-tests"
python3 Tests/check_resources.py
python3 Tests/check_km_macro.py

#!/bin/zsh
set -eu
cd "${0:A:h}"
STAGING=$(mktemp -d "${TMPDIR:-/tmp/}pastematchstyle-tests.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" Sources/MenuTitles.swift Tests/MenuTitlesTests.swift -o "$STAGING/titles-tests"
"$STAGING/titles-tests"
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" Sources/LaunchPolicy.swift Tests/LaunchTests.swift -o "$STAGING/launch-tests"
"$STAGING/launch-tests"
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" Sources/HotKey.swift Tests/ShortcutTests.swift -o "$STAGING/shortcut-tests"
"$STAGING/shortcut-tests"
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" Sources/HotKey.swift Sources/ShortcutCombo.swift Sources/HotkeyRecorder.swift Sources/StartupWindow.swift Sources/SettingsSection.swift Tests/ComboTests.swift -o "$STAGING/combo-tests"
"$STAGING/combo-tests"
python3 Tests/check_resources.py
python3 Tests/check_km_macro.py

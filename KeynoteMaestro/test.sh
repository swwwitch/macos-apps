#!/bin/zsh
set -eu
cd "${0:A:h}"
STAGING=$(mktemp -d "${TMPDIR:-/tmp/}keynotehelper-tests.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" Sources/LaunchPolicy.swift Tests/LaunchTests.swift -o "$STAGING/launch-tests"
"$STAGING/launch-tests"
CORE_SOURCES=(Sources/HotKey.swift Sources/ShortcutCombo.swift Sources/HotkeyRecorder.swift Sources/StartupWindow.swift Sources/SettingsSection.swift
    Sources/AutoMagicMove.swift Sources/KeynoteCommands.swift Sources/ShortcutCatalog.swift Sources/ShortcutProfiles.swift Sources/NativeKeyboardActions.swift Sources/CommandRunner.swift)
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" "${CORE_SOURCES[@]}" Tests/AutoMagicMoveTests.swift Tests/ShortcutProfileTests.swift Tests/NativeActionTests.swift Tests/CommandTests.swift -o "$STAGING/command-tests"
"$STAGING/command-tests"
python3 Tests/check_resources.py
python3 Tests/check_km_macro.py

python3 Tests/check_native_reference.py

# Opt in: create/close only the dedicated unsaved fixture; never edit an existing document.
if [[ "${1:-}" == --integration ]]; then
    xcrun swiftc -module-cache-path "$STAGING/ModuleCache" "${CORE_SOURCES[@]}" Tests/AutoMagicMoveIntegration.swift -o "$STAGING/integration-tests"
    "$STAGING/integration-tests"
    xcrun swiftc -module-cache-path "$STAGING/ModuleCache" "${CORE_SOURCES[@]}" Tests/GroupedBackgroundIntegration.swift -o "$STAGING/background-integration-tests"
    "$STAGING/background-integration-tests"
    xcrun swiftc -module-cache-path "$STAGING/ModuleCache" "${CORE_SOURCES[@]}" Tests/PaletteShapeIntegration.swift -o "$STAGING/palette-shape-integration-tests"
    "$STAGING/palette-shape-integration-tests"
fi

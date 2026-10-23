#!/bin/zsh
set -eu
cd "${0:A:h}/../../.."
stage=$(mktemp -d /private/tmp/accessibility-standard-tests.XXXXXX)
trap 'rm -rf "$stage"' EXIT
xcrun swiftc -swift-version 5 -parse-as-library Shared/Accessibility/AccessibilityPermission.swift Shared/AppStandards/StartupWindow.swift Shared/AppStandards/SettingsSection.swift Shared/AppStandards/HelpDocument.swift Shared/MenuBarPresence/MenuBarPresence.swift Shared/LoginAtLaunch/LoginAtLaunch.swift Shared/Accessibility/Tests/OpeningTests.swift -module-cache-path "$stage/cache" -o "$stage/tests"
"$stage/tests"
python3 Shared/Accessibility/Tests/check_integration.py

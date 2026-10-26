#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/ShotSorter-engine.XXXXXX)
trap 'rm -rf "$stage"' EXIT
python3 - "$stage/main.swift" <<'PY'
import sys
from pathlib import Path
source = Path('Source/main.swift').read_text().split('/// Grows its window')[0]
Path(sys.argv[1]).write_text(source + '\n' + Path('Tests/engine.swift').read_text())
PY
xcrun swiftc -swift-version 5 -module-cache-path "$stage/cache" \
  -framework AppKit -framework SwiftUI -framework ServiceManagement -framework Carbon -framework ApplicationServices -framework Vision -framework UserNotifications \
  ../Shared/AppStandards/{SettingsSection,LaunchPresenceSection,AppHeader,AppSurface,StartupWindow,HelpDocument,AboutSection}.swift ../Shared/MenuBarPresence/MenuBarPresence.swift ../Shared/HotkeyRecorder/HotkeyRecorder.swift \
  ../Shared/LoginAtLaunch/LoginAtLaunch.swift ../Shared/Accessibility/AccessibilityPermission.swift ../Shared/Notifications/NotificationPreferences.swift ../Shared/Updater/UpdateSupport.swift ../Shared/SettingsSync/SettingsSync.swift \
  Source/{Naming,Services,Panels,Views}.swift "$stage/main.swift" -o "$stage/ShotSorterEngineTests"
"$stage/ShotSorterEngineTests"

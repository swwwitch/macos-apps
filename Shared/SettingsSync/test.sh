#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/settings-sync-test.XXXXXX)
trap 'rm -rf "$stage"' EXIT
python3 - "$stage/Journal.swift" <<'PY'
from pathlib import Path
import sys
source=Path('SettingsSync.swift').read_text()
Path(sys.argv[1]).write_text('import Foundation\n'+source[source.index('enum SettingsSyncJournal {'):source.index('/// Shared settings export/import and sync.')])
PY
xcrun swiftc -swift-version 5 -module-cache-path "$stage/cache" "$stage/Journal.swift" Tests/main.swift -o "$stage/tests"
"$stage/tests"
python3 - "$stage/SettingsSync.swift" <<'PY'
from pathlib import Path
import sys
s=Path('SettingsSync.swift').read_text()
s=s.replace('private let defaults = UserDefaults.standard', 'var defaults = UserDefaults(suiteName: defaultsSuiteName)!')
s=s.replace('private var synchronizing = false','var synchronizing = false')
Path(sys.argv[1]).write_text('let defaultsSuiteName = "SettingsSyncTests-" + UUID().uuidString\n'+s)
PY
xcrun swiftc -swift-version 5 -module-cache-path "$stage/cache" \
    ../AppStandards/StartupWindow.swift ../AppStandards/SettingsSection.swift \
    "$stage/SettingsSync.swift" Tests/Integration.swift -o "$stage/integration"
"$stage/integration"

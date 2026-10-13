#!/bin/zsh
set -eu
cd "${0:A:h}"
STAGING=$(mktemp -d "${TMPDIR:-/tmp/}projectfolder-tests.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
CORE=(Sources/FolderName.swift Sources/Project.swift Sources/FileTemplates.swift Sources/Library.swift Sources/Creation.swift)
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" "${CORE[@]}" Tests/NameTests.swift -o "$STAGING/name-tests"
"$STAGING/name-tests"
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" "${CORE[@]}" Tests/BulkTests.swift -o "$STAGING/bulk-tests"
"$STAGING/bulk-tests"
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" "${CORE[@]}" Tests/ProjectTests.swift -o "$STAGING/project-tests"
"$STAGING/project-tests"
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" "${CORE[@]}" Tests/TemplateTests.swift -o "$STAGING/template-tests"
"$STAGING/template-tests"
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" "${CORE[@]}" Tests/CreationTests.swift -o "$STAGING/creation-tests"
"$STAGING/creation-tests"
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" Sources/FileViewers.swift Tests/LinkTests.swift -o "$STAGING/link-tests"
"$STAGING/link-tests"
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" Sources/LaunchPolicy.swift Tests/LaunchTests.swift -o "$STAGING/launch-tests"
"$STAGING/launch-tests"
xcrun swiftc -module-cache-path "$STAGING/ModuleCache" Sources/HotKey.swift Tests/ShortcutTests.swift -o "$STAGING/shortcut-tests"
"$STAGING/shortcut-tests"
python3 Tests/check_resources.py
python3 Tests/check_km_macro.py

#!/bin/zsh
set -euo pipefail
root="${0:A:h:h}"
stage=$(mktemp -d /private/tmp/startup-window-tests.XXXXXX)
trap 'rm -rf "$stage"' EXIT
xcrun swiftc -module-cache-path "$stage/cache" "$root/StartupWindow.swift" "$root/Tests/StartupWindowTests.swift" -o "$stage/policy"
"$stage/policy"
xcrun swiftc -module-cache-path "$stage/cache" "$root/StartupWindow.swift" "$root/Tests/StartupWindowGateTests.swift" -o "$stage/gate"
"$stage/gate"
"$stage/gate" --reopen

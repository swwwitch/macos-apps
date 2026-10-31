#!/bin/zsh
set -eu
cd "${0:A:h}/.."
mkdir -p build/tests build/ModuleCache
python3 make-resources.py
python3 Tests/check_resources.py
xcrun swiftc -module-cache-path build/ModuleCache Sources/Commands.swift Sources/TextRanges.swift Tests/CommandTests/main.swift -o build/tests/commands
build/tests/commands
xcrun swiftc -module-cache-path build/ModuleCache Sources/KeyMap.swift Sources/NumpadTap.swift Tests/KeyMapTests.swift -o build/tests/keymap
build/tests/keymap
xcrun swiftc -module-cache-path build/ModuleCache Sources/Commands.swift Sources/KeyMap.swift Sources/NumpadTap.swift Sources/KeyTap.swift Sources/OCRText.swift Tests/RoutingTests/main.swift -o build/tests/routing
build/tests/routing
xcrun swiftc -module-cache-path build/ModuleCache Sources/OCRServices.swift Tests/OCRTests/main.swift -framework Vision -o build/tests/ocr
build/tests/ocr

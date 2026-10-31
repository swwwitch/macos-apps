#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/FileSorter-engine.XXXXXX)
trap 'rm -rf "$stage"' EXIT
python3 - "$stage" <<'PYTEST'
from pathlib import Path
import sys
source = Path('Source/main.swift').read_text()
engine = source[source.index('@MainActor final class Engine'):source.index('/// Grows its window')]
Path(sys.argv[1], 'main.swift').write_text(Path('Tests/Engine/main.swift').read_text().replace('// ENGINE_SOURCE', engine))
PYTEST
xcrun swiftc -swift-version 5 -module-cache-path "$stage/cache" Source/{Rules,Naming,ImageReader,FolderWatcher}.swift "$stage/main.swift" -o "$stage/tests"
"$stage/tests"

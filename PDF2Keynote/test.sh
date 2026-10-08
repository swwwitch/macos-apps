#!/bin/zsh
# ./test.sh            unit tests + localization checks
# ./test.sh --keynote  also converts a fixture through the real Keynote (Automation permission required)
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/PDF2Keynote-test.XXXXXX)
trap 'rm -rf "$stage"' EXIT
xcrun swiftc -swift-version 5 -module-cache-path "$stage/cache" -framework AppKit -framework PDFKit -framework Carbon \
  -framework SwiftUI ../Shared/KeynoteExport/KeynoteExport.swift ../Shared/KeynoteExport/PDFBackground.swift Source/ConversionRunner.swift Tests/main.swift -o "$stage/tests"
if [[ "${1:-}" == "--keynote" ]]; then
  osacompile -o "$stage/Keynote.scpt" ../Shared/KeynoteExport/Keynote.applescript
  "$stage/tests" "$stage/work" "$stage/Keynote.scpt" "$PWD/Tests/KeynoteOutput"
else
  "$stage/tests" "$stage/work"
fi
python3 make-resources.py >/dev/null
python3 - <<'PY'
import re, pathlib
root = pathlib.Path('.')
keys = set()
for p in list((root / 'Source').glob('*.swift')) + [root / '../Shared/KeynoteExport/KeynoteExport.swift']:
    text = p.read_text()
    keys.update(re.findall(r'L\("([^"\\]+)"\)', text))
    keys.update('box.' + c for c in ['crop', 'trim', 'bleed', 'media', 'art'])
sets = []
for p in (root / 'Resources').glob('*.lproj/Localizable.strings'):
    present = set(re.findall(r'^"([^"]+)"\s*=', p.read_text(), re.M)); sets.append(present)
    assert keys <= present, (p, keys - present)
assert len(sets) == 4 and all(s == sets[0] for s in sets)
for p in (root / 'Resources').glob('*.lproj'):
    assert (p / 'Help.txt').stat().st_size > 1000 and 'NSAppleEventsUsageDescription' in (p / 'InfoPlist.strings').read_text(), p
print('PASS: localization key parity (4 languages), help and permission text present')
PY

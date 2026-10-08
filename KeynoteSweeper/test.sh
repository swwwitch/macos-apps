#!/bin/zsh
# ./test.sh            unit tests + localization checks
# ./test.sh --keynote  also cleans a scratch presentation in the real Keynote
#                      (Automation and Accessibility permission for the terminal required)
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/KeynoteSweeper-test.XXXXXX)
trap 'rm -rf "$stage"' EXIT
xcrun swiftc -swift-version 5 -module-cache-path "$stage/cache" -framework AppKit Source/Sweeper.swift Tests/main.swift -o "$stage/tests"
"$stage/tests" "$@"
python3 make-resources.py >/dev/null
python3 - <<'PY'
import re, pathlib
root = pathlib.Path('.')
keys = set()
for p in (root / 'Source').glob('*.swift'):
    keys.update(re.findall(r'L\("([^"\\]+)"\)', p.read_text()))
sets = []
for p in (root / 'Resources').glob('*.lproj/Localizable.strings'):
    text = p.read_text()
    present = dict(re.findall(r'^"([^"]+)"\s*=\s*"(.*)";$', text, re.M)); sets.append(present)
    assert keys <= set(present), (p, keys - set(present))
for s in sets:
    for k, v in s.items():
        assert sorted(re.findall(r'%[@d]', v)) == sorted(re.findall(r'%[@d]', sets[0][k])), ('placeholder mismatch', k)
assert len(sets) == 4 and all(set(s) == set(sets[0]) for s in sets)
for p in (root / 'Resources').glob('*.lproj'):
    assert (p / 'Help.txt').stat().st_size > 1000 and 'NSAppleEventsUsageDescription' in (p / 'InfoPlist.strings').read_text(), p
print('PASS: localization key and placeholder parity (4 languages), help and permission text present')
PY

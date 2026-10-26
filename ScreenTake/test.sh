#!/bin/zsh
# ./test.sh   timeline unit tests + export of a generated movie + localization checks
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/ScreenTake-test.XXXXXX)
trap 'rm -rf "$stage"' EXIT
xcrun swiftc -swift-version 5 -target arm64-apple-macosx15.0 -module-cache-path "$stage/cache" \
  Source/{Project,Recorder,Compositor,Exporter}.swift Tests/main.swift -o "$stage/tests"
"$stage/tests"
python3 make-resources.py >/dev/null
python3 - <<'PY'
import re, pathlib
root = pathlib.Path('.')
keys = set()
for p in (root / 'Source').glob('*.swift'):
    text = p.read_text()
    keys.update(re.findall(r'L\("([^"\\]+)"\)', text))
    # Keys chosen with a ternary inside L(...).
    for a, b in re.findall(r'L\([^()]*\? "(\w+)" : "(\w+)"\)', text): keys.update([a, b])
keys.update('corner.' + c for c in ['topLeft', 'topRight', 'bottomLeft', 'bottomRight'])
keys.update('shape.' + c for c in ['circle', 'rounded'])
sets = []
for p in (root / 'Resources').glob('*.lproj/Localizable.strings'):
    present = dict(re.findall(r'^"([^"]+)"\s*=\s*"(.*)";$', p.read_text(), re.M)); sets.append(present)
    assert keys <= set(present), (p, keys - set(present))
for s in sets:
    for k, v in s.items():
        assert sorted(re.findall(r'%(?:\.\d)?[@df]', v)) == sorted(re.findall(r'%(?:\.\d)?[@df]', sets[0][k])), ('placeholder mismatch', k)
assert len(sets) == 4 and all(set(s) == set(sets[0]) for s in sets)
for p in (root / 'Resources').glob('*.lproj'):
    assert (p / 'Help.txt').stat().st_size > 1000, p
print('PASS: localization key and placeholder parity (4 languages), help present')
PY

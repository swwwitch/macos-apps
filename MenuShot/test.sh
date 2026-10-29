#!/bin/zsh
# ./test.sh   layout unit tests + localization checks
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/MenuShot-test.XXXXXX)
trap 'rm -rf "$stage"' EXIT
xcrun swiftc -swift-version 5 -module-cache-path "$stage/cache" Source/Layout.swift Tests/main.swift -o "$stage/tests"
xcrun swiftc -swift-version 5 -module-cache-path "$stage/cache" Source/MenuPath.swift Tests/MenuPath/main.swift -o "$stage/path-tests"
"$stage/path-tests"
xcrun swiftc -swift-version 5 -module-cache-path "$stage/cache" -framework AppKit -framework ScreenCaptureKit Source/Layout.swift Source/Capture.swift Tests/Rendering/main.swift -o "$stage/render-tests"
"$stage/render-tests"
"$stage/tests"
python3 make-resources.py >/dev/null
python3 - <<'PY'
import re, pathlib
root = pathlib.Path('.')
keys = set()
for p in (root / 'Source').glob('*.swift'):
    keys.update(re.findall(r'L\("([^"\\]+)"\)', p.read_text()))
# Range titles are looked up as "range." + rawValue.
cases = re.findall(r'^\s*case (\w+)$', (root / 'Source/Layout.swift').read_text(), re.M)
keys.update('range.' + c for c in cases)
keys.update(['saved', 'savedAndCopied', 'permitted', 'notPermitted'])  # chosen with a ternary inside L(...)
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
    assert (p / 'Help.txt').stat().st_size > 1000, p
print('PASS: localization key and placeholder parity (4 languages), help present')
PY

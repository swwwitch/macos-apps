#!/bin/zsh
# ./test.sh   unit tests + localization checks
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/FavoritesTidy-test.XXXXXX)
trap 'rm -rf "$stage"' EXIT
xcrun swiftc -swift-version 5 -module-cache-path "$stage/cache" -framework AppKit -framework Carbon Source/Favorites.swift Source/DFX.swift Tests/main.swift -o "$stage/tests"
"$stage/tests"
python3 make-resources.py >/dev/null
python3 - <<'PY'
import re, pathlib
root = pathlib.Path('.')
keys = set()
for p in (root / 'Source').glob('*.swift'):
    keys.update(k for k in re.findall(r'L\("([^"\\]+)"\)', p.read_text()) if '\\(' not in k)
# Sort names are looked up as "sort." + rawValue.
keys.update('sort.' + c for c in re.search(r'case (name[^\n]+)', (root / 'Source/Favorites.swift').read_text()).group(1).replace(' ', '').split(','))
keys.update(['undo', 'redo', 'cut', 'copy', 'paste', 'delete', 'selectAll'])
sets = []
for p in (root / 'Resources').glob('*.lproj/Localizable.strings'):
    text = p.read_text()
    present = dict(re.findall(r'^"([^"]+)"\s*=\s*"(.*)";$', text, re.M)); sets.append(present)
    assert keys <= set(present), (p, keys - set(present))
for s in sets:
    for k, v in s.items():
        assert sorted(re.findall(r'%(?:\d\$)?[@d]', v)) == sorted(re.findall(r'%(?:\d\$)?[@d]', sets[0][k])), ('placeholder mismatch', k)
assert len(sets) == 4 and all(set(s) == set(sets[0]) for s in sets)
for p in (root / 'Resources').glob('*.lproj'):
    assert (p / 'Help.txt').stat().st_size > 1000, p
print('PASS: localization key and placeholder parity (4 languages), help present')
PY

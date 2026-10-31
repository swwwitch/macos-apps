#!/bin/zsh
# ./test.sh   unit tests + localization checks
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/VectorFX-test.XXXXXX)
trap 'rm -rf "$stage"' EXIT
xcrun swiftc -swift-version 5 -module-cache-path "$stage/cache" Source/Commands.swift Source/ScriptBuilder.swift Source/Runner.swift Tests/main.swift -o "$stage/tests"
"$stage/tests"
python3 make-resources.py >/dev/null
python3 - <<'PY'
import re, pathlib
root = pathlib.Path('.')
keys = set()
for p in (root / 'Source').glob('*.swift'):
    keys.update(re.findall(r'L\("([^"\\]+)"\)', p.read_text()))
src = (root / 'Source/Commands.swift').read_text()
# Titles looked up by prefix: commands, sections, parameters, built-in code descriptions, failures.
ids = re.findall(r'Command\(id: "([^"]+)"', src)
keys.update('cmd.' + i for i in ids)
keys.update('section.' + s.strip() for s in re.search(r'case (stylize[^\n]+)', src).group(1).split(','))
keys.update('param.' + k for k in re.findall(r'key: "([^"]+)"', src) + re.findall(r'length\("([^"]+)"', src))
keys.update('kind.code.' + i for i in re.findall(r'Command\(id: "([^"]+)"[^\n]*action: \.code\(', src))
keys.update('status.err.' + f.strip() for f in re.search(r'enum Failure: String \{ case ([^}]+)\}', (root / 'Source/ScriptBuilder.swift').read_text()).group(1).split(','))
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

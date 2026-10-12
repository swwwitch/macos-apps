# Default hotkeys must match the triggers of the Keyboard Maestro macros they replace.
from pathlib import Path
import plistlib, re
root = Path(__file__).resolve().parents[1]
groups = plistlib.load(open(root / 'Reference/Make Link Macros-20261013.kmmacros', 'rb')) + plistlib.load(open(root / 'Reference/Make Link (misc) Macros-20261013.kmmacros', 'rb'))
triggers = {}
doubles = set()
for group in groups:
    for macro in group['Macros']:
        for t in macro.get('Triggers', []):
            if t.get('MacroTriggerType') == 'HotKey':
                triggers.setdefault((t['KeyCode'], t['Modifiers']), []).append(macro['Name'])
                if t.get('TapCount') == 2: doubles.add((t['KeyCode'], t['Modifiers']))
source = (root / 'Sources/LinkAction.swift').read_text()
consts = {k: int(v) for k, v in re.findall(r'(opt|optShiftCmd|optCmd|ctrlOptCmd|ctrlCmd): UInt32 = (\d+)', 'opt: UInt32 = 2048, ' + source.split('static let opt: UInt32 = 2048, ')[1].split('\n')[0])}
defaults = re.findall(r'case \.(\w+): return \.km\((\d+), Self\.(\w+), "(\w)"\)', source)
missing = []
for action, code, mod, key in defaults:
    names = triggers.get((int(code), consts[mod]))
    if not names: missing.append(action)
    else: print(f'{action:22} {key} {consts[mod]:5} ← {names[0]}')
assert not missing, missing
# Double-tap defaults must be double taps in Keyboard Maestro too.
double_actions = re.findall(r'var defaultDoubleTap: Bool \{ self == \.(\w+) \}', source)
for action, code, mod, key in defaults:
    if action in double_actions:
        assert (int(code), consts[mod]) in doubles, action
        print(f'{action:22} double tap ← KM TapCount 2')
print(f'PASS: {len(defaults)} default hotkeys match Keyboard Maestro triggers')

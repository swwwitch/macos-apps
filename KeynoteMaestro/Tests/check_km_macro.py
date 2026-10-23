"""Every active KM macro trigger of Keynote Macros.kmmacros is a default key of KeynoteMaestro (or listed as dropped)."""
from pathlib import Path
import plistlib, re
root = Path(__file__).resolve().parents[1]
macro_file = root / 'Keynote Macros.kmmacros'
if not macro_file.exists():
    print('SKIP: KM macros not found at', macro_file); raise SystemExit(0)
source = (root / 'Sources/KeynoteCommands.swift').read_text()
names = {'cmd': 256, 'shift': 512, 'opt': 2048, 'ctrl': 4096}
defaults = set()
for code, mods in re.findall(r'Shortcut\((\d+), km: ([a-z |]+)\)', source):
    defaults.add((int(code), sum(names[m.strip()] for m in mods.split('|'))))
for code in [18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 50]: defaults.add((code, 512))  # opacity ⇧1 … ⇧0, ⇧` (100%, second key)
# KeynoteSweeper's services ⌃⌥⌘1 … ⌃⌥⌘5 are not KM macros; no active KM trigger may use them.
assert not {(c, 6400) for c in (18, 19, 20, 21, 23)} & {(t.get('KeyCode'), t.get('Modifiers')) for g in plistlib.loads(macro_file.read_bytes()) for m in g.get('Macros', []) if m.get('IsActive', True) for t in m.get('Triggers', [])}
# Second triggers of one command, and bare Home/End: one key per command in the app (see README).
# 29:6400 is 「37)【トランジション】なし（すべてのスライド）」, left to KeynoteSweeper (1.0.1).
dropped = {(29, 6400), (34, 6400), (48, 6144), (40, 6400), (48, 4096), (115, 0), (119, 0), (2, 4096), (35, 4352), (36, 2304), (7, 4352), (126, 4352), (46, 4352),
           (125, 4352), (123, 4352), (8, 4352), (124, 4352), (32, 2560), (46, 256), (46, 2816), (38, 6400), (37, 6400), (44, 2304)}
missing = []
for group in plistlib.loads(macro_file.read_bytes()):
    for macro in group.get('Macros', []):
        if not macro.get('IsActive', True): continue
        for trigger in macro.get('Triggers', []):
            key = (trigger.get('KeyCode'), trigger.get('Modifiers'))
            if key not in defaults and key not in dropped: missing.append((macro['Name'], key))
assert not missing, missing
print(f'PASS: every active KM trigger is a default key ({len(defaults)} keys) or a documented second trigger')

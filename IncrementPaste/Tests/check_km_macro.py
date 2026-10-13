"""Compares the defaults with the Keyboard Maestro macro 「increment-paste」: trigger ⌥V and the excluded apps."""
from pathlib import Path
import plistlib, re
root = Path(__file__).resolve().parents[1]
macro_file = root / 'increment-paste.kmmacros'
if not macro_file.exists():
    print('SKIP: KM macro not found at', macro_file)
    raise SystemExit(0)
group = plistlib.loads(macro_file.read_bytes())[0]
trigger = group['Macros'][0]['Triggers'][0]
assert (trigger['KeyCode'], trigger['Modifiers']) == (9, 2048), trigger  # ⌥V
assert 'Shortcut(code: 9, modifiers: UInt32(optionKey)' in (root / 'Sources/HotKey.swift').read_text()
km_apps = sorted({t['BundleIdentifier'] for t in group['Targeting']['TargetingApps']})
lists = (root / 'Sources/ExcludedAppList.swift').read_text()
initial = sorted(re.findall(r'"([\w.-]+)"', re.search(r'static let initial = \[(.*?)\]', lists).group(1)))
assert initial == km_apps, (initial, km_apps)
print('PASS: ⌥V and excluded defaults match the KM macro')

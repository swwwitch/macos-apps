"""Compares LineRules.swift and the defaults with the Keyboard Maestro macro 「01)連続ペースト」, code point by code point."""
from pathlib import Path
import plistlib, re
root = Path(__file__).resolve().parents[1]
macro_file = root / '01)連続ペースト.kmmacros'
if not macro_file.exists():
    print('SKIP: KM macro not found at', macro_file)
    raise SystemExit(0)
group = plistlib.loads(macro_file.read_bytes())[0]
macro = group['Macros'][0]
trigger = macro['Triggers'][0]
assert (trigger['KeyCode'], trigger['Modifiers']) == (9, 6144), trigger  # ⌃⌥V
shaping = next(a for a in macro['Actions'] if a.get('ActionName') == '整形')
active = [a['Search'] for a in shaping['Actions'] if a['MacroActionType'] == 'SearchReplace' and a.get('IsActive', True)]
# The last two only remove blank lines, which LineRules always skips.
assert active[-2:] == ['\\n\\s+\\n', '\\n\\n'], active[-2:]
source = (root / 'Sources/LineRules.swift').read_text()
swift = re.findall(r'#"(.*?)"#', source)
assert swift == active[:-2], (swift, active[:-2])
km_apps = sorted({t['BundleIdentifier'] for t in group['Targeting']['TargetingApps']})
lists = (root / 'Sources/ExcludedAppList.swift').read_text()
initial = sorted(re.findall(r'"([\w.-]+)"', re.search(r'static let initial = \[(.*?)\]', lists).group(1)))
assert initial == km_apps, (initial, km_apps)
assert macro['Actions'][2]['Variable'] == 'local__notification' and macro['Actions'][2]['Text'] == '0'
print(f'PASS: {len(swift)} cleanup patterns match the macro in order; excluded defaults = KM excluded apps; ⌃⌥V; notification off')

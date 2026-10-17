"""Compares the defaults with the Keyboard Maestro macros 「Universal Paste Without Style」 and 「Paste and Match Style」."""
from pathlib import Path
import plistlib, re
root = Path(__file__).resolve().parents[1]
universal = root / 'Universal Paste Without Style.kmmacros'
matching = root / 'Paste and Match Style.kmmacros'
if not universal.exists() or not matching.exists():
    print('SKIP: KM macros not found'); raise SystemExit(0)
group = plistlib.loads(universal.read_bytes())[0]
macro = group['Macros'][0]
assert (macro['Triggers'][0]['KeyCode'], macro['Triggers'][0]['Modifiers']) == (9, 768)  # ⇧⌘V
km_titles = macro['Actions'][0]['Menu'][1].split('\n')
source = (root / 'Sources/MenuTitles.swift').read_text()
initial = re.findall(r'"([^"\n]+)"', re.search(r'static let initial = \[(.*?)\]', source, re.S).group(1))
assert initial[:len(km_titles)] == km_titles, (initial, km_titles)
# Every app-specific title of 「Paste and Match Style」 is covered.
def menus(node):
    if isinstance(node, dict):
        if node.get('MacroActionType') == 'SelectMenuItem': yield node['Menu'][-1]
        for v in node.values(): yield from menus(v)
    elif isinstance(node, list):
        for v in node: yield from menus(v)
specific = set(menus(plistlib.loads(matching.read_bytes())))
assert specific <= set(initial), specific - set(initial)
km_apps = sorted({t['BundleIdentifier'] for t in group['Targeting']['TargetingApps']})
lists = (root / 'Sources/main.swift').read_text()
excluded = sorted(re.findall(r'"([\w.-]+)"', re.search(r'static let initial = \[(.*?)\]', lists).group(1)))
assert excluded == km_apps, (excluded, km_apps)
print(f'PASS: {len(km_titles)} macro titles in order + {len(specific)} app-specific titles covered; excluded defaults = KM; ⇧⌘V')

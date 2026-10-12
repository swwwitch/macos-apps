from pathlib import Path
import re, subprocess, json
root=Path(__file__).resolve().parents[1]
resources=[]
for language in ('ja','en','zh-Hans','ko'):
    path=root/'Resources'/f'{language}.lproj'/'Localizable.strings'
    data=json.loads(subprocess.check_output(['plutil','-convert','json','-o','-',str(path)]))
    assert all(data.values()), language
    # Format placeholders must match the Japanese source.
    if language == 'ja': base = data
    for key, value in data.items():
        assert value.count('%@') == base[key].count('%@'), (language, key)
    resources.append(set(data))
assert all(keys == resources[0] for keys in resources)
used=set()
for path in (root/"Sources").glob("*.swift"):
    text = path.read_text()
    used.update(re.findall(r'L\("([^"\n]+)"\)',text))
    # Keys chosen with a ternary inside L(...).
    for inner in re.findall(r'\bL\(([^()\n]*\? *"[^()\n]*)\)', text):
        used.update(re.findall(r'"([^"\n]+)"', inner))
# Keys built at run time: L(action.titleKey), L("group." + …), the edit menu's L(key).
cases = re.findall(r'case ([\w, ]+)$', (root/'Sources/LinkAction.swift').read_text().split('enum Group')[0], re.M)
used.update('action.' + c.strip() for line in cases for c in line.split(','))
used.update('group.' + g for g in re.search(r'enum Group: String, CaseIterable \{ case ([^}]+)\}', (root/'Sources/LinkAction.swift').read_text()).group(1).replace(' ', '').split(','))
used.update(['undo', 'redo', 'cut', 'copy', 'paste', 'selectAll'])
assert not used-resources[0], used-resources[0]
assert not resources[0]-used, ('unused', resources[0]-used)
print(f'PASS: {len(resources[0])} localization keys in 4 languages; placeholders match; all literal calls covered ({len(used)} used)')
# The localized display name must be the app's current name (a rename once left the old one here).
name = subprocess.check_output(['/usr/libexec/PlistBuddy', '-c', 'Print :CFBundleName', str(root/'Info.plist')], text=True).strip()
for language in ('ja','en','zh-Hans','ko'):
    info = json.loads(subprocess.check_output(['plutil','-convert','json','-o','-',str(root/'Resources'/f'{language}.lproj'/'InfoPlist.strings')]))
    assert info.get('CFBundleDisplayName') == name, (language, info.get('CFBundleDisplayName'))
print(f'PASS: display name "{name}" in 4 languages')

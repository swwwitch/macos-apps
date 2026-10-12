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
for path in (root/'Sources').glob('*.swift'):
    text = path.read_text()
    used.update(re.findall(r'L\("([^"\n]+)"\)',text))
    # Keys chosen with a ternary inside L(...).
    for inner in re.findall(r'\bL\(([^()\n]*\? *"[^()\n]*)\)', text):
        used.update(re.findall(r'"([^"\n]+)"', inner))
assert not used-resources[0], used-resources[0]
print(f'PASS: {len(resources[0])} localization keys in 4 languages; placeholders match; all literal calls covered ({len(used)} used)')
# %@ needs an object: a bare Int (count) passed to String(format:) crashes (1.0–1.4.1 Settings > Hotkeys).
for path in (root/'Sources').glob('*.swift'):
    for line in path.read_text().splitlines():
        if 'String(format:' in line:
            assert not re.search(r'String\(format:[^\n]*,\s*(?!String\()[\w.]*(?:count|Count|added)\b', line), (path.name, line.strip())
print('PASS: no bare counts passed to %@ formats')


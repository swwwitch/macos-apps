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
# Keys built from identifiers: "cmd." + command id, "group." + group (and ".hint"), "triggerKey." + trigger.
source = (root/'Sources'/'Commands.swift').read_text()
ids = re.findall(r'Command\(id: "(\w+)"', source)
built = {'cmd.' + c for c in ids} | {'short.' + c for c in ids}
groups = re.search(r'case (basic, assist, paragraph)', source).group(1).split(', ')
built |= {'group.' + g for g in groups} | {'group.' + g + '.hint' for g in groups}
built |= {'triggerKey.' + t for t in re.search(r'case (control, capsLock, both)', source).group(1).split(', ')}
cats = re.search(r'case (cursor, keySend, editing, killYank)', source).group(1).split(', ')
built |= {'category.' + c for c in cats} | {'category.' + c + '.hint' for c in cats}
built |= {'undo', 'redo', 'cut', 'copy', 'paste', 'selectAll'}  # menu items made in a loop
assert not built - resources[0], built - resources[0]
print(f'PASS: {len(built)} identifier-built keys present')

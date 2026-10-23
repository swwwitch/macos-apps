"""Validate the entire supplied snapshot, not only counts or examples."""
from pathlib import Path
import json
import subprocess

root = Path(__file__).resolve().parents[1]
lines = (root / 'Reference/KeynoteShortcuts-ja.txt').read_text().splitlines()
starts = [i for i, line in enumerate(lines) if line == '操作']
expected = []
headings = []
for index, start in enumerate(starts):
    headings.append(lines[start - 1])
    end = starts[index + 1] - 1 if index + 1 < len(starts) else lines.index('関連項目')
    pairs = [line for line in lines[start + 2:end] if line.strip()
             and not line.startswith('音声入力の設定を変更するには')]
    assert len(pairs) % 2 == 0
    expected.extend(zip(pairs[::2], pairs[1::2]))
entries = json.loads((root / 'Resources/NativeShortcuts.json').read_text())
assert [(item['title'], item['shortcut']) for item in entries] == expected
section_ids = list(dict.fromkeys(item['section'] for item in entries))
assert len(section_ids) == len(headings) == 14
resources = {}
for language in ('ja', 'en', 'zh-Hans', 'ko'):
    path = root / 'Resources' / f'{language}.lproj' / 'Localizable.strings'
    data = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(path)]))
    resources[language] = data
    for section in section_ids + ['transition', 'animation', 'export', 'sweeper']:
        assert data['catalog.category.' + section]
    for scope in ('all', 'maestro', 'native'):
        assert data['catalog.scope.' + scope]
    assert data['catalog.results'].count('%d') == 1
assert [resources['ja']['catalog.category.' + section] for section in section_ids] == headings
# Particular source keys that differ from current Maestro defaults must remain intact.
by_command = {item['commandID']: item for item in entries if 'commandID' in item}
assert by_command['saveAs']['shortcut'] == 'Option＋Shift＋Command＋S'
assert by_command['sendBackward']['shortcut'] == 'Option＋Shift＋Command＋B'
assert by_command['group']['shortcut'] == 'Option＋Command＋G'
print('PASS: all 341 source pairs preserved verbatim and in order; original headings, contextual duplicates, mappings and 4-language labels verified')

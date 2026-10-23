"""Import the user-supplied Japanese Keynote shortcut reference without changing its wording.

The source is a supplied snapshot, not a probe of the user's macOS key overrides.
Run from any directory. IDs are section + original row number; mappings name existing command IDs.
"""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
section_ids = ['general', 'navigation', 'textSelection', 'textFormat', 'findComments',
               'objects', 'editableShapes', 'tables', 'chartData', 'formulas',
               'navigator', 'lightTable', 'presentation', 'video']
# Only the same operation is joined. Similar compound operations (e.g. fit selection + zoom out)
# keep their own row so the reference never claims that the native key runs our extra steps.
mappings = {
    ('general', 1): 'newDocument', ('general', 6): 'saveAs',
    ('general', 15): 'zoomIn', ('general', 16): 'zoomOut',
    ('general', 19): 'zoomToContent', ('general', 20): 'fitSlide',
    ('general', 28): 'hideInspector', ('general', 29): 'objectList',
    ('navigation', 19): 'nextSlide', ('navigation', 20): 'previousSlide',
    ('navigation', 21): 'firstSlide', ('navigation', 22): 'lastSlide', ('navigation', 23): 'goToSlide',
    ('textFormat', 10): 'fontBigger', ('textFormat', 11): 'fontSmaller',
    ('textFormat', 12): 'tighten', ('textFormat', 13): 'loosen',
    ('textFormat', 16): 'textLeft', ('textFormat', 17): 'textCenter',
    ('textFormat', 18): 'textRight', ('textFormat', 19): 'textJustify', ('textFormat', 30): 'pasteMatchStyle',
    ('objects', 16): 'sendToBack', ('objects', 17): 'sendBackward',
    ('objects', 18): 'bringToFront', ('objects', 19): 'bringForward',
    ('objects', 20): 'group', ('objects', 21): 'ungroup',
    ('navigator', 0): 'newSlide', ('navigator', 11): 'expand',
    ('navigator', 12): 'collapse', ('navigator', 13): 'skipSlide',
}
lines = (root / 'Reference/KeynoteShortcuts-ja.txt').read_text().splitlines()
starts = [i for i, line in enumerate(lines) if line == '操作']
assert len(starts) == len(section_ids)
entries = []
for index, start in enumerate(starts):
    end = starts[index + 1] - 1 if index + 1 < len(starts) else lines.index('関連項目')
    content = [line for line in lines[start + 2:end] if line.strip()
               and not line.startswith('音声入力の設定を変更するには')]
    assert len(content) % 2 == 0
    section = section_ids[index]
    for row in range(len(content) // 2):
        item = dict(id=f'{section}.{row:02d}', section=section,
                    title=content[row * 2], shortcut=content[row * 2 + 1])
        if (section, row) in mappings:
            item['commandID'] = mappings[(section, row)]
        entries.append(item)
assert len({item['id'] for item in entries}) == len(entries)
assert sum('commandID' in item for item in entries) == len(mappings)
(root / 'Resources/NativeShortcuts.json').write_text(json.dumps(entries, ensure_ascii=False, indent=2) + '\n')
print(f'Imported {len(entries)} native entries in {len(starts)} categories; {len(mappings)} equivalent command mappings')

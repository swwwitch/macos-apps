"""Every language has the same keys, every key used in the source exists, and format placeholders match."""
from pathlib import Path
import re, sys
root = Path(__file__).resolve().parents[1]
def load(lang):
    text = (root / 'Resources' / f'{lang}.lproj' / 'Localizable.strings').read_text()
    return dict(re.findall(r'^"((?:[^"\\]|\\.)*)" = "((?:[^"\\]|\\.)*)";$', text, re.M))
langs = ['ja', 'en', 'zh-Hans', 'ko']
tables = {lang: load(lang) for lang in langs}
errors = []
base = tables['en']
for lang, table in tables.items():
    if set(table) != set(base): errors.append(f'{lang}: keys differ {set(table) ^ set(base)}')
    for key, value in table.items():
        if sorted(re.findall(r'%(?:\d\$)?l?[@d]', value)) != sorted(re.findall(r'%(?:\d\$)?l?[@d]', base.get(key, ''))):
            errors.append(f'{lang}: placeholders differ in {key}')
source = '\n'.join(p.read_text() for p in (root / 'Source').glob('*.swift'))
used = set(re.findall(r'L\("([^"]+)"\)', source)) | {k for k in re.findall(r'"((?:metrics|watch|bg|bright|shape|hotkey|fail)\.[A-Za-z0-9.]+)"', source) if not k.endswith('.')}
used |= {'bright.level.' + k for k in ('dark', 'mediumDark', 'mediumLight', 'light')}
used |= {'on', 'off', 'undo', 'redo', 'cut', 'copy', 'paste', 'selectAll', 'minimize', 'zoom'}
for key in sorted(used):
    if key not in base: errors.append(f'missing key {key}')
print('\n'.join(errors) if errors else 'Resources OK')
sys.exit(1 if errors else 0)

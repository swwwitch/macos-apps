#!/bin/zsh
set -eu
cd "${0:A:h}"
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/commanddee-tests.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun swiftc -module-cache-path "$TEST_DIR/cache" Sources/Localization.swift Sources/Duplicator.swift Sources/Shortcut.swift Tests/main.swift -o "$TEST_DIR/tests"
"$TEST_DIR/tests"
python3 make-resources.py
python3 - <<'PY'
# Localization: every L() key in all 4 languages, identical key sets, matching format specifiers, help files.
import re, json, pathlib
root = pathlib.Path('.')
langs = ['ja', 'en', 'zh-Hans', 'ko']
used = set()
for p in (root / 'Sources').glob('*.swift'):
    used.update(re.findall(r'\bL\("([^"\\]+)"[,)]', p.read_text()))
# Keys built at runtime in main.swift: L("progress." + action) etc.
used.update(f'{kind}.{action}' for kind in ['progress', 'done', 'partial'] for action in ['duplicate', 'rename', 'swap'])
def load(path):
    text = path.read_text(encoding='utf-8')
    pairs = re.findall(r'^("(?:[^"\\]|\\.)*") = ("(?:[^"\\]|\\.)*");$', text, re.M)
    assert len(pairs) == len([l for l in text.splitlines() if l.strip()]), f'unparsed line in {path}'
    return {json.loads(k): json.loads(v) for k, v in pairs}
spec = re.compile(r'%(?:\d+\$)?[@dfsiu]')
def specs(value):
    found = spec.findall(value)
    # Positional and sequential forms are equivalent; compare the sorted argument types.
    return sorted(re.sub(r'\d+\$', '', s) for s in found)
tables = {lang: load(root / 'Resources' / f'{lang}.lproj' / 'Localizable.strings') for lang in langs}
checks = 0
headings = {}
for lang, table in tables.items():
    missing = used - table.keys(); assert not missing, (lang, sorted(missing)); checks += 1
    unused = table.keys() - used; assert not unused, (lang, 'unused keys', sorted(unused)); checks += 1
    assert table.keys() == tables['ja'].keys(), (lang, 'key mismatch'); checks += 1
    empty = [k for k, v in table.items() if not v.strip()]; assert not empty, (lang, empty); checks += 1
    for key, value in table.items():
        assert specs(value) == specs(tables['ja'][key]), (lang, key, value); checks += 1
    info = load(root / 'Resources' / f'{lang}.lproj' / 'InfoPlist.strings')
    assert info.get('NSAppleEventsUsageDescription', '').strip(), (lang, 'InfoPlist'); checks += 1
    help_text = (root / 'Resources' / f'{lang}.lproj' / 'Help.txt').read_text(encoding='utf-8')
    # HelpDocument markup: same ## / ### structure in every language, no '# ' title, no legacy '----' sections.
    lines = help_text.strip().splitlines()
    structure = [l.split(' ', 1)[0] for l in lines if l.startswith('#')]
    assert structure.count('##') >= 5 and '# ' not in [l[:2] for l in lines], (lang, 'Help.txt headings'); checks += 1
    if lang == 'ja': headings['ja'] = structure
    assert structure == headings['ja'], (lang, 'Help.txt heading structure differs from ja'); checks += 1
    assert '----' not in lines and any(l.startswith('- ') for l in lines), (lang, 'Help.txt bullets'); checks += 1
    assert tables[lang]['menu.appHelp'] in help_text and tables[lang]['menu.help'] in help_text, (lang, 'help names the status menu Help submenu'); checks += 1
    for shortcut in ['⌘D', '⌃⌘D', '⌃⌘E', '⌃E', '⌃⇧⌘D', '⌃⌥⌘S', '⌘,', '⌘M', '⌘Q']:
        assert shortcut in help_text, (lang, 'help shortcut', shortcut)
    checks += 1
for lang in ['en', 'zh-Hans', 'ko']:
    same = [k for k, v in tables[lang].items() if v == tables['ja'][k] and re.search('[ぁ-んァ-ヶ一-龥]', v)]
    assert not same, (lang, 'untranslated Japanese', same); checks += 1
note_titles = {'ja': 'note記事を開く', 'en': 'Open the note Article', 'zh-Hans': '打开 note 文章', 'ko': 'note 글 열기'}
shared = (root / 'Sources' / 'HelpDocument.swift').read_text()
assert all(t in shared for t in note_titles.values()), 'HelpLinks titles changed'
for lang in langs:
    assert note_titles[lang] in (root / 'Resources' / f'{lang}.lproj' / 'Help.txt').read_text(encoding='utf-8'), (lang, 'help mentions the note item')
checks += 1
plist = (root / 'build.sh').read_text()
assert '<key>SWNoteArticleURL</key><string>https://note.com/swwwitch/m/m057948d2fbeb</string>' in plist, 'SWNoteArticleURL'
checks += 1
for lang in langs:
    assert f'<string>{lang}</string>' in plist.split('CFBundleLocalizations', 1)[1].split('</array>', 1)[0], lang
checks += 1
print(f'PASS: {checks} localization checks ({len(used)} keys x {len(langs)} languages)')
PY

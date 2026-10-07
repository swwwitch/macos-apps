#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""B15/B16 localization check for MightyEdit.

Checks the generated Resources (run make-resources.py first) and, when given, a built .app:
  - ja / en / zh-Hans / ko Localizable.strings parse and have identical key sets
  - every value is non-empty and keeps the Japanese format specifiers
  - every L("key") used in Source/*.swift exists in the table
  - Help.txt exists and is non-empty for every language
  - the Japanese fallback table equals ja.lproj (unit tests see the same Japanese text)
  - the app bundle (optional argument) declares CFBundleLocalizations and contains all .lproj
Usage: python3 Tests/check-localization.py [path/to/MightyEdit.app]
"""
from pathlib import Path
import json, plistlib, re, subprocess, sys

root = Path(__file__).resolve().parents[1]
LANGS = ['ja', 'en', 'zh-Hans', 'ko']
PLACEHOLDER = re.compile(r'%(?:\d+\$)?[@dlsf]')
failures = []

def load_strings(path):
    data = subprocess.run(['plutil', '-convert', 'json', '-o', '-', str(path)], capture_output=True, check=True).stdout
    return json.loads(data)

tables = {}
for lang in LANGS:
    folder = root / 'Resources' / f'{lang}.lproj'
    try:
        tables[lang] = load_strings(folder / 'Localizable.strings')
    except Exception as error:
        failures.append(f'{lang}: Localizable.strings unreadable ({error})')
        tables[lang] = {}
    help_file = folder / 'Help.txt'
    if not help_file.is_file() or len(help_file.read_text(encoding='utf-8').strip()) < 200:
        failures.append(f'{lang}: Help.txt missing or too short')

reference = tables['ja']
for lang in LANGS[1:]:
    table = tables[lang]
    for key in sorted(set(reference) - set(table)):
        failures.append(f'{lang}: missing key {key}')
    for key in sorted(set(table) - set(reference)):
        failures.append(f'{lang}: extra key {key}')
for lang, table in tables.items():
    for key, value in table.items():
        if not value.strip():
            failures.append(f'{lang}: empty value {key}')
        if key in reference and sorted(PLACEHOLDER.findall(value)) != sorted(PLACEHOLDER.findall(reference[key])):
            failures.append(f'{lang}: placeholder mismatch {key}')

used = set()
for source in (root / 'Source').glob('*.swift'):
    used |= set(re.findall(r'\bL\("([A-Za-z0-9_.]+)"', source.read_text(encoding='utf-8')))
for key in sorted(used - set(reference)):
    failures.append(f'source uses unknown key {key}')
# Keys looked up indirectly (e.g. group titles in a dictionary) appear as plain literals.
literals = set()
for source in (root / 'Source').glob('*.swift'):
    if source.name != 'LocalizationFallback.swift':
        literals |= set(re.findall(r'"([A-Za-z0-9_.]+)"', source.read_text(encoding='utf-8')))
unused = sorted(set(reference) - used - literals)

fallback = (root / 'Source' / 'LocalizationFallback.swift').read_text(encoding='utf-8')
pairs = dict(re.findall(r'^\s+("(?:[^"\\]|\\.)*"): ("(?:[^"\\]|\\.)*"),$', fallback, re.M))
if {json.loads(k): json.loads(v) for k, v in pairs.items()} != reference:
    failures.append('LocalizationFallback.swift differs from ja.lproj (run make-resources.py)')

if len(sys.argv) > 1:
    app = Path(sys.argv[1])
    with open(app / 'Contents' / 'Info.plist', 'rb') as handle:
        info = plistlib.load(handle)
    if info.get('CFBundleLocalizations') != LANGS:
        failures.append(f'CFBundleLocalizations is {info.get("CFBundleLocalizations")}')
    for lang in LANGS:
        for name in ['Localizable.strings', 'Help.txt']:
            built = app / 'Contents' / 'Resources' / f'{lang}.lproj' / name
            source = root / 'Resources' / f'{lang}.lproj' / name
            if not built.is_file() or built.read_bytes() != source.read_bytes():
                failures.append(f'bundle: {lang}.lproj/{name} missing or stale')

if failures:
    print('\n'.join(failures))
    sys.exit(1)
print(f'Localization OK: {len(reference)} keys x {len(LANGS)} languages, {len(used)} used in source'
      + (f', unused: {", ".join(unused)}' if unused else '') + ('; bundle verified' if len(sys.argv) > 1 else ''))

#!/usr/bin/env python3
"""Verify the 4 localizations (ja, en, zh-Hans, ko) of this app.

Usage:
  python3 check-localization.py              # check Localizations/ in the source tree
  python3 check-localization.py App.app      # also check the built bundle's Resources

Checks: every language has Localizable.strings, InfoPlist.strings and a non-empty
Help.txt with section headings; Help.txt has the same number of ## sections, ### subsections
and list items (- / 1.) in every language and mentions the note article (Help menu);
the .strings key sets match across languages with no duplicate or empty values; format
placeholders match per key; the bundle contains the same Help.txt files and an
Info.plist SWNoteArticleURL.
"""
import plistlib
import re
import sys
from pathlib import Path

LANGUAGES = ["ja", "en", "zh-Hans", "ko"]
ROOT = Path(__file__).resolve().parent / "Localizations"
ENTRY = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;\s*$')
# Positional forms (%1$@) may reorder arguments; compare only the conversion types.
PLACEHOLDER = re.compile(r"%(?:\d+\$)?([@dDuUxXoOfeEgGcCsSpaAF%])")
errors = []


def parse(path):
    table = {}
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip() or line.strip().startswith(("//", "/*", "*")):
            continue
        match = ENTRY.match(line)
        if not match:
            errors.append(f"{path}: line {number} is not a key = value entry")
            continue
        key, value = match.groups()
        if key in table:
            errors.append(f"{path}: duplicate key {key!r}")
        if not value.strip():
            errors.append(f"{path}: empty value for {key!r}")
        table[key] = value
    return table


def check_help(path):
    if not path.is_file():
        errors.append(f"missing {path}")
        return None
    text = path.read_text(encoding="utf-8").strip()
    if not text:
        errors.append(f"empty {path}")
    elif not any(line.startswith("## ") for line in text.splitlines()):
        errors.append(f"{path}: no '## ' section headings")
    return text


def compare(name):
    tables = {}
    for language in LANGUAGES:
        path = ROOT / f"{language}.lproj" / name
        if not path.is_file():
            errors.append(f"missing {path}")
            continue
        tables[language] = parse(path)
    if "ja" not in tables:
        return
    base = tables["ja"]
    for language, table in tables.items():
        missing = sorted(set(base) - set(table))
        extra = sorted(set(table) - set(base))
        if missing:
            errors.append(f"{language}/{name}: missing keys {missing}")
        if extra:
            errors.append(f"{language}/{name}: extra keys {extra}")
        for key in set(base) & set(table):
            if sorted(PLACEHOLDER.findall(base[key])) != sorted(PLACEHOLDER.findall(table[key])):
                errors.append(f"{language}/{name}: placeholders differ for {key!r}")
    print(f"{name}: {len(base)} keys x {len(tables)} languages")


compare("Localizable.strings")
compare("InfoPlist.strings")
sources = {language: check_help(ROOT / f"{language}.lproj" / "Help.txt") for language in LANGUAGES}
headings = {language: sum(1 for line in (text or "").splitlines() if line.startswith("## ")) for language, text in sources.items()}
if len(set(headings.values())) != 1:
    errors.append(f"Help.txt section counts differ: {headings}")
print("Help.txt sections: " + ", ".join(f"{language} {count}" for language, count in headings.items()))


def count(text, test):
    return sum(1 for line in (text or "").splitlines() if test(line.strip()))


def is_item(line):
    digits = len(line) - len(line.lstrip("0123456789"))
    return line.startswith(("- ", "・", "• ")) or (0 < digits <= 2 and line[digits:].startswith(". "))


subsections = {language: count(text, lambda line: line.startswith("### ")) for language, text in sources.items()}
if len(set(subsections.values())) != 1:
    errors.append(f"Help.txt subsection counts differ: {subsections}")
items = {language: count(text, is_item) for language, text in sources.items()}
if len(set(items.values())) != 1:
    errors.append(f"Help.txt list item counts differ: {items}")
for language, text in sources.items():
    if text is not None and "note" not in text:
        errors.append(f"{language}/Help.txt: no mention of the note article in the Help menu")
print("Help.txt subsections: " + ", ".join(f"{language} {n}" for language, n in subsections.items()))
print("Help.txt list items: " + ", ".join(f"{language} {n}" for language, n in items.items()))

if len(sys.argv) > 1:
    resources = Path(sys.argv[1]) / "Contents" / "Resources"
    for language in LANGUAGES:
        built = check_help(resources / f"{language}.lproj" / "Help.txt")
        if built is not None and sources[language] is not None and built != sources[language]:
            errors.append(f"{resources}/{language}.lproj/Help.txt differs from the source")
    info = Path(sys.argv[1]) / "Contents" / "Info.plist"
    try:
        note = plistlib.loads(info.read_bytes()).get("SWNoteArticleURL", "")
    except (OSError, plistlib.InvalidFileException) as error:
        note = ""
        errors.append(f"{info}: {error}")
    if not str(note).startswith("https://note.com/"):
        errors.append(f"{info}: SWNoteArticleURL is missing or not a note.com URL")
    print(f"bundle: {resources} (SWNoteArticleURL {note})")

if errors:
    print("Localization check FAILED:", *errors, sep="\n  ", file=sys.stderr)
    sys.exit(1)
print("Localization check passed.")

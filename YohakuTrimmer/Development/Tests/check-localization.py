#!/usr/bin/env python3
"""Localization check: ja/en/zh-Hans/ko must each have a non-empty Help.txt
and the same Localizable.strings / InfoPlist.strings keys.

usage: check-localization.py [--app path/to/App.app]
Without --app it checks the source Localizations folder next to this script's parent.
With --app it also checks the built bundle's Contents/Resources.
"""
import json, plistlib, re, subprocess, sys
from pathlib import Path

LANGS = ["ja", "en", "zh-Hans", "ko"]
STRINGS = ["Localizable.strings", "InfoPlist.strings"]


def load_strings(path: Path) -> dict:
    out = subprocess.run(["plutil", "-convert", "json", "-o", "-", str(path)], capture_output=True, text=True)
    if out.returncode != 0:
        raise ValueError(f"{path}: {out.stderr.strip()}")
    return json.loads(out.stdout)


def check(root: Path, label: str) -> list[str]:
    errors = []
    headings = {}
    for lang in LANGS:
        help_file = root / f"{lang}.lproj" / "Help.txt"
        if not help_file.is_file():
            errors.append(f"[{label}] missing {help_file}")
            continue
        text = help_file.read_text(encoding="utf-8").strip()
        if not text:
            errors.append(f"[{label}] empty {help_file}")
        headings[lang] = sum(1 for line in text.splitlines() if line.startswith("## "))
    if len(set(headings.values())) > 1:
        errors.append(f"[{label}] Help.txt section counts differ: {headings}")
    # Subsections (###) and list items (- / 1.) stay parallel; each help mentions the note article.
    shapes = {}
    for lang in LANGS:
        help_file = root / f"{lang}.lproj" / "Help.txt"
        if not help_file.is_file():
            continue
        lines = [line.strip() for line in help_file.read_text(encoding="utf-8").splitlines()]
        shapes[lang] = (sum(1 for line in lines if line.startswith("### ")),
                        sum(1 for line in lines if line.startswith(("- ", "・", "• ")) or re.match(r"\d{1,2}\. ", line)))
        if not any("note" in line for line in lines):
            errors.append(f"[{label}] {lang}/Help.txt: no mention of the note article in the Help menu")
    if len(set(shapes.values())) > 1:
        errors.append(f"[{label}] Help.txt subsection/list item counts differ: {shapes}")
    for name in STRINGS:
        tables = {}
        for lang in LANGS:
            path = root / f"{lang}.lproj" / name
            if not path.is_file():
                errors.append(f"[{label}] missing {path}")
                continue
            try:
                tables[lang] = load_strings(path)
            except ValueError as error:
                errors.append(f"[{label}] {error}")
        if not tables:
            continue
        reference = set(tables.get("ja", next(iter(tables.values()))))
        for lang, table in tables.items():
            missing, extra = reference - set(table), set(table) - reference
            if missing or extra:
                errors.append(f"[{label}] {lang}/{name}: missing {sorted(missing)} extra {sorted(extra)}")
            empty = [key for key, value in table.items() if not str(value).strip()]
            if empty:
                errors.append(f"[{label}] {lang}/{name}: empty values {empty}")
    return errors


def main() -> int:
    source = Path(__file__).resolve().parent.parent / "Localizations"
    errors = check(source, "source")
    if "--app" in sys.argv:
        app = Path(sys.argv[sys.argv.index("--app") + 1])
        errors += check(app / "Contents" / "Resources", app.name)
        try:
            note = plistlib.loads((app / "Contents" / "Info.plist").read_bytes()).get("SWNoteArticleURL", "")
        except (OSError, plistlib.InvalidFileException) as error:
            note = f"unreadable ({error})"
        if not str(note).startswith("https://note.com/"):
            errors.append(f"[{app.name}] Info.plist SWNoteArticleURL is missing or not a note.com URL: {note!r}")
    for error in errors:
        print("FAIL", error)
    if not errors:
        print("PASS localization: Help.txt and strings keys for " + ", ".join(LANGS))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())

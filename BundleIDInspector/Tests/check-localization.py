#!/usr/bin/env python3
"""Localization check: ja/en/zh-Hans/ko must each have a non-empty Help.txt
with the same ## / ### heading structure (HelpDocument markup, no "# " title line,
mentions the shared "note記事を開く" item) and the same Localizable.strings / InfoPlist.strings keys.
With --app it also checks Info.plist SWNoteArticleURL.

usage: check-localization.py [--app path/to/App.app]
Without --app it checks the source Localizations folder next to this script's parent.
With --app it also checks the built bundle's Contents/Resources.
"""
import json, subprocess, sys
from pathlib import Path

LANGS = ["ja", "en", "zh-Hans", "ko"]
STRINGS = ["Localizable.strings", "InfoPlist.strings"]
# HelpLinks.noteTitle in Sources/BundleIDInspector/HelpDocument.swift (synced from Shared/AppStandards).
NOTE_TITLES = {"ja": "note記事を開く", "en": "Open the note Article", "zh-Hans": "打开 note 文章", "ko": "note 글 열기"}
NOTE_URL = "https://note.com/swwwitch/m/m057948d2fbeb"


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
        lines = text.splitlines()
        headings[lang] = tuple(line.split(" ", 1)[0] for line in lines if line.startswith("#"))
        if any(line.startswith("# ") for line in lines):
            errors.append(f"[{label}] {lang}/Help.txt: no '# ' title line (the window adds it)")
        if headings[lang].count("##") < 5 or not any(line.startswith("- ") for line in lines):
            errors.append(f"[{label}] {lang}/Help.txt: needs ## sections and - bullets")
        if NOTE_TITLES[lang] not in text:
            errors.append(f"[{label}] {lang}/Help.txt: does not mention {NOTE_TITLES[lang]}")
    if len(set(headings.values())) > 1:
        errors.append(f"[{label}] Help.txt heading structure differs: {headings}")
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
        info = subprocess.run(["/usr/libexec/PlistBuddy", "-c", "Print :SWNoteArticleURL", str(app / "Contents" / "Info.plist")], capture_output=True, text=True)
        if info.stdout.strip() != NOTE_URL:
            errors.append(f"[{app.name}] Info.plist SWNoteArticleURL is {info.stdout.strip() or 'missing'}")
    for error in errors:
        print("FAIL", error)
    if not errors:
        print("PASS localization: Help.txt headings, note item and strings keys for " + ", ".join(LANGS))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())

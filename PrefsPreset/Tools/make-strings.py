#!/usr/bin/env python3
"""Writes Localizations/<lang>.lproj/Localizable.strings from translations.tsv
(columns: ja key, en, zh-Hans, ko). Fails if a key from extract-keys.py has no row."""
import subprocess, sys
from pathlib import Path

tools = Path(__file__).resolve().parent
root = tools.parent
keys = subprocess.run([sys.executable, str(tools / "extract-keys.py")], capture_output=True, text=True, check=True).stdout.splitlines()
rows = {}
for line in (tools / "translations.tsv").read_text(encoding="utf-8").split("\n"):
    if not line:
        continue
    cols = line.split("\t")
    if len(cols) != 4:
        sys.exit(f"bad row ({len(cols)} columns): {line!r}")
    rows[cols[0]] = {"ja": cols[0], "en": cols[1], "zh-Hans": cols[2], "ko": cols[3]}
missing = [k for k in keys if k not in rows]
unused = [k for k in rows if k not in keys]
if missing or unused:
    sys.exit(f"missing: {missing}\nunused: {unused}")
esc = lambda s: s.replace("\\", "\\\\").replace('"', '\\"')
for lang in ["ja", "en", "zh-Hans", "ko"]:
    folder = root / "Localizations" / f"{lang}.lproj"
    folder.mkdir(parents=True, exist_ok=True)
    body = "".join(f'"{esc(k)}" = "{esc(rows[k][lang])}";\n' for k in keys)
    (folder / "Localizable.strings").write_text(body, encoding="utf-8")
    (folder / "InfoPlist.strings").write_text('"CFBundleDisplayName" = "PrefsPreset";\n', encoding="utf-8")
print(f"wrote {len(keys)} keys × 4 languages")

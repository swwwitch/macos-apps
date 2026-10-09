#!/usr/bin/env python3
"""Lists every Localizable.strings key: L("…") literals in the sources plus the catalog's
category names, item labels and choice labels (shown through L() at display time)."""
import re, sys
from pathlib import Path

src = Path(__file__).resolve().parent.parent / "Sources/PrefsPreset"
keys = []
def add(k):
    if k not in keys: keys.append(k)
for f in ["PrefsPresetApp.swift", "ContentView.swift", "SettingsView.swift", "Store.swift", "MyPreset.swift"]:
    for m in re.finditer(r'\bL\("((?:[^"\\]|\\.)*)"', (src / f).read_text()):
        add(m.group(1))
cat = (src / "Catalog.swift").read_text()
for m in re.finditer(r'^\s*\("([^"]+)", "[^"]+"\),', cat, re.M):            # categoryOrder
    add(m.group(1))
add("追加した項目")
for m in re.finditer(r'(?:item|flag)\("[^"]+", "([^"]+)"', cat):            # item / flag labels
    add(m.group(1))
for m in re.finditer(r'trackpad\("([^"]+)"', cat):
    add(m.group(1))
for m in re.finditer(r'"[^"]*": "([^"]+)"', cat):                           # choice labels
    add(m.group(1))
print("\n".join(keys))

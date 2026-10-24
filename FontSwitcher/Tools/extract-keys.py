#!/usr/bin/env python3
"""Lists every Localizable.strings key: L("…") literals in the app's own sources
(the shared parts translate inline with StartupWindow.text)."""
import re
from pathlib import Path

src = Path(__file__).resolve().parent.parent / "Sources/FontSwitcher"
keys = []
for f in ["FontSwitcherApp.swift", "ContentView.swift", "FontLibrary.swift", "LibraryStore.swift", "FamilyOutline.swift", "AppHotkey.swift", "SettingsView.swift", "AppDelegate.swift"]:
    for m in re.finditer(r'\bL\("((?:[^"\\]|\\.)*)"', (src / f).read_text()):
        if m.group(1) not in keys:
            keys.append(m.group(1))
print("\n".join(keys))

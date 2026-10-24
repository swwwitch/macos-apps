#!/usr/bin/env python3
"""Lists every Localizable.strings key: L("…") literals in the app's own sources
(the shared parts translate inline with StartupWindow.text)."""
import re
from pathlib import Path

src = Path(__file__).resolve().parent.parent / "Sources/SiteMirror"
keys = []
for f in ["SiteMirrorApp.swift", "ContentView.swift", "Mirror.swift", "Crawler.swift", "SettingsView.swift", "AppDelegate.swift"]:
    for m in re.finditer(r'\bL\("((?:[^"\\]|\\.)*)"', (src / f).read_text()):
        if m.group(1) not in keys:
            keys.append(m.group(1))
print("\n".join(keys))

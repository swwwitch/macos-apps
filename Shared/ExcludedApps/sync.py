from pathlib import Path
root = Path(__file__).resolve().parents[2]
source = (root / "Shared/ExcludedApps/ExcludedApps.swift").read_bytes()
# MightyEdit joined on 2026-10-17 after its own AppKit ExcludedApps.swift was migrated.
# Apps that compile ../Shared/ExcludedApps/ExcludedApps.swift directly are not listed.
for target in ['DocklessLauncher/Sources', 'MightyEdit/Source', 'IncrementPaste/Sources', 'KakkoReplace/Sources', 'LinkMaker/Sources',
               'PasteInARow/Sources', 'PasteMatchStyle/Sources']:
    path = root / target / "ExcludedApps.swift"
    if not path.parent.is_dir():
        continue
    if not path.exists() or path.read_bytes() != source:
        path.write_bytes(source)

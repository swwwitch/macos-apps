from pathlib import Path
root = Path(__file__).resolve().parents[2]
source = (root / "Shared/HotkeyManifest/HotkeyManifest.swift").read_bytes()
for target in ['MightyEdit/Source', 'BrowserSwitcher/Source', 'FolderHopper/Development/Source', 'KageTrimmer/Development/Sources', 'YohakuTrimmer/Development/Sources', 'CommandDee/Sources', 'KakkoReplace/Sources', 'SpreadsheetHelper/Sources', 'KeynoteMaestro/Sources', 'PasteInARow/Sources', 'IncrementPaste/Sources', 'PasteMatchStyle/Sources', 'LinkMaker/Sources', 'ProjectFolder/Sources', 'DocklessLauncher/Sources', 'QuickIconExporter/Development/Sources/IconDrop']:
    path = root / target / "HotkeyManifest.swift"
    if not path.parent.is_dir():
        continue
    if not path.exists() or path.read_bytes() != source:
        path.write_bytes(source)

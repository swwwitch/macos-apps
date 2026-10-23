from pathlib import Path
root = Path(__file__).resolve().parents[2]
source = (root / "Shared/HotkeyRecorder/HotkeyRecorder.swift").read_bytes()
# Apps join this list when they adopt the shared field; direct-compile apps build the Shared file instead.
TARGETS = ['MightyEdit/Source', 'BrowserSwitcher/Source', 'CommandDee/Sources', 'FolderHopper/Development/Source', 'KageTrimmer/Development/Sources', 'YohakuTrimmer/Development/Sources', 'KakkoReplace/Sources', 'LinkMaker/Sources', 'IncrementPaste/Sources', 'PasteInARow/Sources', 'PasteMatchStyle/Sources', 'SpreadsheetHelper/Sources', 'KeynoteMaestro/Sources', 'ProjectFolder/Sources', 'MarkdownKitchen/Sources/MarkdownKitchen', 'QuickIconExporter/Development/Sources/IconDrop']
for target in TARGETS:
    path = root / target / "HotkeyRecorder.swift"
    if not path.parent.is_dir():
        continue
    if not path.exists() or path.read_bytes() != source:
        path.write_bytes(source)

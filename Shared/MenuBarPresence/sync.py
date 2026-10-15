from pathlib import Path
root = Path(__file__).resolve().parents[2]
source = (root / "Shared/MenuBarPresence/MenuBarPresence.swift").read_bytes()
for target in ['MightyEdit/Source', 'BrowserSwitcher/Source', 'FolderHopper/Development/Source', 'KageTrimmer/Development/Sources', 'YohakuTrimmer/Development/Sources', 'QuickIconExporter/Development/Sources/IconDrop', 'PodiumAssist/Development/Sources/Toki', 'CommandDee/Sources', 'ExtensionLinker/Development/Sources/DutiGUI', 'CarmaChameleon/Source', 'FileCaravan/Source', 'IdBackgroundOff/Source', 'CCAutoUpdateOff/Source', 'KakkoReplace/Sources', 'CellCopyCleaner/Sources', 'PasteInARow/Sources', 'IncrementPaste/Sources', 'PasteMatchStyle/Sources', 'LinkMaker/Sources', 'ProjectFolder/Sources', 'DocklessLauncher/Sources', 'BundleIDInspector/Sources/BundleIDInspector', 'HotkeyHound/Sources/HotkeyHound', 'PrefsPreset/Sources/PrefsPreset', 'MarkdownKitchen/Sources/MarkdownKitchen', 'note2markdown/Source', 'ListMatch/Source']:
    path = root / target / "MenuBarPresence.swift"
    if not path.parent.is_dir():
        continue
    if not path.exists() or path.read_bytes() != source:
        path.write_bytes(source)

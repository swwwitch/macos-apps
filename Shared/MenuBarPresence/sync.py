from pathlib import Path
root = Path(__file__).resolve().parents[2]
source = (root / "Shared/MenuBarPresence/MenuBarPresence.swift").read_bytes()
for target in ['MightyEdit/Source', 'BrowserSwitcher/Source', 'FolderHopper/Development/Source', 'KageTrimmer/Development/Sources', 'QuickIconExporter/Development/Sources/IconDrop', 'PodiumFlight/Development/Sources/Toki', 'CommandDee/Sources', 'ExtensionLinker/Development/Sources/DutiGUI', 'CarmaChameleon/Source', 'FileCaravan/Source', 'IdBackgroundOff/Source', 'KakkoReplace/Sources', 'BundleIDInspector/Sources/BundleIDInspector', 'PrefsPreset/Sources/PrefsPreset']:
    path = root / target / "MenuBarPresence.swift"
    if not path.parent.is_dir():
        continue
    if not path.exists() or path.read_bytes() != source:
        path.write_bytes(source)

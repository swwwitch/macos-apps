from pathlib import Path
root = Path(__file__).resolve().parents[2]
# 個人利用のみのアプリは追跡外の Shared/PrivateApps/targets.txt から加える
private_list = root / "Shared/PrivateApps/targets.txt"
private_targets = [line.strip() for line in private_list.read_text().splitlines()
                   if line.strip() and not line.startswith("#")] if private_list.exists() else []
source = (root / "Shared/MenuBarPresence/MenuBarPresence.swift").read_bytes()
for target in ['MightyEdit/Source', 'BrowserSwitcher/Source', 'FolderHopper/Development/Source', 'KageTrimmer/Development/Sources', 'YohakuTrimmer/Development/Sources', 'QuickIconExporter/Development/Sources/IconDrop', 'PodiumAssist/Development/Sources/Toki', 'CommandDee/Sources', 'ExtensionLinker/Development/Sources/DutiGUI', 'CarmaChameleon/Source', 'FileCaravan/Source', 'IdBackgroundOff/Source', 'CCAutoUpdateOff/Source', 'KakkoReplace/Sources', 'SpreadsheetHelper/Sources', 'KeynoteMaestro/Sources', 'PasteInARow/Sources', 'IncrementPaste/Sources', 'PasteMatchStyle/Sources', 'LinkMaker/Sources', 'ProjectFolder/Sources', 'DocklessLauncher/Sources', 'BundleIDInspector/Sources/BundleIDInspector', 'HotkeyHound/Sources/HotkeyHound', 'PrefsPreset/Sources/PrefsPreset', 'MarkdownKitchen/Sources/MarkdownKitchen', 'note2markdown/Source', 'ListMatch/Source'] + private_targets:
    path = root / target / "MenuBarPresence.swift"
    if not path.parent.is_dir():
        continue
    if not path.exists() or path.read_bytes() != source:
        path.write_bytes(source)

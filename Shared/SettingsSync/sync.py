from pathlib import Path
root = Path(__file__).resolve().parents[2]
# 個人利用のみのアプリは追跡外の Shared/PrivateApps/targets.txt から加える
private_list = root / "Shared/PrivateApps/targets.txt"
private_targets = [line.strip() for line in private_list.read_text().splitlines()
                   if line.strip() and not line.startswith("#")] if private_list.exists() else []
source = (root / "Shared/SettingsSync/SettingsSync.swift").read_bytes()
# CCAutoUpdateOff, CarmaChameleon, FileCaravan, KeynoteSweeper, ListMatch, PDF2Keynote and note2markdown
# compile ../Shared/SettingsSync/SettingsSync.swift directly.
for target in ['BrowserSwitcher/Source', 'CommandDee/Sources', 'DocklessLauncher/Sources', 'ExtensionLinker/Development/Sources/DutiGUI',
               'FolderHopper/Development/Source', 'HotkeyHound/Sources/HotkeyHound', 'IncrementPaste/Sources', 'KageTrimmer/Development/Sources',
               'KakkoReplace/Sources', 'LinkMaker/Sources', 'MarkdownKitchen/Sources/MarkdownKitchen', 'MightyEdit/Source',
               'PasteInARow/Sources', 'PasteMatchStyle/Sources', 'PodiumAssist/Development/Sources/Toki', 'PrefsPreset/Sources/PrefsPreset',
               'ProjectFolder/Sources', 'QuickIconExporter/Development/Sources/IconDrop', 'SpreadsheetHelper/Sources', 'KeynoteMaestro/Sources', 'YohakuTrimmer/Development/Sources'] + private_targets:
    path = root / target / "SettingsSync.swift"
    if not path.parent.is_dir():
        continue
    if not path.exists() or path.read_bytes() != source:
        path.write_bytes(source)

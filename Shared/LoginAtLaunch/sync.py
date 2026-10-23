"""Copy the canonical LoginAtLaunch.swift and AccessibilityPermission.swift into apps that keep local copies.
CarmaChameleon, FileCaravan, PDF2Keynote and the other direct-compile apps build Shared/LoginAtLaunch/LoginAtLaunch.swift as is."""
from pathlib import Path
root = Path(__file__).resolve().parents[2]
copies = {
    'Shared/LoginAtLaunch/LoginAtLaunch.swift': ['BrowserSwitcher/Source', 'CommandDee/Sources', 'ExtensionLinker/Development/Sources/DutiGUI',
        'KageTrimmer/Development/Sources', 'YohakuTrimmer/Development/Sources', 'PodiumAssist/Development/Sources/Toki', 'QuickIconExporter/Development/Sources/IconDrop', 'BundleIDInspector/Sources/BundleIDInspector', 'HotkeyHound/Sources/HotkeyHound', 'PrefsPreset/Sources/PrefsPreset', 'MarkdownKitchen/Sources/MarkdownKitchen'],
    'Shared/Accessibility/AccessibilityPermission.swift': ['BrowserSwitcher/Source', 'CommandDee/Sources', 'ExtensionLinker/Development/Sources/DutiGUI',
        'KageTrimmer/Development/Sources', 'YohakuTrimmer/Development/Sources', 'PodiumAssist/Development/Sources/Toki', 'QuickIconExporter/Development/Sources/IconDrop',
        'KakkoReplace/Sources', 'DocklessLauncher/Sources', 'LinkMaker/Sources', 'MightyEdit/Source', 'FolderHopper/Development/Source', 'HotkeyHound/Sources/HotkeyHound', 'PasteMatchStyle/Sources',
        'IncrementPaste/Sources', 'PasteInARow/Sources', 'SpreadsheetHelper/Sources', 'KeynoteMaestro/Sources', 'ProjectFolder/Sources'],
}
for source, targets in copies.items():
    data = (root / source).read_bytes()
    for target in targets:
        path = root / target / Path(source).name
        if path.exists() and path.read_bytes() != data:
            path.write_bytes(data); print('updated', path.relative_to(root))

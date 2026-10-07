"""Copy the canonical LoginAtLaunch.swift and AccessibilityPermission.swift into apps that keep local copies.
FolderMover, CarmaChameleon and PDF2Keynote keep their own localized (L()-based) LoginAtLaunch and are not touched."""
from pathlib import Path
root = Path(__file__).resolve().parents[2]
copies = {
    'Shared/LoginAtLaunch/LoginAtLaunch.swift': ['BrowserSwitcher/Source', 'CommandDee/Sources', 'ExtensionLinker/Development/Sources/DutiGUI',
        'KageTrimmer/Development/Sources', 'PodiumFlight/Development/Sources/Toki', 'QuickIconExporter/Development/Sources/IconDrop'],
    'Shared/Accessibility/AccessibilityPermission.swift': ['BrowserSwitcher/Source', 'CommandDee/Sources', 'ExtensionLinker/Development/Sources/DutiGUI',
        'KageTrimmer/Development/Sources', 'PodiumFlight/Development/Sources/Toki', 'QuickIconExporter/Development/Sources/IconDrop',
        'KakkoReplace/Sources', 'MightyEdit/Source', 'FolderHopper/Development/Source'],
}
for source, targets in copies.items():
    data = (root / source).read_bytes()
    for target in targets:
        path = root / target / Path(source).name
        if path.exists() and path.read_bytes() != data:
            path.write_bytes(data); print('updated', path.relative_to(root))

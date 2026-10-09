from pathlib import Path
root = Path(__file__).resolve().parents[2]
source = Path(__file__).with_name("AppSurface.swift").read_bytes()
for relative in ['BrowserSwitcher/Source', 'CommandDee/Sources', 'ExtensionLinker/Development/Sources/DutiGUI', 'FolderHopper/Development/Source', 'KageTrimmer/Development/Sources', 'QuickIconExporter/Development/Sources/IconDrop', 'PodiumFlight/Development/Sources/Toki', 'MightyEdit/Source', 'KakkoReplace/Sources', 'BundleIDInspector/Sources/BundleIDInspector', 'PrefsPreset/Sources/PrefsPreset']:
    target = root / relative / "AppSurface.swift"
    if not target.parent.is_dir():
        continue
    if not target.exists() or target.read_bytes() != source:
        target.write_bytes(source)

startup = Path(__file__).with_name("StartupWindow.swift").read_bytes()
for relative in ['BrowserSwitcher/Source', 'CommandDee/Sources', 'ExtensionLinker/Development/Sources/DutiGUI', 'FolderHopper/Development/Source', 'KageTrimmer/Development/Sources', 'QuickIconExporter/Development/Sources/IconDrop', 'PodiumFlight/Development/Sources/Toki', 'MightyEdit/Source', 'KakkoReplace/Sources', 'BundleIDInspector/Sources/BundleIDInspector', 'PrefsPreset/Sources/PrefsPreset', 'FileCaravan/Source']:
    target = root / relative / 'StartupWindow.swift'
    if not target.parent.is_dir():
        continue
    if not target.exists() or target.read_bytes() != startup:
        target.write_bytes(startup)

settings = Path(__file__).with_name("SettingsSection.swift").read_bytes()
for relative in ['BrowserSwitcher/Source', 'CommandDee/Sources', 'ExtensionLinker/Development/Sources/DutiGUI', 'FolderHopper/Development/Source', 'KageTrimmer/Development/Sources', 'QuickIconExporter/Development/Sources/IconDrop', 'PodiumFlight/Development/Sources/Toki', 'MightyEdit/Source', 'KakkoReplace/Sources', 'BundleIDInspector/Sources/BundleIDInspector', 'PrefsPreset/Sources/PrefsPreset', 'FileCaravan/Source']:
    target = root / relative / "SettingsSection.swift"
    if not target.parent.is_dir():
        continue
    if not target.exists() or target.read_bytes() != settings:
        target.write_bytes(settings)

helpdoc = Path(__file__).with_name("HelpDocument.swift").read_bytes()
for relative in ['BrowserSwitcher/Source', 'CommandDee/Sources', 'ExtensionLinker/Development/Sources/DutiGUI', 'FolderHopper/Development/Source', 'KageTrimmer/Development/Sources', 'QuickIconExporter/Development/Sources/IconDrop', 'PodiumFlight/Development/Sources/Toki', 'MightyEdit/Source', 'KakkoReplace/Sources', 'BundleIDInspector/Sources/BundleIDInspector', 'PrefsPreset/Sources/PrefsPreset']:
    target = root / relative / "HelpDocument.swift"
    if not target.parent.is_dir():
        continue
    if not target.exists() or target.read_bytes() != helpdoc:
        target.write_bytes(helpdoc)

activation = Path(__file__).with_name("WindowActivationPolicy.swift").read_bytes()
for relative in ['KakkoReplace/Sources']:
    target = root / relative / "WindowActivationPolicy.swift"
    if not target.parent.is_dir():
        continue
    if not target.exists() or target.read_bytes() != activation:
        target.write_bytes(activation)

about = Path(__file__).with_name("AboutSection.swift").read_bytes()
for relative in ['KakkoReplace/Sources']:
    target = root / relative / "AboutSection.swift"
    if not target.parent.is_dir():
        continue
    if not target.exists() or target.read_bytes() != about:
        target.write_bytes(about)

from pathlib import Path
root = Path(__file__).resolve().parents[2]
# 個人利用のみのアプリは追跡外の Shared/PrivateApps/targets.txt から加える
private_list = root / "Shared/PrivateApps/targets.txt"
private_targets = [line.strip() for line in private_list.read_text().splitlines()
                   if line.strip() and not line.startswith("#")] if private_list.exists() else []
source = Path(__file__).with_name("AppSurface.swift").read_bytes()
for relative in ['BrowserSwitcher/Source', 'CommandDee/Sources', 'ExtensionLinker/Development/Sources/DutiGUI', 'FolderHopper/Development/Source', 'KageTrimmer/Development/Sources', 'YohakuTrimmer/Development/Sources', 'QuickIconExporter/Development/Sources/IconDrop', 'PodiumAssist/Development/Sources/Toki', 'MightyEdit/Source', 'KakkoReplace/Sources', 'SpreadsheetHelper/Sources', 'KeynoteMaestro/Sources', 'PasteInARow/Sources', 'IncrementPaste/Sources', 'PasteMatchStyle/Sources', 'LinkMaker/Sources', 'ProjectFolder/Sources', 'DocklessLauncher/Sources', 'BundleIDInspector/Sources/BundleIDInspector', 'HotkeyHound/Sources/HotkeyHound', 'PrefsPreset/Sources/PrefsPreset', 'MarkdownKitchen/Sources/MarkdownKitchen'] + private_targets:
    target = root / relative / "AppSurface.swift"
    if not target.parent.is_dir():
        continue
    if not target.exists() or target.read_bytes() != source:
        target.write_bytes(source)

startup = Path(__file__).with_name("StartupWindow.swift").read_bytes()
for relative in ['BrowserSwitcher/Source', 'CommandDee/Sources', 'ExtensionLinker/Development/Sources/DutiGUI', 'FolderHopper/Development/Source', 'KageTrimmer/Development/Sources', 'YohakuTrimmer/Development/Sources', 'QuickIconExporter/Development/Sources/IconDrop', 'PodiumAssist/Development/Sources/Toki', 'MightyEdit/Source', 'KakkoReplace/Sources', 'SpreadsheetHelper/Sources', 'KeynoteMaestro/Sources', 'PasteInARow/Sources', 'IncrementPaste/Sources', 'PasteMatchStyle/Sources', 'LinkMaker/Sources', 'ProjectFolder/Sources', 'DocklessLauncher/Sources', 'BundleIDInspector/Sources/BundleIDInspector', 'HotkeyHound/Sources/HotkeyHound', 'PrefsPreset/Sources/PrefsPreset', 'MarkdownKitchen/Sources/MarkdownKitchen', 'FileCaravan/Source'] + private_targets:
    target = root / relative / 'StartupWindow.swift'
    if not target.parent.is_dir():
        continue
    if not target.exists() or target.read_bytes() != startup:
        target.write_bytes(startup)

settings = Path(__file__).with_name("SettingsSection.swift").read_bytes()
for relative in ['BrowserSwitcher/Source', 'CommandDee/Sources', 'ExtensionLinker/Development/Sources/DutiGUI', 'FolderHopper/Development/Source', 'KageTrimmer/Development/Sources', 'YohakuTrimmer/Development/Sources', 'QuickIconExporter/Development/Sources/IconDrop', 'PodiumAssist/Development/Sources/Toki', 'MightyEdit/Source', 'KakkoReplace/Sources', 'SpreadsheetHelper/Sources', 'KeynoteMaestro/Sources', 'PasteInARow/Sources', 'IncrementPaste/Sources', 'PasteMatchStyle/Sources', 'LinkMaker/Sources', 'ProjectFolder/Sources', 'DocklessLauncher/Sources', 'BundleIDInspector/Sources/BundleIDInspector', 'HotkeyHound/Sources/HotkeyHound', 'PrefsPreset/Sources/PrefsPreset', 'MarkdownKitchen/Sources/MarkdownKitchen', 'FileCaravan/Source'] + private_targets:
    target = root / relative / "SettingsSection.swift"
    if not target.parent.is_dir():
        continue
    if not target.exists() or target.read_bytes() != settings:
        target.write_bytes(settings)

helpdoc = Path(__file__).with_name("HelpDocument.swift").read_bytes()
for relative in ['BrowserSwitcher/Source', 'CommandDee/Sources', 'ExtensionLinker/Development/Sources/DutiGUI', 'FolderHopper/Development/Source', 'KageTrimmer/Development/Sources', 'YohakuTrimmer/Development/Sources', 'QuickIconExporter/Development/Sources/IconDrop', 'PodiumAssist/Development/Sources/Toki', 'MightyEdit/Source', 'KakkoReplace/Sources', 'SpreadsheetHelper/Sources', 'KeynoteMaestro/Sources', 'PasteInARow/Sources', 'IncrementPaste/Sources', 'PasteMatchStyle/Sources', 'LinkMaker/Sources', 'ProjectFolder/Sources', 'DocklessLauncher/Sources', 'BundleIDInspector/Sources/BundleIDInspector', 'HotkeyHound/Sources/HotkeyHound', 'PrefsPreset/Sources/PrefsPreset', 'MarkdownKitchen/Sources/MarkdownKitchen'] + private_targets:
    target = root / relative / "HelpDocument.swift"
    if not target.parent.is_dir():
        continue
    if not target.exists() or target.read_bytes() != helpdoc:
        target.write_bytes(helpdoc)

activation = Path(__file__).with_name("WindowActivationPolicy.swift").read_bytes()
# Menu-bar (accessory) apps only: regular apps keep their Dock icon.
for relative in ['KakkoReplace/Sources', 'SpreadsheetHelper/Sources', 'KeynoteMaestro/Sources', 'PasteInARow/Sources', 'IncrementPaste/Sources', 'PasteMatchStyle/Sources', 'LinkMaker/Sources', 'ProjectFolder/Sources', 'DocklessLauncher/Sources', 'CommandDee/Sources', 'MightyEdit/Source', 'PodiumAssist/Development/Sources/Toki', 'QuickIconExporter/Development/Sources/IconDrop', 'BrowserSwitcher/Source', 'FolderHopper/Development/Source', 'YohakuTrimmer/Development/Sources', 'KageTrimmer/Development/Sources'] + private_targets:
    target = root / relative / "WindowActivationPolicy.swift"
    if not target.parent.is_dir():
        continue
    if not target.exists() or target.read_bytes() != activation:
        target.write_bytes(activation)

about = Path(__file__).with_name("AboutSection.swift").read_bytes()
for relative in ['BrowserSwitcher/Source', 'CommandDee/Sources', 'ExtensionLinker/Development/Sources/DutiGUI', 'FolderHopper/Development/Source', 'KageTrimmer/Development/Sources', 'YohakuTrimmer/Development/Sources', 'QuickIconExporter/Development/Sources/IconDrop', 'PodiumAssist/Development/Sources/Toki', 'MightyEdit/Source', 'KakkoReplace/Sources', 'SpreadsheetHelper/Sources', 'KeynoteMaestro/Sources', 'PasteInARow/Sources', 'IncrementPaste/Sources', 'PasteMatchStyle/Sources', 'LinkMaker/Sources', 'ProjectFolder/Sources', 'DocklessLauncher/Sources', 'BundleIDInspector/Sources/BundleIDInspector', 'HotkeyHound/Sources/HotkeyHound', 'PrefsPreset/Sources/PrefsPreset', 'MarkdownKitchen/Sources/MarkdownKitchen', 'FileCaravan/Source'] + private_targets:
    target = root / relative / "AboutSection.swift"
    if not target.parent.is_dir():
        continue
    if not target.exists() or target.read_bytes() != about:
        target.write_bytes(about)

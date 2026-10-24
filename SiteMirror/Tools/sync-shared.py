"""Sync only SiteMirror's copies; leave other apps' working changes untouched."""
from pathlib import Path
app = Path(__file__).resolve().parents[1]
shared = app.parent / "Shared"
for relative in ['AppStandards/AboutSection.swift', 'AppStandards/AppSurface.swift', 'AppStandards/StartupWindow.swift', 'AppStandards/SettingsSection.swift', 'AppStandards/HelpDocument.swift', 'MenuBarPresence/MenuBarPresence.swift', 'LoginAtLaunch/LoginAtLaunch.swift', 'SettingsSync/SettingsSync.swift', 'Updater/UpdateSupport.swift', 'Notifications/NotificationPreferences.swift']:
    source = shared / relative
    target = app / "Sources/SiteMirror" / source.name
    if not target.exists() or target.read_bytes() != source.read_bytes():
        target.write_bytes(source.read_bytes())
        print("updated", target.name)

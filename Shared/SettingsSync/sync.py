from pathlib import Path
root = Path(__file__).resolve().parents[2]
source = (root / "Shared/SettingsSync/SettingsSync.swift").read_bytes()
# CarmaChameleon compiles ../Shared/SettingsSync/SettingsSync.swift directly.
for target in ['KakkoReplace/Sources', 'LinkMaker/Sources', 'DocklessLauncher/Sources']:
    path = root / target / "SettingsSync.swift"
    if not path.parent.is_dir():
        continue
    if not path.exists() or path.read_bytes() != source:
        path.write_bytes(source)

from pathlib import Path
root = Path(__file__).resolve().parents[2]
source = root / "Shared/Notifications/NotificationPreferences.swift"
target = root / "QuickIconExporter/Development/Sources/IconDrop/NotificationPreferences.swift"
if not target.exists() or target.read_bytes() != source.read_bytes():
    target.write_bytes(source.read_bytes())

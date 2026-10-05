#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
UPDATER_ROOT="$PWD/../../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
stage=$(mktemp -d /private/tmp/FolderHopper-build.XXXXXX)
trap 'rm -rf "$stage"' EXIT
bundle="$stage/FolderHopper.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp ../Assets/FolderHopper-Mustard.icns "$bundle/Contents/Resources/FolderHopper-Mustard.icns"
cp Info.plist "$bundle/Contents/Info.plist"
xcrun swiftc "${UPDATE_SWIFT_FLAGS[@]}" Source/UpdateSupport.swift -module-cache-path "$stage/module-cache" -target arm64-apple-macosx13.0 -swift-version 5 -O -framework AppKit -framework Carbon -framework ServiceManagement -framework UserNotifications Source/Localization.swift Source/LaunchPolicy.swift Source/GlobalShortcut.swift Source/History.swift Source/MoveEngine.swift Source/Browser.swift Source/main.swift -o "$bundle/Contents/MacOS/FolderMover"
cp -R Localizations/*.lproj "$bundle/Contents/Resources/"
embed_updates "$bundle"
xattr -cr "$bundle"
codesign --force --sign - "$bundle"
codesign --verify --deep --strict "$bundle"
python3 ../../Shared/BuildTools/publish_latest.py "$bundle"
backup="../Backups/before-build-$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$backup"
if [[ -d ../FolderHopper.app ]]; then mv ../FolderHopper.app "$backup/"; fi
ditto "$bundle" ../FolderHopper.app
codesign --verify --deep --strict ../FolderHopper.app
printf 'Built and published: FolderHopper.app\n'

#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
python3 ../../Shared/MenuBarPresence/sync.py
python3 "../../Shared/AppStandards/sync-surface.py"
python3 check-localization.py
UPDATER_ROOT="$PWD/../../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
stage=$(mktemp -d /private/tmp/FolderHopper-build.XXXXXX)
trap 'rm -rf "$stage"' EXIT
bundle="$stage/FolderHopper.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp ../Assets/FolderHopper-Mustard.icns "$bundle/Contents/Resources/FolderHopper-Mustard.icns"
cp Info.plist "$bundle/Contents/Info.plist"
xcrun swiftc Source/AppSurface.swift Source/StartupWindow.swift Source/SettingsSection.swift Source/MenuBarPresence.swift "${UPDATE_SWIFT_FLAGS[@]}" Source/UpdateSupport.swift Source/AccessibilityPermission.swift Source/FolderAccess.swift -module-cache-path "$stage/module-cache" -target arm64-apple-macosx13.0 -swift-version 5 -O -framework AppKit -framework Carbon -framework ServiceManagement -framework UserNotifications Source/Localization.swift Source/LaunchPolicy.swift Source/GlobalShortcut.swift Source/History.swift Source/MoveEngine.swift Source/Browser.swift Source/HelpDocument.swift Source/LocalHelp.swift Source/AboutSection.swift Source/main.swift -o "$bundle/Contents/MacOS/FolderMover"
cp -R Localizations/*.lproj "$bundle/Contents/Resources/"
python3 check-localization.py "$bundle"
embed_updates "$bundle"
"$UPDATER_ROOT/../AppIcon/apply-app-icon.sh" "$bundle"
xattr -cr "$bundle"
if [[ "${APP_STORE_BUILD:-0}" == 1 ]]; then
    codesign --force --sign - --entitlements FolderHopper-AppStore.entitlements "$bundle"
else
    # A certificate-backed identity (team PL9S9PXX96) so Accessibility / Automation grants follow the app
    # rather than a changing ad-hoc hash (same as KakkoReplace / MightyEdit).
    SIGNING_IDENTITY="${FOLDERHOPPER_SIGNING_IDENTITY:-301A41C0A37B6B578B7477229015992E8AA34E44}"
    codesign --force --sign "$SIGNING_IDENTITY" --timestamp=none "$bundle"
fi
codesign --verify --deep --strict "$bundle"
if [[ "${APP_STORE_BUILD:-0}" == 1 ]]; then
    mkdir -p StoreBuild
    if [[ -d StoreBuild/FolderHopper.app ]]; then
        backup="../Backups/store-before-build-$(date +%Y%m%d-%H%M%S)-$$"
        mkdir -p "$backup"
        mv StoreBuild/FolderHopper.app "$backup/"
    fi
    ditto "$bundle" StoreBuild/FolderHopper.app
    codesign --verify --deep --strict StoreBuild/FolderHopper.app
    printf 'Built App Store candidate: StoreBuild/FolderHopper.app\n'
    exit 0
fi
python3 ../../Shared/BuildTools/publish_latest.py "$bundle"
backup="../Backups/before-build-$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$backup"
if [[ -d ../FolderHopper.app ]]; then mv ../FolderHopper.app "$backup/"; fi
ditto "$bundle" ../FolderHopper.app
codesign --verify --deep --strict ../FolderHopper.app
printf 'Built and published: FolderHopper.app\n'

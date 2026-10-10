#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
python3 ../../Shared/MenuBarPresence/sync.py
python3 "../../Shared/AppStandards/sync-surface.py"
UPDATER_ROOT="$PWD/../../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
STAGING=$(mktemp -d /private/tmp/podiumflight-build.XXXXXX)
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/PodiumFlight.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc Sources/Toki/AppSurface.swift Sources/Toki/StartupWindow.swift Sources/Toki/SettingsSection.swift Sources/Toki/MenuBarPresence.swift "${UPDATE_SWIFT_FLAGS[@]}" Sources/Toki/UpdateSupport.swift Sources/Toki/AccessibilityPermission.swift Sources/Toki/QuitApps.swift Sources/Toki/LaunchApps.swift -parse-as-library Sources/Toki/HelpDocument.swift Sources/Toki/LocalHelp.swift Sources/Toki/TokiApp.swift Sources/Toki/Localization.swift Sources/Toki/LoginAtLaunch.swift Sources/Toki/WindowActivationPolicy.swift Sources/Toki/AboutSection.swift -sdk "$(xcrun --sdk macosx --show-sdk-path)" -target "$(uname -m)-apple-macosx13.0" -module-cache-path "$STAGING/module-cache" -O -o "$APP/Contents/MacOS/Toki"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp ../Assets/Toki-Mustard.icns "$APP/Contents/Resources/Toki-Mustard.icns"
cp -R Localizations/*.lproj "$APP/Contents/Resources/"
python3 Tests/check-localization.py --app "$APP"
embed_updates "$APP"
"$UPDATER_ROOT/../AppIcon/apply-app-icon.sh" "$APP"
xattr -cr "$APP"
# A certificate-backed identity (team PL9S9PXX96) so Accessibility / Automation grants follow the app
# rather than a changing ad-hoc hash (same as KakkoReplace / MightyEdit).
SIGNING_IDENTITY="${PODIUMFLIGHT_SIGNING_IDENTITY:-301A41C0A37B6B578B7477229015992E8AA34E44}"
codesign --force --sign "$SIGNING_IDENTITY" --timestamp=none "$APP"
codesign --verify --deep --strict "$APP"
python3 ../../Shared/BuildTools/publish_latest.py "$APP"
backup="../Backups/before-build-$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$backup"
if [[ -d ../PodiumFlight.app ]]; then mv ../PodiumFlight.app "$backup/"; fi
ditto "$APP" ../PodiumFlight.app
codesign --verify --deep --strict ../PodiumFlight.app
printf 'Built and published: PodiumFlight.app\n'

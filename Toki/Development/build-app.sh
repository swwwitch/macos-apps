#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
UPDATER_ROOT="$PWD/../../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
STAGING=$(mktemp -d /private/tmp/podiumflight-build.XXXXXX)
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/PodiumFlight.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc "${UPDATE_SWIFT_FLAGS[@]}" Sources/Toki/UpdateSupport.swift -parse-as-library Sources/Toki/TokiApp.swift Sources/Toki/Localization.swift Sources/Toki/LoginAtLaunch.swift -sdk "$(xcrun --sdk macosx --show-sdk-path)" -target "$(uname -m)-apple-macosx13.0" -module-cache-path "$STAGING/module-cache" -O -o "$APP/Contents/MacOS/Toki"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp ../Assets/Toki-Mustard.icns "$APP/Contents/Resources/Toki-Mustard.icns"
cp -R Localizations/*.lproj "$APP/Contents/Resources/"
embed_updates "$APP"
xattr -cr "$APP"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
python3 ../../Shared/BuildTools/publish_latest.py "$APP"
backup="../Backups/before-build-$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$backup"
if [[ -d ../PodiumFlight.app ]]; then mv ../PodiumFlight.app "$backup/"; fi
ditto "$APP" ../PodiumFlight.app
codesign --verify --deep --strict ../PodiumFlight.app
printf 'Built and published: PodiumFlight.app\n'

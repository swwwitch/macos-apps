#!/bin/zsh
set -eu
cd "${0:A:h}"
python3 ../Shared/AppStandards/sync-surface.py
STAGING=$(mktemp -d "${TMPDIR:-/tmp/}superkakko.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/KakkoReplace.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc -O -target "$(uname -m)-apple-macos13.0" -module-cache-path "$STAGING/ModuleCache" -framework AppKit -framework SwiftUI -framework ApplicationServices -framework Carbon -framework ServiceManagement Sources/AppSurface.swift Sources/StartupWindow.swift Sources/HelpDocument.swift Sources/SettingsSection.swift Sources/AccessibilityPermission.swift Sources/LaunchPolicy.swift Sources/Transform.swift Sources/Editor.swift Sources/HotKey.swift Sources/Palette.swift Sources/OperationPicker.swift Sources/main.swift -o "$APP/Contents/MacOS/KakkoReplace"
cp Info.plist "$APP/Contents/Info.plist"
cp -R Resources/. "$APP/Contents/Resources/"
if [[ ! -f Assets/KakkoReplace.icns || Assets/draw-icon.swift -nt Assets/KakkoReplace.icns || Assets/package-icon.py -nt Assets/KakkoReplace.icns ]]; then
    xcrun swift -module-cache-path "$STAGING/ModuleCache" Assets/draw-icon.swift Assets/KakkoReplace.png
    python3 Assets/package-icon.py
fi
cp Assets/KakkoReplace.icns "$APP/Contents/Resources/"
xattr -cr "$APP"
codesign --force --sign "${SUPERKAKKOREPLACE_SIGNING_IDENTITY:-${SUPERKAKKOEDIT_SIGNING_IDENTITY:--}}" --timestamp=none "$APP"
codesign --verify --deep --strict "$APP"
if [[ -e KakkoReplace.app ]]; then
    mkdir -p Backups
    mv KakkoReplace.app "Backups/KakkoReplace-$(date +%Y%m%d-%H%M%S)-$$.app"
fi
ditto "$APP" KakkoReplace.app
printf '%s\n' "$PWD/KakkoReplace.app"

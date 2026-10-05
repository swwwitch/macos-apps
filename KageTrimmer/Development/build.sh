#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h}"
UPDATER_ROOT="$ROOT/../../Shared/Updater"
source "$UPDATER_ROOT/build-support.sh"
BUILD=$(mktemp -d /private/tmp/kagetrimmer-build.XXXXXX)
trap 'rm -rf "$BUILD"' EXIT
APP="$BUILD/KageTrimmer.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc "${UPDATE_SWIFT_FLAGS[@]}" "$ROOT/Sources/UpdateSupport.swift" -parse-as-library -O -target arm64-apple-macos14.0 \
  -module-cache-path "$BUILD/ModuleCache" \
  -framework Carbon -framework AppKit -framework CoreImage -framework ImageIO -framework UniformTypeIdentifiers \
  "$ROOT/Sources/SoftShadowApp.swift" "$ROOT/Sources/ShadowProcessor.swift" "$ROOT/Sources/Localization.swift" "$ROOT/Sources/LoginAtLaunch.swift" \
  -o "$APP/Contents/MacOS/KageTrimmer"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 28" "$APP/Contents/Info.plist"
cp "$ROOT/PkgInfo" "$APP/Contents/PkgInfo"
cp "$ROOT/Resources/AppIcon-source.png" "$APP/Contents/Resources/AppIcon.png"
cp "$ROOT/Resources/KageTrimmer-Mustard.icns" "$APP/Contents/Resources/KageTrimmer-Mustard.icns"
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile KageTrimmer-Mustard" "$APP/Contents/Info.plist"
cp -R "$ROOT/Localizations/"*.lproj "$APP/Contents/Resources/"
embed_updates "$APP"
xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
python3 "$ROOT/../../Shared/BuildTools/publish_latest.py" "$APP"
mkdir -p "$ROOT/build"
ditto --norsrc --noextattr "$APP" "$ROOT/build/KageTrimmer.app"
xattr -cr "$ROOT/build/KageTrimmer.app"
codesign --verify --deep --strict "$ROOT/build/KageTrimmer.app"
echo "$ROOT/build/KageTrimmer.app"

#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/../.."
stage=$(mktemp -d /private/tmp/Carma-StoreSmoke.XXXXXX)
trap 'rm -rf "$stage"' EXIT
app="$stage/CarmaStoreSmoke.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/bin"
cp Vendor/{pandoc,typst} "$app/Contents/Resources/bin/"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0"?><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>jp.local.CarmaStoreSmoke</string><key>CFBundleExecutable</key><string>CarmaStoreSmoke</string><key>CFBundlePackageType</key><string>APPL</string></dict></plist>
PLIST
xcrun swiftc -D APP_STORE -module-cache-path "$stage/cache" -framework PDFKit Source/StoreFolderAccess.swift Tests/StoreSandbox/main.swift -o "$app/Contents/MacOS/CarmaStoreSmoke"
identity=7A1E563ACDF18A58946DC4305A27467A63B24318
for tool in pandoc typst; do codesign --force --sign "$identity" --options runtime --timestamp --entitlements Store/Helper.entitlements "$app/Contents/Resources/bin/$tool"; done
codesign --force --sign "$identity" --options runtime --timestamp --entitlements Store/App.entitlements "$app"
codesign --verify --deep --strict "$app"
"$app/Contents/MacOS/CarmaStoreSmoke"

#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/CarmaChameleon-test.XXXXXX)
trap 'rm -rf "$stage"' EXIT
xcrun swiftc -swift-version 5 -module-cache-path "$stage/cache" -framework Vision -framework PDFKit -framework AppKit -framework SwiftUI -framework Carbon ../Shared/KeynoteExport/KeynoteExport.swift Source/PDFImporter.swift Source/IDMLExporter.swift Source/IDMLImporter.swift Source/HTMLFormatting.swift Source/MarkdownToText.swift Source/XLSXImporter.swift Source/AIImporter.swift Source/IllustratorBridge.swift Source/Conversion.swift Source/ImageExport.swift Source/ImageConversion.swift Source/SRTConverter.swift Tests/main.swift -o "$stage/tests"
osacompile -o "$stage/Keynote.scpt" ../Shared/KeynoteExport/Keynote.applescript
export PANDOCDESK_KEYNOTE_SCRIPT="$stage/Keynote.scpt"
if [[ -n "${1:-}" ]]; then
  "$stage/tests" "$PWD/Vendor/pandoc" "$1" "$PWD/Tests/PDFOutput"
else
  "$stage/tests" "$PWD/Vendor/pandoc"
  print "PDF test skipped: supply the Typst executable path as argument."
fi
python3 - <<'PY'
import re,pathlib
root=pathlib.Path('.')
keys=set()
for p in (root/'Source').glob('*.swift'): keys.update(re.findall(r'L\("([^"\\]+)"\)',p.read_text()))
sets=[]
for p in (root/'Resources').glob('*.lproj/Localizable.strings'):
 data=p.read_text(); present=set(re.findall(r'^"([^"]+)"\s*=',data,re.M));sets.append(present)
 assert keys <= present, (p,keys-present)
assert all(s==sets[0] for s in sets)
print('PASS: localization key parity and literal UI keys')
PY
Tests/markdown2text/run.sh

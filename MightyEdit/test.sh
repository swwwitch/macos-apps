#!/bin/zsh
# Runs every MightyEdit unit test plus the localization check (B15/B16).
# Usage: zsh test.sh [path/to/MightyEdit.app]   (the optional app is checked for .lproj and CFBundleLocalizations)
set -u
cd "${0:A:h}"
OUT=$(mktemp -d "${TMPDIR:-/tmp/}mightyedit-tests.XXXXXX")
trap 'rm -rf "$OUT"' EXIT
# UI text goes through L(); test binaries have no bundle and use the generated Japanese table.
LOCALIZATION=(Source/Localization.swift Source/LocalizationFallback.swift)
TRANSFORMS=(Source/LineTools.swift Source/HTMLMinifier.swift Source/TextTransform.swift Source/TypographyOption.swift Source/DateTransform.swift)
typeset -A deps
deps[ContinuationSelectionTests]="Source/ContinuationSelection.swift"
deps[TextTransformTests]="${TRANSFORMS[*]}"
deps[HTMLBeautifierTests]="${TRANSFORMS[*]}"
deps[HTMLMinifierTests]="Source/HTMLMinifier.swift"
deps[LineToolsTests]="Source/LineTools.swift"
deps[ExcludedAppsTests]="Source/ExcludedAppList.swift"
deps[HotkeyScopeTests]="Source/HotkeyScope.swift"
deps[HotkeyReleaseGateTests]="Source/HotkeyReleaseGate.swift"
deps[PaletteTargetSessionTests]="Source/PaletteTargetSession.swift"
deps[GridLayoutTests]="Source/PaletteButton.swift Source/ResponsiveButtonGrid.swift"
python3 make-resources.py >/dev/null || exit 1
fail=0
for name in ${(ko)deps}; do
    if ! xcrun swiftc -parse-as-library ${=deps[$name]} ${LOCALIZATION[@]} Tests/$name.swift -o "$OUT/$name" 2>"$OUT/$name.log"; then
        print "FAIL (compile) $name"; head -20 "$OUT/$name.log"; fail=1; continue
    fi
    if "$OUT/$name" >"$OUT/$name.out" 2>&1; then print "PASS $name"; else print "FAIL $name"; tail -5 "$OUT/$name.out"; fail=1; fi
done
if python3 Tests/check-localization.py "$@"; then print "PASS check-localization"; else print "FAIL check-localization"; fail=1; fi
exit $fail

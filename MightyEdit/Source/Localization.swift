import Foundation

// UI labels only (B15). Text inserted into the user's document — list markers, 「合計：」,
// dates, typography rules — stays literal in the transform code and is never passed through L().
// Keys and translations live in make-resources.py; Resources/<lang>.lproj is generated from it.

private let missingMarker = "\u{1}MightyEditMissingKey"

/// Localized UI text. Falls back to the generated Japanese table when the key is absent from
/// the bundle (unit-test binaries have no Localizable.strings), so Japanese output never changes.
func L(_ key: String) -> String {
    let value = Bundle.main.localizedString(forKey: key, value: missingMarker, table: nil)
    return value == missingMarker ? (LocalizationFallback.japanese[key] ?? key) : value
}

/// Localized format string with arguments. Translations use positional %1$@ / %2$@ when needed.
func L(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: L(key), arguments: arguments)
}

import Foundation

/// Resolve UI strings using macOS preferred languages for this app.
func L(_ key: String, _ arguments: CVarArg...) -> String {
    let format = Bundle.main.localizedString(forKey: key, value: key, table: "Localizable")
    return arguments.isEmpty ? format : String(format: format, locale: Locale.current, arguments: arguments)
}

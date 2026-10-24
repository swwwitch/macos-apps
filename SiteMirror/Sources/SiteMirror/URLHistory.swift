import Foundation

/// Local to this Mac, separate from the editable URL and synchronized download settings.
struct URLHistory {
    static let key = "recentURLs"
    static let limit = 20
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, previousURL: URL? = nil) {
        self.defaults = defaults
        // Seed the upgrade once; an explicitly cleared history must stay empty.
        if defaults.object(forKey: Self.key) == nil {
            defaults.set(previousURL.flatMap(Self.entry).map { [$0] } ?? [], forKey: Self.key)
        }
    }

    var entries: [String] { defaults.stringArray(forKey: Self.key) ?? [] }

    func record(_ url: URL) {
        guard let entry = Self.entry(url) else { return }
        defaults.set(Array(([entry] + entries.filter { $0 != entry }).prefix(Self.limit)), forKey: Self.key)
    }

    func clear() { defaults.set([String](), forKey: Self.key) }

    private static func entry(_ url: URL) -> String? {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = parts.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil else { return nil }
        parts.scheme = scheme
        parts.host = host.lowercased()
        parts.fragment = nil
        if parts.path.isEmpty { parts.path = "/" }
        return parts.url?.absoluteString
    }
}

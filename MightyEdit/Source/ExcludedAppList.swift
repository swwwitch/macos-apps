import Foundation

/// Bundle IDs of apps MightyEdit never acts on (B21). Foundation-only for ExcludedAppsTests.
struct ExcludedAppList {
    static let key = "excludedBundleIDs"
    enum AddResult: Equatable { case added, duplicate, own, invalid }
    let ownID: String?
    private(set) var ids: [String]

    init(ownID: String?, defaults: UserDefaults = .standard) {
        self.ownID = ownID
        ids = defaults.stringArray(forKey: Self.key) ?? []
    }
    /// Bundle IDs compare case-insensitively, as Launch Services does.
    private static func same(_ a: String?, _ b: String) -> Bool { a?.caseInsensitiveCompare(b) == .orderedSame }
    func excludes(_ bundleID: String?) -> Bool { ids.contains { Self.same(bundleID, $0) } }

    mutating func add(_ id: String?) -> AddResult {
        guard let id = id?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else { return .invalid }
        if let ownID, Self.same(id, ownID) { return .own }
        guard !excludes(id) else { return .duplicate }
        ids.append(id)
        return .added
    }
    mutating func remove(_ id: String) { ids.removeAll { Self.same(id, $0) } }
    func save(_ defaults: UserDefaults = .standard) { defaults.set(ids, forKey: Self.key) }

    /// Global hotkeys stay unregistered while the front app is excluded or MightyEdit itself,
    /// so the keystroke reaches that app. An unknown front app (nil) keeps them registered.
    func blocksHotkeys(bundleID: String?, pid: Int32?, ownPID: Int32) -> Bool {
        if let pid, pid == ownPID { return true }
        if let ownID, Self.same(bundleID, ownID) { return true }
        return excludes(bundleID)
    }
}

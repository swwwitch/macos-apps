import Foundation
import Combine

/// Each app/key label is an independent preference, so edits to different labels can merge.
@MainActor
final class CustomSettingLabels: ObservableObject {
    static let prefix = "courierLabel.v1."
    private static let migrationKey = "courierLabelLocalMigrationV1"
    static let shared = CustomSettingLabels(file: FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/SettingsCourier/SettingLabels.json"))
    @Published private(set) var revision = 0
    private let defaults: UserDefaults
    private var loadError: Error?

    init(file: URL, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard !defaults.bool(forKey: Self.migrationKey) else { return }
        do {
            if FileManager.default.fileExists(atPath: file.path) {
                let old = try JSONDecoder().decode([String: [String: String]].self, from: Data(contentsOf: file))
                for (app, labels) in old {
                    for (key, title) in labels {
                        let storageKey = Self.storageKey(bundleID: app, key: key)
                        // Existing synced values (including deletion markers) take precedence.
                        if defaults.object(forKey: storageKey) == nil { defaults.set(title, forKey: storageKey) }
                    }
                }
            }
            defaults.set(true, forKey: Self.migrationKey)
            // Keep the old JSON intact as a backup; never import it again after migration.
        } catch { loadError = error }
    }

    static func storageKey(bundleID: String, key: String) -> String {
        // Length-independent encoding prevents collisions when identifiers contain separators.
        prefix + Data(bundleID.utf8).base64EncodedString() + "." + Data(key.utf8).base64EncodedString()
    }

    func title(bundleID: String, key: String) -> String? {
        guard let title = defaults.string(forKey: Self.storageKey(bundleID: bundleID, key: key)), !title.isEmpty else { return nil }
        return title
    }

    /// Sync/import changes UserDefaults first, then calls this to refresh the table.
    func reload() { revision += 1 }

    func save(_ title: String, bundleID: String, key: String) throws {
        if let loadError { throw loadError }
        // An empty string is an explicit reset, and participates in per-key sync conflict resolution.
        defaults.set(title.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Self.storageKey(bundleID: bundleID, key: key))
        reload()
    }
}

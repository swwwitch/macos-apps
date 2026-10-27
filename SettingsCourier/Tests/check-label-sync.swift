import Foundation

@main enum LabelSyncChecks {
    @MainActor static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let suites = (0..<3).map { _ in "CourierLabelTest-" + UUID().uuidString }
        let prefs = suites.map { UserDefaults(suiteName: $0)! }
        defer { for (i, name) in suites.enumerated() { prefs[i].removePersistentDomain(forName: name) } }
        let old = root.appendingPathComponent("labels.json")
        let original = try JSONEncoder().encode(["app.a": ["矢印": "Arrow", "reset": "Old"]])
        try original.write(to: old)
        let resetKey = CustomSettingLabels.storageKey(bundleID: "app.a", key: "reset")
        prefs[0].set("", forKey: resetKey)
        let a = CustomSettingLabels(file: old, defaults: prefs[0])
        assert(a.title(bundleID: "app.a", key: "矢印") == "Arrow")
        assert(a.title(bundleID: "app.a", key: "reset") == nil)
        try a.save("", bundleID: "app.a", key: "矢印")
        let restarted = CustomSettingLabels(file: old, defaults: prefs[0])
        assert(restarted.title(bundleID: "app.a", key: "矢印") == nil)
        let preserved = try Data(contentsOf: old)
        assert(preserved == original)
        let b = CustomSettingLabels(file: root.appendingPathComponent("missing.json"), defaults: prefs[1])
        let keyA = CustomSettingLabels.storageKey(bundleID: "app.a", key: "same.key")
        let keyB = CustomSettingLabels.storageKey(bundleID: "app.b", key: "same.key")
        assert(keyA != keyB)
        try a.save("Alpha", bundleID: "app.a", key: "same.key")
        try b.save("Beta", bundleID: "app.b", key: "same.key")
        let journal = root.appendingPathComponent("sync")
        try SettingsSyncJournal.append(journal, app: "SettingsCourier", device: "A", revision: 1, values: [keyA: "Alpha"], deleted: [])
        try SettingsSyncJournal.append(journal, app: "SettingsCourier", device: "B", revision: 1, values: [keyB: "Beta"], deleted: [])
        let merged = try SettingsSyncJournal.read(journal, app: "SettingsCourier")
        assert(merged.values[keyA] as? String == "Alpha" && merged.values[keyB] as? String == "Beta")
        for (key, value) in merged.values { prefs[1].set(value, forKey: key as! String) }
        b.reload()
        assert(b.title(bundleID: "app.a", key: "same.key") == "Alpha")
        try SettingsSyncJournal.append(journal, app: "SettingsCourier", device: "A", revision: 2, values: [keyA: ""], deleted: [])
        let reset = try SettingsSyncJournal.read(journal, app: "SettingsCourier")
        for (key, value) in reset.values { prefs[1].set(value, forKey: key as! String) }
        b.reload()
        assert(b.title(bundleID: "app.a", key: "same.key") == nil)
        assert(b.title(bundleID: "app.b", key: "same.key") == "Beta")
        let exported = prefs[1].dictionaryRepresentation().filter { $0.key.hasPrefix(CustomSettingLabels.prefix) }
        let data = try PropertyListSerialization.data(fromPropertyList: exported, format: .xml, options: 0)
        let imported = try PropertyListSerialization.propertyList(from: data, format: nil) as! [String: Any]
        assert(imported[keyB] as? String == "Beta")
        assert(imported[keyA] as? String == "")
        let corrupt = root.appendingPathComponent("bad.json")
        try Data("invalid".utf8).write(to: corrupt)
        do {
            try CustomSettingLabels(file: corrupt, defaults: prefs[2]).save("new", bundleID: "a", key: "k")
            fatalError("Must preserve corrupt migration input")
        } catch {}
        print("PASS: migration/backup, no resurrection, app/key isolation, concurrent different-label merge, remote reload/reset, plist export round trip, corrupt legacy protection")
    }
}

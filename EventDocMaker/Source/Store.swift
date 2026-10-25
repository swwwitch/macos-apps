import Foundation

/// One event's input. Saved as JSON: event.json in the event's folder, or EventDoc/EventData/<id>.json
/// while that folder does not exist yet (making the documents creates it and the file moves there).
struct EventRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    var values: [String: String] = [:]
    var modified = Date()

    static let fileName = "event.json"
    subscript(_ key: String) -> String { values[key] ?? "" }
    var number: Int? { Int(self["#"]) }
    private static func usable(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "-" || trimmed == "0" ? nil : trimmed
    }
    /// <category without spaces, lowercase>-<仮の日付>-<タイトル（abc）>, as the documents use; nil until all three are set.
    var folderName: String? {
        guard let category = Self.usable(self["種別"]), let date = Self.usable(self["仮の日付"]), let title = Self.usable(self["タイトル（abc）"]) else { return nil }
        return category.lowercased().replacingOccurrences(of: " ", with: "") + "-" + date + "-" + title
    }
    var displayName: String { Self.usable(self["イベント名"]) ?? Self.usable(self["フォルダー名"]) ?? L("untitled") }
}

struct StoredEvent: Identifiable {
    var record: EventRecord
    var url: URL?
    var id: UUID { record.id }
}

struct EventStore {
    let places: Locations
    var dataFolder: URL { URL(fileURLWithPath: places.eventDoc).appendingPathComponent("EventData") }
    private var fm: FileManager { .default }

    static func decode(_ url: URL) -> EventRecord? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(EventRecord.self, from: data)
    }

    /// Every saved event: event.json in the folders under the parent folder, and the files in EventData.
    func load() -> [StoredEvent] {
        var found: [UUID: StoredEvent] = [:]
        let root = URL(fileURLWithPath: places.root)
        for name in (try? fm.contentsOfDirectory(atPath: root.path)) ?? [] where !name.hasPrefix(".") {
            let file = root.appendingPathComponent(name).appendingPathComponent(EventRecord.fileName)
            if fm.fileExists(atPath: file.path), let record = Self.decode(file) { found[record.id] = StoredEvent(record: record, url: file) }
        }
        for name in (try? fm.contentsOfDirectory(atPath: dataFolder.path)) ?? [] where name.hasSuffix(".json") {
            let file = dataFolder.appendingPathComponent(name)
            // A copy in an event folder wins over a leftover in EventData.
            if let record = Self.decode(file), found[record.id] == nil { found[record.id] = StoredEvent(record: record, url: file) }
        }
        return Array(found.values)
    }

    /// The event folder's event.json when that folder exists and the file is not another event's; otherwise EventData.
    func target(for record: EventRecord) -> URL {
        if let name = record.folderName {
            let folder = URL(fileURLWithPath: places.root).appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            if fm.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue {
                let file = folder.appendingPathComponent(EventRecord.fileName)
                if !fm.fileExists(atPath: file.path) || Self.decode(file)?.id == record.id { return file }
            }
        }
        return dataFolder.appendingPathComponent(record.id.uuidString + ".json")
    }

    /// Writes the event where it belongs and removes the file it was in before, if that moved. Returns the new location.
    @discardableResult
    func save(_ record: EventRecord, replacing old: URL?) throws -> URL {
        let file = target(for: record)
        try fm.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]; encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(record).write(to: file, options: .atomic)
        if let old, old.standardizedFileURL != file.standardizedFileURL, Self.decode(old)?.id == record.id { try? fm.removeItem(at: old) }
        return file
    }

    /// Moves the event's file to the Trash. Folders and documents stay.
    func delete(_ event: StoredEvent) throws {
        guard let url = event.url, fm.fileExists(atPath: url.path) else { return }
        try fm.trashItem(at: url, resultingItemURL: nil)
    }
}

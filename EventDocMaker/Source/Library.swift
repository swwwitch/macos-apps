import AppKit

/// The events, the selection and saving. Edits are saved shortly after typing stops.
@MainActor final class Library: ObservableObject {
    @Published private(set) var events: [StoredEvent] = []
    @Published var selection: UUID? { didSet { UserDefaults.standard.set(selection?.uuidString, forKey: "selectedEvent") } }
    @Published var search = ""
    @Published var saveError = ""
    var places: () -> Locations
    private var pending: [UUID: DispatchWorkItem] = [:]

    init(places: @escaping () -> Locations) {
        self.places = places
        selection = UserDefaults.standard.string(forKey: "selectedEvent").flatMap(UUID.init(uuidString:))
    }
    var store: EventStore { EventStore(places: places()) }

    func reload() {
        flush()
        events = store.load()
        if let selection, !events.contains(where: { $0.id == selection }) { self.selection = nil }
        if selection == nil { selection = sorted.first?.id }
    }

    /// Newest 仮の日付 first, then the highest #.
    var sorted: [StoredEvent] {
        events.sorted { a, b in
            let da = a.record["仮の日付"], db = b.record["仮の日付"]
            if da != db { return da > db }
            return (a.record.number ?? 0) > (b.record.number ?? 0)
        }
    }
    var filtered: [StoredEvent] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return sorted }
        return sorted.filter { event in
            ["#", "イベント名", "フォルダー名", "タイトル（abc）", "出演者名（1人目）", "種別", "仮の日付"].contains { event.record[$0].localizedCaseInsensitiveContains(query) }
        }
    }
    var current: EventRecord? { events.first { $0.id == selection }?.record }

    func value(_ key: String) -> String { current?[key] ?? "" }
    func setValue(_ key: String, _ value: String) {
        guard let index = events.firstIndex(where: { $0.id == selection }) else { return }
        guard events[index].record.values[key] ?? "" != value else { return }
        events[index].record.values[key] = value.isEmpty ? nil : value
        events[index].record.modified = Date()
        scheduleSave(events[index].id)
    }
    private func scheduleSave(_ id: UUID) {
        pending[id]?.cancel()
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.save(id) } }
        pending[id] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }
    func save(_ id: UUID) {
        pending[id]?.cancel(); pending[id] = nil
        guard let index = events.firstIndex(where: { $0.id == id }) else { return }
        do {
            events[index].url = try store.save(events[index].record, replacing: events[index].url)
            saveError = ""
        } catch {
            saveError = String(format: L("saveFailed"), error.localizedDescription)
        }
    }
    /// Saves everything still waiting (before quitting, reloading or making documents).
    func flush() { for id in Array(pending.keys) { save(id) } }

    func newEvent() {
        var record = EventRecord()
        record.values["#"] = String((events.compactMap(\.record.number).max() ?? 0) + 1)
        events.append(StoredEvent(record: record, url: nil))
        selection = record.id
        save(record.id)
    }
    func duplicate() {
        guard let current else { return }
        var record = EventRecord()
        record.values = current.values
        record.values["#"] = String((events.compactMap(\.record.number).max() ?? 0) + 1)
        for key in ["仮の日付", "日付（Doorkeeper）"] { record.values[key] = nil }
        for field in Schema.fields where field.tab == .after { record.values[field.key] = nil }
        events.append(StoredEvent(record: record, url: nil))
        selection = record.id
        save(record.id)
    }
    func deleteCurrent() {
        guard let event = events.first(where: { $0.id == selection }) else { return }
        let alert = NSAlert()
        alert.messageText = String(format: L("deleteConfirm"), event.record.displayName)
        alert.informativeText = L("deleteConfirmDetail")
        alert.addButton(withTitle: L("delete"))
        alert.addButton(withTitle: L("cancel")).keyEquivalent = "\u{1b}"
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        pending[event.id]?.cancel(); pending[event.id] = nil
        do { try store.delete(event) } catch { saveError = error.localizedDescription; return }
        events.removeAll { $0.id == event.id }
        selection = sorted.first?.id
    }
    /// Fills the selected event from rows copied from a sheet ("label<TAB>value"). Returns how many fields were filled.
    func fillFromSheet(_ text: String) -> Int {
        let fields = EventFields.parse(text)
        var count = 0
        for field in Schema.fields where field.key != "#" {
            // A repeated label (CSS Nite ads) can only be told apart by its own key.
            let label = field.occurrence == 1 ? field.excelLabel.trimmingCharacters(in: .whitespaces) : field.key
            guard let raw = fields[label] else { continue }
            setValue(field.key, raw == "-" ? "" : raw); count += 1
        }
        return count
    }

    /// Adds the sheet's events that are not here yet (by #); with `overwrite`, also replaces the values of those that are.
    func importSheet(_ rows: [[String: String]], overwrite: Bool) -> (added: Int, updated: Int, skipped: Int) {
        var added = 0, updated = 0, skipped = 0
        for values in rows {
            let cleaned = values.filter { !$0.value.isEmpty }
            if let index = events.firstIndex(where: { $0.record["#"] == values["#"] }) {
                guard overwrite else { skipped += 1; continue }
                events[index].record.values = cleaned; events[index].record.modified = Date()
                save(events[index].id); updated += 1
            } else {
                var record = EventRecord(); record.values = cleaned
                events.append(StoredEvent(record: record, url: nil))
                save(record.id); added += 1
            }
        }
        if selection == nil { selection = sorted.first?.id }
        return (added, updated, skipped)
    }
}

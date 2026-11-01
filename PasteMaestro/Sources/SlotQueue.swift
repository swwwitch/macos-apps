import Foundation

struct SlotItem: Equatable, Identifiable {
    let id: UUID
    var text: String
    var starred: Bool
    init(id: UUID = UUID(), text: String, starred: Bool = false) {
        self.id = id; self.text = text; self.starred = starred
    }
}

/// Stable identities keep equal text, selection and retained rows distinct after moving.
struct SlotQueue {
    private(set) var items: [SlotItem] = []
    private(set) var cursor = 0
    private var history: [SlotItem] = []
    var nextIndex: Int? { items.isEmpty ? nil : min(cursor, items.count - 1) }
    var canRestart: Bool { !history.isEmpty && items != history }
    mutating func append(_ lines: [String]) {
        guard !lines.isEmpty else { return }
        if items.isEmpty { history = []; cursor = 0 }
        let added = lines.map { SlotItem(text: $0) }
        let next = nextIndex.map { items[$0] }
        let insertion = items.firstIndex(where: \.starred) ?? items.count
        let anchor = insertion < items.count ? items[insertion].id : nil
        items.insert(contentsOf: added, at: insertion)
        let historyInsertion = anchor.flatMap { id in history.firstIndex { $0.id == id } } ?? history.count
        history.insert(contentsOf: added, at: historyInsertion)
        if let next, !next.starred, let index = items.firstIndex(where: { $0.id == next.id }) { cursor = index }
        else { cursor = insertion }
    }
    mutating func toggleStar(_ index: Int) {
        guard items.indices.contains(index) else { return }
        items[index].starred.toggle()
        if let h = history.firstIndex(where: { $0.id == items[index].id }) { history[h].starred = items[index].starred }
    }
    @discardableResult mutating func move(id: UUID, before anchor: UUID?) -> Bool {
        guard id != anchor, let source = items.firstIndex(where: { $0.id == id }),
              anchor == nil || items.contains(where: { $0.id == anchor }) else { return false }
        let old = items
        let item = items.remove(at: source)
        let target = anchor.flatMap { id in items.firstIndex { $0.id == id } } ?? items.count
        items.insert(item, at: target)
        guard items != old else { return false }
        if let index = history.firstIndex(where: { $0.id == id }) {
            let historical = history.remove(at: index)
            let target = anchor.flatMap { id in history.firstIndex { $0.id == id } } ?? history.count
            history.insert(historical, at: target)
        }
        cursor = 0
        return true
    }
    mutating func consumeNext() {
        guard let index = nextIndex else { return }
        if items[index].starred { cursor = index + 1; if cursor >= items.count { cursor = 0 } }
        else { items.remove(at: index); cursor = index < items.count ? index : 0 }
    }
    mutating func consume(id: UUID, keep: Bool) {
        guard let index = items.firstIndex(where: { $0.id == id }), !keep, !items[index].starred else { return }
        items.remove(at: index)
        if index < cursor { cursor -= 1 }
        if cursor >= items.count { cursor = 0 }
    }
    mutating func clear() { items.removeAll { !$0.starred }; cursor = 0 }
    @discardableResult mutating func restart() -> Bool {
        guard canRestart else { return false }
        items = history; cursor = 0; return true
    }
}

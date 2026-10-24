import Foundation

@main
struct URLHistoryTests {
    static func main() {
        let suite = "SiteMirror-history-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let initial = URL(string: "https://example.com/old")!
        let history = URLHistory(defaults: defaults, previousURL: initial)
        precondition(history.entries == [initial.absoluteString])
        history.record(URL(string: "https://EXAMPLE.com/new#section")!)
        history.record(initial)
        precondition(history.entries == [initial.absoluteString, "https://example.com/new"])
        history.record(URL(string: "https://user:password@example.com/")!)
        history.record(URL(string: "file:///tmp/example")!)
        precondition(history.entries.count == 2)
        for n in 0..<25 { history.record(URL(string: "https://example.com/\(n)?page=2")!) }
        precondition(history.entries.count == 20)
        precondition(history.entries.first == "https://example.com/24?page=2")
        let restored = URLHistory(defaults: UserDefaults(suiteName: suite)!, previousURL: initial)
        precondition(restored.entries == history.entries)
        restored.clear()
        precondition(URLHistory(defaults: defaults, previousURL: initial).entries.isEmpty)
        print("PASS URL history: migration, ordering, deduplication, credentials, limit, persistence, clear")
    }
}

import Foundation

struct SettingsSearchEntry: Identifiable {
    var id: String
    var title: String
    var keywords: String
    var tab: Int
    var anchor: String
}
enum SettingsSearchIndex {
    static func matches(_ query: String, in entries: [SettingsSearchEntry]) -> [SettingsSearchEntry] {
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return [] }
        return entries.filter { entry in words.allSatisfy { (entry.title + " " + entry.keywords).localizedStandardContains($0) } }
    }
}

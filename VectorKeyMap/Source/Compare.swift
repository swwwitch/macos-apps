import Foundation

/// Name table entry from Data/Commands.tsv.
struct CommandName {
    let group: String
    let japanese: String
    let english: String
}

enum CommandTable {
    /// kind, ID, group, Japanese name, English name
    static func parse(_ text: String) -> (names: [CommandKey: CommandName], order: [CommandKey: Int]) {
        var names: [CommandKey: CommandName] = [:]
        var order: [CommandKey: Int] = [:]
        // No trimming: a trailing space is part of the ID, and a line may end in an empty English name.
        for (index, line) in text.components(separatedBy: "\n").enumerated() {
            let columns = line.components(separatedBy: "\t")
            guard columns.count == 5, let kind = CommandKind(rawValue: columns[0]) else { continue }
            let key = CommandKey(kind: kind, id: columns[1])
            names[key] = CommandName(group: columns[2], japanese: columns[3], english: columns[4])
            order[key] = index
        }
        return (names, order)
    }
}

enum DiffStatus: Int, CaseIterable {
    case changed, added, removed, unlisted, same, unassigned
}

struct Row: Identifiable, Hashable {
    let key: CommandKey
    let group: String
    let groupRank: Int
    let order: Int
    /// Japanese or English name, or nil when the table does not know the ID.
    let name: String?
    let baseline: Shortcut?
    let target: Shortcut?
    let status: DiffStatus
    /// Other commands that have the same key in the compared set.
    var conflicts: [String] = []

    var id: CommandKey { key }
    var displayName: String { name ?? key.id }
    var statusRank: Int { status.rawValue }
    var commandID: String { key.id }
    var baselineSort: String { baseline?.sortKey ?? "~" }
    var targetSort: String { target?.sortKey ?? "~" }
    var hasConflict: Bool { !conflicts.isEmpty }
}

enum Compare {
    static let groups = ["ツール", "Illustrator", "ファイル", "編集", "オブジェクト", "書式", "選択", "効果", "表示", "ウィンドウ", "ヘルプ",
                         "その他の選択", "その他のテキスト", "その他のオブジェクト", "その他のパネル", "その他"]
    static let unknownGroup = "未分類"

    static func rows(baseline: KeySet, target: KeySet, names: [CommandKey: CommandName], order: [CommandKey: Int], japanese: Bool) -> [Row] {
        var seen = Set<CommandKey>()
        let keys = (baseline.order + target.order).filter { seen.insert($0).inserted }
        var rows = keys.enumerated().map { index, key -> Row in
            let name = names[key]
            let base = baseline.entries[key] ?? nil
            let next = target.entries[key] ?? nil
            let inTarget = target.entries[key] != nil
            let group = name?.group ?? (key.kind == .tool ? "ツール" : unknownGroup)
            return Row(key: key, group: group, groupRank: groups.firstIndex(of: group) ?? groups.count,
                       order: order[key] ?? (100_000 + index),
                       name: name.map { japanese || $0.english.isEmpty ? $0.japanese : $0.english },
                       baseline: base, target: next, status: status(base, next, listedInTarget: inTarget))
        }
        var byKey: [Shortcut: [Int]] = [:]
        for (index, row) in rows.enumerated() {
            if let target = row.target { byKey[target, default: []].append(index) }
        }
        for indices in byKey.values where indices.count > 1 {
            for index in indices {
                rows[index].conflicts = indices.filter { $0 != index }.map { rows[$0].displayName }
            }
        }
        return rows
    }

    static func status(_ baseline: Shortcut?, _ target: Shortcut?, listedInTarget: Bool) -> DiffStatus {
        switch (baseline, target) {
        case (nil, nil): return .unassigned
        case (nil, _?): return .added
        case (_?, nil): return listedInTarget ? .removed : .unlisted
        case let (a?, b?): return a == b ? .same : .changed
        }
    }

    /// "cmd+e" and "⌘E" both find ⌘E; every word has to match.
    static func matches(_ row: Row, query: String) -> Bool {
        let words = normalized(query).split(separator: " ")
        guard !words.isEmpty else { return true }
        let haystack = normalized([row.displayName, row.key.id, row.baseline?.label ?? "", row.target?.label ?? ""].joined(separator: " "))
        return words.allSatisfy { haystack.contains($0) }
    }

    private static func normalized(_ text: String) -> String {
        var result = text.lowercased()
        for (name, symbol) in [("command", "⌘"), ("cmd", "⌘"), ("shift", "⇧"), ("option", "⌥"), ("opt", "⌥"), ("alt", "⌥")] {
            result = result.replacingOccurrences(of: name + "+", with: symbol)
        }
        return result
    }
}

/// Export of the rows on screen.
enum Report {
    struct Labels {
        let status: String, group: String, command: String, baseline: String, target: String, id: String, conflict: String
    }

    static func table(_ rows: [Row], labels: Labels, contextMark: String, statusText: (DiffStatus) -> String, groupText: (String) -> String) -> [[String]] {
        func label(_ shortcut: Shortcut?) -> String {
            guard let shortcut else { return "" }
            return shortcut.label + (shortcut.context == 1 ? " " + contextMark : "")
        }
        return [[labels.status, labels.group, labels.command, labels.baseline, labels.target, labels.id, labels.conflict]] + rows.map {
            [statusText($0.status), groupText($0.group), $0.displayName, label($0.baseline), label($0.target), $0.key.id, $0.conflicts.joined(separator: " / ")]
        }
    }

    static func csv(_ table: [[String]]) -> String {
        table.map { $0.map(csvField).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    static func csvField(_ text: String) -> String {
        guard text.contains(where: { ",\"\r\n".contains($0) }) || text.hasPrefix(" ") || text.hasSuffix(" ") else { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func tsv(_ table: [[String]]) -> String {
        table.map { $0.map { $0.replacingOccurrences(of: "\t", with: " ") }.joined(separator: "\t") }.joined(separator: "\n") + "\n"
    }

    static func markdown(_ table: [[String]]) -> String {
        guard let header = table.first else { return "" }
        func line(_ cells: [String]) -> String { "| " + cells.map(markdownCell).joined(separator: " | ") + " |" }
        return ([line(header), line(header.map { _ in "---" })] + table.dropFirst().map(line)).joined(separator: "\n") + "\n"
    }

    private static func markdownCell(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        return text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "|", with: "\\|")
    }
}

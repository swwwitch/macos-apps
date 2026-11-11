import Foundation

struct PathPair: Hashable {
    let old: String
    let new: String
}

struct ShortcutChange: Hashable {
    let path: String
    let old: String
    let new: String
}

/// 2つのスナップショットの差分
/// - moved：同じ名前の項目が削除側・追加側に1つずつ
/// - renamed：子が移った先のサブメニュー、または同じ親の下で削除・追加が1つずつ
/// - 親の改名・移動に伴うだけの移動は impliedMoves に件数だけ数える
struct MenuDiff {
    var added: [String] = []
    var removed: [String] = []
    var renamed: [PathPair] = []
    var moved: [PathPair] = []
    var impliedMoves = 0
    var shortcutChanges: [ShortcutChange] = []

    init(old: MenuSnapshot, new: MenuSnapshot) {
        let oldShortcuts = Dictionary(old.entries.map { ($0.path, $0.shortcut) }, uniquingKeysWith: { first, _ in first })
        let newShortcuts = Dictionary(new.entries.map { ($0.path, $0.shortcut) }, uniquingKeysWith: { first, _ in first })

        var removedPaths: [String] = []
        for entry in old.entries {
            if let newShortcut = newShortcuts[entry.path] {
                if newShortcut != entry.shortcut {
                    shortcutChanges.append(ShortcutChange(path: entry.path, old: entry.shortcut, new: newShortcut))
                }
            } else {
                removedPaths.append(entry.path)
            }
        }
        var addedPaths = new.entries.map(\.path).filter { oldShortcuts[$0] == nil }

        var movedPairs = Self.pairUp(removedPaths, addedPaths, key: Self.leaf)
        Self.removePaired(movedPairs, from: &removedPaths, &addedPaths)

        var renamedPairs: [PathPair] = []
        let childPairs = Self.pairByChildren(removedPaths, addedPaths, moved: movedPairs)
        for pair in childPairs {
            if Self.leaf(pair.old) == Self.leaf(pair.new) { movedPairs.append(pair) } else { renamedPairs.append(pair) }
        }
        Self.removePaired(childPairs, from: &removedPaths, &addedPaths)

        // サブメニューの有無が異なるものは組にしない（別の項目がたまたま1つずつ増減しただけのことが多い）
        let oldBranches = Set(old.entries.map { Self.parent($0.path) })
        let newBranches = Set(new.entries.map { Self.parent($0.path) })
        let parentPairs = Self.pairUp(removedPaths, addedPaths, key: Self.parent)
            .filter { oldBranches.contains($0.old) == newBranches.contains($0.new) }
        renamedPairs += parentPairs
        Self.removePaired(parentPairs, from: &removedPaths, &addedPaths)

        let pairMap = Dictionary((movedPairs + renamedPairs).map { ($0.old, $0.new) }, uniquingKeysWith: { first, _ in first })
        for pair in movedPairs {
            if pairMap[Self.parent(pair.old)] == Self.parent(pair.new) {
                impliedMoves += 1
            } else {
                moved.append(pair)
            }
        }
        renamed = renamedPairs
        added = addedPaths
        removed = removedPaths
    }

    static func leaf(_ path: String) -> String {
        path.components(separatedBy: MenuReader.separator).last ?? path
    }

    static func parent(_ path: String) -> String {
        var parts = path.components(separatedBy: MenuReader.separator)
        guard parts.count > 1 else { return "" }
        parts.removeLast()
        return parts.joined(separator: MenuReader.separator)
    }

    /// キーが同じで、両側に1つずつしかないものを組にする
    private static func pairUp(_ oldPaths: [String], _ newPaths: [String], key: (String) -> String) -> [PathPair] {
        let oldGroups = Dictionary(grouping: oldPaths, by: key)
        let newGroups = Dictionary(grouping: newPaths, by: key)
        return oldPaths.compactMap { path in
            let groupKey = key(path)
            guard oldGroups[groupKey]?.count == 1, let match = newGroups[groupKey], match.count == 1 else { return nil }
            return PathPair(old: path, new: match[0])
        }
    }

    /// 移動した子の親どうしが、どちらも残りにあれば組にする（先に見つけた組を優先）
    private static func pairByChildren(_ oldPaths: [String], _ newPaths: [String], moved: [PathPair]) -> [PathPair] {
        let oldSet = Set(oldPaths), newSet = Set(newPaths)
        var usedOld = Set<String>(), usedNew = Set<String>()
        var pairs: [PathPair] = []
        for pair in moved {
            let oldParent = parent(pair.old), newParent = parent(pair.new)
            guard oldSet.contains(oldParent), newSet.contains(newParent),
                  !usedOld.contains(oldParent), !usedNew.contains(newParent) else { continue }
            pairs.append(PathPair(old: oldParent, new: newParent))
            usedOld.insert(oldParent)
            usedNew.insert(newParent)
        }
        return pairs
    }

    private static func removePaired(_ pairs: [PathPair], from oldPaths: inout [String], _ newPaths: inout [String]) {
        let pairedOld = Set(pairs.map(\.old)), pairedNew = Set(pairs.map(\.new))
        oldPaths.removeAll { pairedOld.contains($0) }
        newPaths.removeAll { pairedNew.contains($0) }
    }
}

/// 他社製プラグインの項目を比較から外す（スナップショットには残し、比べるときだけ外す）
enum PluginFilter {
    static let keywordsKey = "pluginKeywords"

    /// 既定の名前。メニューのパスのどこかの項目名に含まれていれば外す（大文字小文字は区別しない）
    static let defaultKeywords = [
        "XtreamPath", "Astute", "VectorScribe", "WidthScribe", "InkScribe", "PathScribe", "Phantasm", "ColliderScribe",
        "SubScribe", "DynamicSketch", "Texturino", "Rasterino", "Stylism", "MirrorMe", "InkQuest", "Hot Door", "CADtools",
        "WordsFlow", "Em Software", "Nik Collection", "Topaz", "Imagenomic", "Portraiture", "Luminar",
    ]

    /// 設定の名前（1行1件）。未設定なら既定
    static var keywords: [String] {
        guard let text = UserDefaults.standard.string(forKey: keywordsKey) else { return defaultKeywords }
        return parse(text)
    }

    static func parse(_ text: String) -> [String] {
        text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// 「プラグインについて」（About Plug-ins）の下の項目。InDesign はここに他社製だけが「会社>製品」で並ぶので名前として使う
    static func isAboutPlugins(_ component: String) -> Bool {
        ["プラグインについて", "About Plug-ins", "About Plug-Ins", "About Plugins"].contains(component)
    }

    static func detectedNames(in snapshot: MenuSnapshot) -> [String] {
        let isInDesign = (snapshot.meta["product"] ?? "") == "InDesign" || snapshot.name.hasPrefix("Id")
        guard isInDesign else { return [] }
        var names: [String] = []
        for entry in snapshot.entries {
            let parts = entry.path.components(separatedBy: MenuReader.separator)
            guard parts.count >= 3, isAboutPlugins(parts[1]) else { continue }
            for part in parts[2...] {
                let name = part.replacingOccurrences(of: "™", with: "").replacingOccurrences(of: "®", with: "")
                    .replacingOccurrences(of: "...", with: "").replacingOccurrences(of: "…", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if name.count >= 3 && !names.contains(name) { names.append(name) }
            }
        }
        return names
    }

    static func isPluginItem(_ path: String, names: [String]) -> Bool {
        let parts = path.components(separatedBy: MenuReader.separator)
        if parts.count >= 2 && isAboutPlugins(parts[1]) { return true }
        return parts.contains { part in names.contains { part.localizedCaseInsensitiveContains($0) } }
    }

    static func removingPlugins(from snapshot: MenuSnapshot, names: [String]) -> MenuSnapshot {
        var filtered = snapshot
        filtered.entries = snapshot.entries.filter { !isPluginItem($0.path, names: names) }
        return filtered
    }

    /// 2つのスナップショットから外す名前（設定の名前＋InDesign で見つけた名前）
    static func names(for snapshots: [MenuSnapshot], keywords: [String]) -> [String] {
        var names = keywords
        for snapshot in snapshots {
            for name in detectedNames(in: snapshot) where !names.contains(name) { names.append(name) }
        }
        return names
    }
}

import Foundation

/// A folder structure kept in Settings (プロジェクト). Structure lines:
/// "assets" is a top-level item; a deeper level is given by indentation (tabs, or spaces — the shallowest
/// space indent in the structure is one level) or by leading "/" ("/fonts", "//x"). "a/b" in one line is a path.
/// A name with an extension ("style.css", "_reset.scss") is an empty file; a trailing "/" forces a folder ("v1.0/").
struct Project: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var structure: String

    // Fixed ids: until the list is saved the samples are rebuilt at each launch, and the chosen one must stay chosen.
    static let sample = Project(id: UUID(uuidString: "6F1C2B0A-0000-4000-8000-000000000001")!, name: "Web", structure: """
    assets
    /fonts
    /icons
    /images
    /styles
    components
    /buttons
    /cards
    /error
    /footer
    """)

    static let sampleSCSS = Project(id: UUID(uuidString: "6F1C2B0A-0000-4000-8000-000000000002")!, name: "Web（SCSS）", structure: """
    assets
        css
            style.css
        scss
            style.scss
            base
                _reset.scss
                _variables.scss
                _mixin.scss
            common
                _common.scss
                _header.scss
                _footer.scss
                _layout.scss
            page
        js
        images
    index.html
    """)

    static let samples = [sample, sampleSCSS]

    struct Item: Equatable {
        var path: String
        var isFile: Bool
        var template: String? = nil
    }

    /// "style.css", "_reset.scss", ".htaccess"-like names are files; "v1.0/" is a folder. Extensions are 1–10 letters or digits.
    static func looksLikeFile(_ name: String) -> Bool {
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex || name.count > 1 else { return false }
        let ext = name[name.index(after: dot)...]
        return (1...10).contains(ext.count) && ext.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) } && ext.contains { $0.isLetter }
    }

    /// Leading whitespace and "/" of each line → level. Spaces are divided by the shallowest space indent used.
    private static func levels(_ lines: [String]) -> [(level: Int, name: String)] {
        let spaceIndents = lines.compactMap { line -> Int? in
            let spaces = line.prefix { $0 == " " }.count
            return spaces > 0 && !line.trimmingCharacters(in: .whitespaces).isEmpty ? spaces : nil
        }
        let unit = max(1, spaceIndents.min() ?? 1)
        return lines.compactMap { raw in
            var rest = Substring(raw)
            var tabs = 0, spaces = 0
            while let first = rest.first, first == "\t" || first == " " {
                if first == "\t" { tabs += 1 } else { spaces += 1 }
                rest = rest.dropFirst()
            }
            var slashes = 0
            while rest.first == "/" { slashes += 1; rest = rest.dropFirst() }
            let name = rest.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return nil }
            return (tabs + Int((Double(spaces) / Double(unit)).rounded()) + slashes, name)
        }
    }

    /// Paths in order, parents before children. A level that skips a parent, or an item under a file,
    /// gives an empty part, which BulkNames reports as an unusable name.
    static func items(_ structure: String) -> [Item] {
        var stack: [(name: String, isFile: Bool)] = []
        var result: [Item] = []
        for (level, rawName) in levels(structure.components(separatedBy: .newlines)) {
            var name = rawName
            // "index.html < html5.html": the file's contents come from that template.
            var template: String?
            if let mark = name.firstIndex(of: "<") {
                let left = name[..<mark].trimmingCharacters(in: .whitespaces)
                if looksLikeFile(left) {
                    template = name[name.index(after: mark)...].trimmingCharacters(in: .whitespaces)
                    name = left
                }
            }
            let forcedFolder = name.hasSuffix("/")
            while name.hasSuffix("/") { name.removeLast() }
            if level > stack.count { stack += Array(repeating: ("", false), count: level - stack.count) }
            stack = Array(stack.prefix(level))
            // Nothing can go inside a file.
            if let index = stack.firstIndex(where: { $0.isFile }) { stack[index].name = "" }
            let isFile = !forcedFolder && looksLikeFile(name.components(separatedBy: "/").last ?? name)
            result.append(Item(path: (stack.map(\.name) + [name]).joined(separator: "/"), isFile: isFile, template: isFile ? template : nil))
            stack.append((name, isFile))
        }
        return result
    }

    static func paths(_ structure: String) -> [String] { items(structure).map(\.path) }

    /// Entries for the preview and creation. `root` (one folder name, may be empty) holds the whole structure.
    /// `variables` fill {{name}} in names too ("{{project}}.psd" → ricoh-osaka-20261014.psd), as Post Haste's [template].
    static func entries(_ structure: String, root: String, variables: [String: String] = [:],
                        options: BulkNames.Options = .standard) -> [BulkNames.Entry] {
        let root = root.trimmingCharacters(in: .whitespaces)
        var items = self.items(structure).map { item -> Item in
            var item = item
            for (key, value) in variables { item.path = item.path.replacingOccurrences(of: "{{\(key)}}", with: value) }
            return item
        }
        if !root.isEmpty { items = [Item(path: root, isFile: false)] + items.map { Item(path: root + "/" + $0.path, isFile: $0.isFile, template: $0.template) } }
        var seen = Set<String>()
        return items.compactMap { item in
            guard var entry = BulkNames.parse(item.path, grouping: false, options: options).first else {
                return BulkNames.Entry(line: item.path, path: nil, problem: .badCharacter)
            }
            if let path = entry.path, !seen.insert(options.caseSensitive ? path : path.lowercased()).inserted { return nil }
            entry.isFile = item.isFile
            entry.template = item.template
            return entry
        }
    }
}

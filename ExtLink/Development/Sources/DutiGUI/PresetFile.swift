import Foundation
import UniformTypeIdentifiers

struct PresetFile {
    var name: String
    var associations: [Entry]

    struct Entry {
        var ext: String
        var bundleID: String
        var appName: String? = nil
    }
    static func decode(_ data: Data, name: String = L("プリセット"), typeIdentifier: (String) -> String? = { UTType(filenameExtension: $0)?.identifier }) throws -> PresetFile {
        guard data.count <= 1_048_576 else { throw invalid(L("ファイルが大きすぎます（上限1MB）。")) }
        guard var text = String(data: data, encoding: .utf8) else { throw invalid(L("UTF-8のテキストファイルを選択してください。")) }
        if text.first == "\u{FEFF}" { text.removeFirst() }
        var entries: [Entry] = []
        var canonicalHandlers: [String: String] = [:]
        var typeHandlers: [String: String] = [:]
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        for (index, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let fields = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard fields.count == 5, fields[0] == "duti", fields[1] == "-s", fields[4] == "all" else {
                throw invalid(L("%@行目: duti -s アプリID .拡張子 all の形式で指定してください。", String(describing: index + 1)))
            }
            guard let originalExtension = AssociationService.normalized(fields[3]) else {
                throw invalid(L("%@行目: 無効な拡張子です。", String(describing: index + 1)))
            }
            let ext = AssociationService.canonicalExtension(originalExtension)
            guard let type = typeIdentifier(ext) else { throw invalid(L("%@行目: 無効な拡張子です。", String(describing: index + 1))) }
            let id = fields[2]
            guard id.contains("."), !id.contains(".."), !id.hasPrefix("."), !id.hasSuffix("."),
                  id.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) || ".-_".unicodeScalars.contains($0) }) else {
                throw invalid(L("%@行目: アプリ識別子が無効です。", String(describing: index + 1)))
            }
            if let previous = typeHandlers[type], previous != id {
                throw invalid(L("%@行目: .%@ と同じファイルタイプに異なるアプリが指定されています。", String(describing: index + 1), String(describing: ext)))
            }
            if let previous = canonicalHandlers[ext] {
                guard previous == id else { throw invalid(L("%@行目: .%@ と別名の拡張子に異なるアプリが指定されています。", String(describing: index + 1), String(describing: originalExtension))) }
                continue
            }
            canonicalHandlers[ext] = id
            typeHandlers[type] = id
            entries.append(.init(ext: ext, bundleID: id))
            guard entries.count <= 1000 else { throw invalid(L("関連付けは1000種類まで指定できます。")) }
        }
        guard !entries.isEmpty else { throw invalid(L("関連付けがありません。duti -s で始まる行を追加してください。")) }
        return PresetFile(name: name, associations: entries)
    }
    func encoded() throws -> Data {
        var lines = ["# ExtLink preset", ""]
        var previousID: String?
        // Keep each application's commands together, with an optional comment heading.
        for entry in associations.sorted(by: { ($0.bundleID, $0.ext) < ($1.bundleID, $1.ext) }) {
            if previousID != entry.bundleID {
                if previousID != nil { lines.append("") }
                let label = (entry.appName ?? entry.bundleID).components(separatedBy: .newlines).joined(separator: " ")
                lines.append("# " + label)
                previousID = entry.bundleID
            }
            let normalized = AssociationService.normalized(entry.ext) ?? entry.ext
            for ext in AssociationService.aliases(for: AssociationService.canonicalExtension(normalized)) {
                lines.append("duti -s \(entry.bundleID) .\(ext) all")
            }
        }
        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }
    private static func invalid(_ message: String) -> Error {
        NSError(domain: "dutiGUI.Preset", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

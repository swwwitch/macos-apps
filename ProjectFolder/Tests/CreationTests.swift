import Foundation
@main struct CreationTests {
    static func main() {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("projectfolder-creation-\(getpid())")
        try? fm.removeItem(at: root)
        let templates = root.appendingPathComponent("templates"), dest = root.appendingPathComponent("dest"), trash = root.appendingPathComponent("trash")
        for url in [templates, dest, trash] { try! fm.createDirectory(at: url, withIntermediateDirectories: true) }
        try! "{{project}}".write(to: templates.appendingPathComponent("template.txt"), atomically: true, encoding: .utf8)

        // Windows names and case rules.
        precondition(FileNames.windowsProblem("a?b") && FileNames.windowsProblem("end.") && FileNames.windowsProblem("con.txt") && !FileNames.windowsProblem("console"))
        let win = BulkNames.parse("ok\nbad*name", options: .init(windowsSafe: true))
        precondition(win[0].path == "ok" && win[1].problem == .windowsName)
        precondition(BulkNames.parse("ABC\nabc", options: .init(caseSensitive: true)).count == 2)

        // Project names with {{project}}; implied parents are made and recorded; NFC on disk.
        let entries = Project.entries("ガイド\n  {{project}}.txt\nx/y", root: "", variables: ["project": "プロジェクト"])
        precondition(entries.map(\.path) == ["ガイド", "ガイド/プロジェクト.txt", "x/y"])
        let made = Creator.make(entries, in: dest, projectName: "プロジェクト", nfc: true, templates: templates)
        precondition(made.created.count == 3 && made.failures.isEmpty)
        precondition(made.record.items.map(\.url.lastPathComponent) == ["ガイド", "プロジェクト.txt", "x", "y"], "\(made.record.items.map(\.url.lastPathComponent))")
        let onDisk = try! fm.contentsOfDirectory(atPath: dest.path)
        let guide = onDisk.first { $0 == "ガイド" }!
        precondition(guide.unicodeScalars.elementsEqual("ガイド".precomposedStringWithCanonicalMapping.unicodeScalars), "not NFC")
        precondition(try! String(contentsOf: dest.appendingPathComponent("ガイド/プロジェクト.txt"), encoding: .utf8) == "プロジェクト")
        // Second run: everything exists, nothing is made.
        let again = Creator.make(entries, in: dest, projectName: "プロジェクト", nfc: true, templates: templates)
        precondition(again.created.isEmpty && again.existing == 3)

        // Bulk files: {{project}} is the line's top folder, or the destination's name.
        let bulk = Creator.make(BulkNames.parse("site/readme.txt\nnote.txt"), in: dest, projectName: "", nfc: true, templates: templates)
        precondition(bulk.created.count == 2)
        precondition(try! String(contentsOf: dest.appendingPathComponent("site/readme.txt"), encoding: .utf8) == "site")
        precondition(try! String(contentsOf: dest.appendingPathComponent("note.txt"), encoding: .utf8) == "dest")
        // Undo: untouched items go, a changed file and its folders stay.
        var moved: [String] = []
        let trashIt: (URL) throws -> Void = { url in
            let target = trash.appendingPathComponent(UUID().uuidString)
            try fm.moveItem(at: url, to: target); moved.append(url.lastPathComponent)
        }
        try! "edited".write(to: dest.appendingPathComponent("ガイド/プロジェクト.txt"), atomically: false, encoding: .utf8)
        let undo = made.record.undo(trash: trashIt)
        precondition(moved == ["y", "x"], "\(moved)")
        precondition(undo.trashed == 2 && Set(undo.kept) == ["プロジェクト.txt", "ガイド"], "\(undo)")
        precondition(fm.fileExists(atPath: dest.appendingPathComponent("ガイド/プロジェクト.txt").path))
        try? fm.removeItem(at: root)
        print("PASS: creation (Windows names, case rule, {{project}} in names, implied parents, NFC, no overwrite, undo keeps changed items)")
    }
}

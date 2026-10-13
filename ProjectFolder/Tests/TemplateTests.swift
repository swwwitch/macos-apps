import Foundation
@main struct TemplateTests {
    static func main() {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("projectfolder-templates-\(getpid())")
        try? fm.removeItem(at: root)
        let bundled = root.appendingPathComponent("bundled"), user = root.appendingPathComponent("user"), out = root.appendingPathComponent("out")
        try! fm.createDirectory(at: bundled, withIntermediateDirectories: true)
        try! fm.createDirectory(at: out, withIntermediateDirectories: true)
        try! "<title>{{project}}</title>{{file}} {{date}}".write(to: bundled.appendingPathComponent("template.html"), atomically: true, encoding: .utf8)
        try! "bundled".write(to: bundled.appendingPathComponent("template.css"), atomically: true, encoding: .utf8)
        // Install copies what is missing and never overwrites the user's version.
        try! fm.createDirectory(at: user, withIntermediateDirectories: true)
        try! "mine".write(to: user.appendingPathComponent("template.css"), atomically: true, encoding: .utf8)
        precondition(FileTemplates.installDefaults(into: user, from: bundled) == 1)
        precondition(try! String(contentsOf: user.appendingPathComponent("template.css"), encoding: .utf8) == "mine")
        // Lookup order: explicit → same name → template.<ext> → none; a missing explicit name is reported.
        try! "reset".write(to: user.appendingPathComponent("_reset.scss"), atomically: true, encoding: .utf8)
        try! "five".write(to: user.appendingPathComponent("html5.html"), atomically: true, encoding: .utf8)
        precondition(FileTemplates.lookup(fileName: "index.html", explicit: "html5.html", in: user) == .template(user.appendingPathComponent("html5.html")))
        precondition(FileTemplates.lookup(fileName: "_reset.scss", explicit: nil, in: user) == .template(user.appendingPathComponent("_reset.scss")))
        precondition(FileTemplates.lookup(fileName: "index.html", explicit: nil, in: user) == .template(user.appendingPathComponent("template.html")))
        precondition(FileTemplates.lookup(fileName: "main.js", explicit: nil, in: user) == .none)
        precondition(FileTemplates.lookup(fileName: "a.html", explicit: "nope.html", in: user) == .missing("nope.html"))
        // Variables are filled in; existing files are never replaced.
        let target = out.appendingPathComponent("index.html")
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 12))!
        try! FileTemplates.write(to: target, template: user.appendingPathComponent("template.html"), project: "site-2026", date: date)
        precondition(try! String(contentsOf: target, encoding: .utf8) == "<title>site-2026</title>index 2026-10-14")
        precondition((try? FileTemplates.write(to: target, template: nil, project: "x")) == nil)
        try! FileTemplates.write(to: out.appendingPathComponent("empty.txt"), template: nil, project: "x")
        precondition((try! Data(contentsOf: out.appendingPathComponent("empty.txt"))).isEmpty)
        // Binary templates (PSD, Office, PDF) are copied byte for byte, never run through the text replacement.
        let binary = Data([0x38, 0x42, 0x50, 0x53, 0xff, 0xfe, 0x00, 0x7b, 0x7b])
        try! binary.write(to: user.appendingPathComponent("template.psd"))
        try! FileTemplates.write(to: out.appendingPathComponent("a.psd"), template: user.appendingPathComponent("template.psd"), project: "x")
        precondition(try! Data(contentsOf: out.appendingPathComponent("a.psd")) == binary)
        // "<" in a structure line names the template, for files only.
        let items = Project.items("index.html < html5.html\nv<1>")
        precondition(items[0] == Project.Item(path: "index.html", isFile: true, template: "html5.html") && items[1].template == nil)
        try? fm.removeItem(at: root)
        print("PASS: file templates (install without overwrite, lookup order, variables, no overwrite, \"<\" in structure)")
    }
}

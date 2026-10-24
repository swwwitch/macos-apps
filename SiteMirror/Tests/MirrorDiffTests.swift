import Foundation

@main
struct MirrorDiffTests {
    static func main() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("SiteMirror-diff-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        func write(_ name: String, _ value: String) throws {
            try value.write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        try write("changed.html", "old\n")
        try write("same.css", "body {}\n")
        try write("gone.html", "gone")
        try write("unseen.html", "unseen")
        try write("removed.html", "removed")
        let comparison = MirrorDiff(root: folder, paths: ["changed.html", "same.css", "gone.html", "unseen.html", "removed.html", "../outside"])
        try write("changed.html", "new\n")
        try write("added.html", "added\n")
        try FileManager.default.removeItem(at: folder.appendingPathComponent("removed.html"))
        let items = comparison.compare(successful: ["changed.html", "same.css", "added.html", "../outside"], gone: ["gone.html"], removed: ["removed.html"])
        let byPath = Dictionary(uniqueKeysWithValues: items.map { ($0.path, $0) })
        precondition(byPath["changed.html"]?.state == .changed)
        precondition(byPath["changed.html"]!.detail.contains("-old") && byPath["changed.html"]!.detail.contains("+new"))
        precondition(byPath["same.css"]?.state == .unchanged)
        precondition(byPath["added.html"]?.state == .added)
        precondition(byPath["gone.html"]?.state == .unavailable)
        precondition(byPath["unseen.html"]?.state == .unverified)
        precondition(byPath["removed.html"]?.state == .removed)
        precondition(byPath["../outside"]?.state == .unreadable)
        precondition(comparison.report(items: items, partial: true, resumed: true).contains("通算差分ではありません"))
        print("PASS diff classification, unified lines, partial/resume labels and path boundary")

        guard CommandLine.arguments.count == 3 else { return }
        let website = URL(fileURLWithPath: CommandLine.arguments[2])
        let destination = folder.appendingPathComponent("mirror")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        func page(_ name: String, _ content: String) throws {
            try content.write(to: website.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        try page("index.html", "<html>\nold title\n<a href='/missing.html'>missing</a>\n<a href='/unlinked.html'>unlinked</a>\n<a href='/temporary.html'>temporary</a>\n<link rel='stylesheet' href='/style.css'>\n<img src='/image.png'>\n</html>\n")
        for name in ["missing.html", "unlinked.html", "temporary.html"] { try page(name, "<p>before</p>\n") }
        try page("style.css", "body { color: red; }\n")
        try page("image.png", "unchanged image")
        let start = URL(string: CommandLine.arguments[1] + "/index.html")!
        var options = MirrorOptions()
        options.obeyRobots = false
        options.retries = 0
        let first = await Crawler(start: start, root: destination, options: options, emit: { _ in }).run()
        precondition(first.failed == 0 && first.diffReport != nil)
        let firstReport = try String(contentsOf: first.diffReport!, encoding: .utf8)
        precondition(firstReport.contains("初回取得"))
        try page("index.html", "<html>\nnew title\n<a href='/missing.html'>missing</a>\n<a href='/temporary.html'>temporary</a>\n<a href='/added.html'>added</a>\n<link rel='stylesheet' href='/style.css'>\n<img src='/image.png'>\n</html>\n")
        try page("style.css", "body { color: blue; }\n")
        try page("added.html", "<p>new page</p>\n")
        try FileManager.default.removeItem(at: website.appendingPathComponent("missing.html"))
        try page("stage2", "1")
        let second = await Crawler(start: start, root: destination, options: options, emit: { _ in }).run()
        precondition(second.diffReport != nil && second.failed == 2)
        precondition(first.diffReport != second.diffReport)
        let retainedReport = try String(contentsOf: first.diffReport!, encoding: .utf8)
        precondition(retainedReport == firstReport)
        let report = try String(contentsOf: second.diffReport!, encoding: .utf8)
        precondition(report.contains("-old title") && report.contains("+new title"))
        precondition(report.contains("-body { color: red; }") && report.contains("+body { color: blue; }"))
        precondition(report.contains("=== サイトで削除・非公開（404／410） ===\nmissing.html"))
        precondition(report.contains("=== 未確認（対象外・未到達・取得失敗など） ===\ntemporary.html\nunlinked.html"))
        precondition(report.contains("=== 追加 ===\nadded.html"))
        precondition(report.contains("=== 変更なし ===\nimage.png"))
        precondition(FileManager.default.fileExists(atPath: destination.appendingPathComponent("unlinked.html").path))
        let third = await Crawler(start: start, root: destination, options: options, emit: { _ in }).run()
        let thirdReport = try String(contentsOf: third.diffReport!, encoding: .utf8)
        precondition(thirdReport.contains("変更: 0"), "Identical repeated downloads must not report rewritten links as changes")
        options.checkOnly = true
        let check = await Crawler(start: start, root: destination, options: options, emit: { _ in }).run()
        precondition(check.diffReport == nil)
        print("PASS crawler integration: first/repeat/identical downloads, HTML/CSS lines, added, 404, 503, unlinked, assets, check-only")
    }
}

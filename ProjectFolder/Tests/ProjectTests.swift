import Foundation
@main struct ProjectTests {
    static func main() {
        let paths = Project.paths(Project.sample.structure)
        precondition(paths == ["assets", "assets/fonts", "assets/icons", "assets/images", "assets/styles",
                               "components", "components/buttons", "components/cards", "components/error", "components/footer"], "\(paths)")
        // Deeper levels, tabs, blank lines.
        precondition(Project.paths("a\n/b\n//c\n\n\td\ne/f") == ["a", "a/b", "a/b/c", "a/d", "e/f"])
        // A level without a parent is reported as unusable.
        let bad = Project.entries("//orphan", root: "")
        precondition(bad.count == 1 && bad[0].path == nil)
        // Root folder holds everything and comes first.
        let e = Project.entries("assets\n/fonts", root: "site-2026")
        precondition(e.map(\.path) == ["site-2026", "site-2026/assets", "site-2026/assets/fonts"])
        precondition(Project.entries("assets", root: "a:b").allSatisfy { $0.path == nil })
        // Indentation with spaces (shallowest indent = one level), tabs, files with extensions, the user's SCSS example.
        let scss = Project.items(Project.sampleSCSS.structure)
        precondition(scss.map(\.path) == ["assets", "assets/css", "assets/css/style.css", "assets/scss", "assets/scss/style.scss",
            "assets/scss/base", "assets/scss/base/_reset.scss", "assets/scss/base/_variables.scss", "assets/scss/base/_mixin.scss",
            "assets/scss/common", "assets/scss/common/_common.scss", "assets/scss/common/_header.scss", "assets/scss/common/_footer.scss",
            "assets/scss/common/_layout.scss", "assets/scss/page", "assets/js", "assets/images", "index.html"], "\(scss.map(\.path))")
        precondition(scss.filter(\.isFile).map(\.path) == ["assets/css/style.css", "assets/scss/style.scss", "assets/scss/base/_reset.scss",
            "assets/scss/base/_variables.scss", "assets/scss/base/_mixin.scss", "assets/scss/common/_common.scss", "assets/scss/common/_header.scss",
            "assets/scss/common/_footer.scss", "assets/scss/common/_layout.scss", "index.html"])
        precondition(Project.paths("a\n  b\n    c\n  d") == ["a", "a/b", "a/b/c", "a/d"])
        precondition(Project.paths("a\n\tb\n\t\tc") == ["a", "a/b", "a/b/c"])
        precondition(Project.paths("a\n-b\n--c") == ["a", "a/b", "a/b/c"])
        // Folder names with dots: trailing "/" forces a folder; version-like names without letters are folders.
        let dotted = Project.items("v1.0/\n2026.10\nnotes.txt")
        precondition(dotted.map(\.isFile) == [false, false, true] && dotted[0].path == "v1.0")
        // Nothing goes inside a file.
        precondition(Project.entries("index.html\n  inner", root: "").map(\.path) == ["index.html", nil])
        let rooted = Project.entries("index.html", root: "site")
        precondition(rooted.map(\.path) == ["site", "site/index.html"] && rooted.map(\.isFile) == [false, true])
        let data = try! JSONEncoder().encode([Project.sample])
        precondition(try! JSONDecoder().decode([Project].self, from: data) == [Project.sample])
        print("PASS: project structures (/, tabs, space indents, files, dotted folders, root folder, orphans, persistence)")
    }
}
